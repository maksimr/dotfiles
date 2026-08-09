#!/usr/bin/env bash
#
# Install:
#   curl -fsSL https://raw.githubusercontent.com/maksimr/dotfiles/main/.config/awg/install_awg.sh | sudo bash -s -- install
#   wget -qO- https://raw.githubusercontent.com/maksimr/dotfiles/main/.config/awg/install_awg.sh | sudo bash -s -- install
#
#   # or download once, then use locally:
#   curl -fsSLo install_awg.sh https://raw.githubusercontent.com/maksimr/dotfiles/main/.config/awg/install_awg.sh
#   chmod +x install_awg.sh && sudo ./install_awg.sh install
#
# Usage:
#   sudo ./install_awg.sh install [--subnet 10.9.0] [--port 51820] [--dns 1.1.1.1,8.8.8.8]
#   sudo ./install_awg.sh update  [--subnet ...] [--port ...] [--dns ...]
#   sudo ./install_awg.sh add <name>         # add client, prints config + QR code
#   sudo ./install_awg.sh remove <name>      # remove client
#   sudo ./install_awg.sh list               # list clients / live peer status
#
# Adding a client:
#   sudo ./install_awg.sh add phone
#   -> client config saved to /etc/amneziawg/clients/phone.conf
#   -> QR code printed in terminal (scan with AmneziaWG / WireGuard app)
#   -> applied live, no restart needed
#
# Removing a client:
#   sudo ./install_awg.sh remove phone
#   -> peer deleted from server config and live interface
#

set -euo pipefail

AWG_DIR=/etc/amneziawg
IFACE=awg0
SERVER_CONF="$AWG_DIR/$IFACE.conf"
CLIENTS_DIR="$AWG_DIR/clients"
SETTINGS="$AWG_DIR/settings.env"

# settings saved at install/update time; --subnet/--port/--dns flags override
[[ -f $SETTINGS ]] && . "$SETTINGS"
VPN_SUBNET="${VPN_SUBNET:-10.9.0}"   # first 3 octets; clients get $VPN_SUBNET.X/32
VPN_PORT="${VPN_PORT:-51820}"
DNS="${DNS:-1.1.1.1,8.8.8.8}"

parse_opts() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --subnet) VPN_SUBNET=${2:?--subnet needs a value}; shift 2 ;;
            --port)   VPN_PORT=${2:?--port needs a value}; shift 2 ;;
            --dns)    DNS=${2:?--dns needs a value}; shift 2 ;;
            *) die "unknown option: $1" ;;
        esac
    done
}

save_settings() {
    umask 077
    cat > "$SETTINGS" <<EOF
VPN_SUBNET=$VPN_SUBNET
VPN_PORT=$VPN_PORT
DNS=$DNS
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }
need_root() { [[ $EUID -eq 0 ]] || die "run as root (sudo)"; }

# ---------------------------------------------------------------- install/update

install_pkgs() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq curl qrencode iptables iproute2 gnupg2 \
        software-properties-common python3-launchpadlib >/dev/null

    if grep -qi ubuntu /etc/os-release; then
        # Ubuntu: kernel module + tools from official PPA
        apt-get install -y -qq "linux-headers-$(uname -r)" >/dev/null || true
        add-apt-repository -y ppa:amnezia/ppa
        apt-get update -qq
        apt-get install -y -qq amneziawg amneziawg-tools >/dev/null
        modprobe amneziawg || true
    else
        # Debian/other: build userspace amneziawg-go + amneziawg-tools from source
        apt-get install -y -qq git build-essential golang-go bash >/dev/null
        build_from_source
    fi

    command -v awg >/dev/null || die "awg not found after install"
    echo "AmneziaWG installed: $(awg --version 2>/dev/null || echo ok)"
}

build_from_source() {
    local src=/usr/local/src

    # amneziawg-go (userspace backend)
    if [[ -d $src/amneziawg-go ]]; then
        git -C "$src/amneziawg-go" pull --ff-only
    else
        git clone https://github.com/amnezia-vpn/amneziawg-go "$src/amneziawg-go"
    fi
    make -C "$src/amneziawg-go"
    install -m 0755 "$src/amneziawg-go/amneziawg-go" /usr/local/bin/amneziawg-go

    # amneziawg-tools (awg / awg-quick), latest release tag
    local tag
    tag=$(curl -fsSL https://api.github.com/repos/amnezia-vpn/amneziawg-tools/releases/latest \
          | grep -oP '"tag_name":\s*"\K[^"]+')
    if [[ -d $src/amneziawg-tools ]]; then
        git -C "$src/amneziawg-tools" fetch --tags
    else
        git clone https://github.com/amnezia-vpn/amneziawg-tools "$src/amneziawg-tools"
    fi
    git -C "$src/amneziawg-tools" checkout "$tag"
    make -C "$src/amneziawg-tools/src"
    make -C "$src/amneziawg-tools/src" install
}

server_setup() {
    [[ -f $SERVER_CONF ]] && { save_settings; echo "Server config exists: $SERVER_CONF (skipping)"; return; }
    save_settings

    mkdir -p "$AWG_DIR" "$CLIENTS_DIR"
    chmod 700 "$AWG_DIR" "$CLIENTS_DIR"
    umask 077

    awg genkey > "$AWG_DIR/server.key"
    awg pubkey < "$AWG_DIR/server.key" > "$AWG_DIR/server.pub"

    # obfuscation params (must match on every client; stored in server conf)
    local h1 h2 h3 h4
    h1=$((RANDOM * RANDOM + 10000)); h2=$((h1 + RANDOM + 1))
    h3=$((h2 + RANDOM + 1));         h4=$((h3 + RANDOM + 1))

    local nic
    nic=$(ip route show default | awk '/default/ {print $5; exit}')

    cat > "$SERVER_CONF" <<EOF
[Interface]
Address = $VPN_SUBNET.1/24
ListenPort = $VPN_PORT
PrivateKey = $(cat "$AWG_DIR/server.key")
Jc = 4
Jmin = 64
Jmax = 512
S1 = 30
S2 = 40
H1 = $h1
H2 = $h2
H3 = $h3
H4 = $h4
PostUp = iptables -t nat -A POSTROUTING -s $VPN_SUBNET.0/24 -o $nic -j MASQUERADE; iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -s $VPN_SUBNET.0/24 -o $nic -j MASQUERADE; iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT
EOF

    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-awg.conf
    sysctl -q -p /etc/sysctl.d/99-awg.conf

    systemctl enable --now "awg-quick@$IFACE"
    echo "Server up: $IFACE, port $VPN_PORT/udp. Open this port in your firewall."
}

cmd_update() {
    save_settings
    if grep -qi ubuntu /etc/os-release; then
        apt-get update -qq
        apt-get install -y --only-upgrade amneziawg amneziawg-tools
    else
        build_from_source
    fi
    systemctl restart "awg-quick@$IFACE" || true
    echo "Updated."
}

# ---------------------------------------------------------------- clients

next_ip() {
    local used i
    used=$(grep -oP "AllowedIPs = $VPN_SUBNET\.\K[0-9]+" "$SERVER_CONF" || true)
    for i in $(seq 2 254); do
        grep -qx "$i" <<< "$used" || { echo "$i"; return; }
    done
    die "subnet full"
}

server_endpoint() {
    echo "${AWG_ENDPOINT:-$(curl -4fsSL https://ifconfig.me 2>/dev/null || curl -4fsSL https://api.ipify.org)}"
}

cmd_add() {
    local name=${1:?usage: $0 add <name>}
    [[ $name =~ ^[A-Za-z0-9_-]+$ ]] || die "name: letters/digits/_/- only"
    [[ -f $SERVER_CONF ]] || die "server not installed, run: $0 install"
    grep -q "# client: $name\$" "$SERVER_CONF" && die "client '$name' already exists"

    umask 077
    local key pub psk ip
    key=$(awg genkey); pub=$(awg pubkey <<< "$key"); psk=$(awg genpsk)
    ip=$(next_ip)

    cat >> "$SERVER_CONF" <<EOF

[Peer]
# client: $name
PublicKey = $pub
PresharedKey = $psk
AllowedIPs = $VPN_SUBNET.$ip/32
EOF

    # obfuscation params copied from server conf so client matches exactly
    local obf
    obf=$(grep -E '^(Jc|Jmin|Jmax|S1|S2|H1|H2|H3|H4) ' "$SERVER_CONF")

    local conf="$CLIENTS_DIR/$name.conf"
    cat > "$conf" <<EOF
[Interface]
Address = $VPN_SUBNET.$ip/32
PrivateKey = $key
DNS = $DNS
$obf

[Peer]
PublicKey = $(cat "$AWG_DIR/server.pub")
PresharedKey = $psk
Endpoint = $(server_endpoint):$VPN_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    # apply live without dropping other peers
    awg syncconf "$IFACE" <(awg-quick strip "$IFACE") 2>/dev/null || true

    echo "Client '$name' added -> $conf"
    echo
    cat "$conf"
    echo
    command -v qrencode >/dev/null && qrencode -t ansiutf8 < "$conf"
}

cmd_remove() {
    local name=${1:?usage: $0 remove <name>}
    grep -q "# client: $name\$" "$SERVER_CONF" || die "client '$name' not found"

    # delete the [Peer] block containing "# client: <name>"
    awk -v tag="# client: $name" '
        BEGIN { RS=""; FS="\n"; ORS="\n\n" }
        $0 !~ tag { print }
    ' "$SERVER_CONF" > "$SERVER_CONF.tmp"
    mv "$SERVER_CONF.tmp" "$SERVER_CONF"
    chmod 600 "$SERVER_CONF"
    rm -f "$CLIENTS_DIR/$name.conf"

    awg syncconf "$IFACE" <(awg-quick strip "$IFACE") 2>/dev/null || true
    echo "Client '$name' removed."
}

cmd_list() {
    echo "== configured clients =="
    grep -oP '# client: \K.*' "$SERVER_CONF" 2>/dev/null || echo "(none)"
    echo
    echo "== live status =="
    awg show "$IFACE" 2>/dev/null || echo "interface $IFACE down"
}

# ---------------------------------------------------------------- main

need_root
case "${1:-}" in
    install) shift; parse_opts "$@"; install_pkgs; server_setup ;;
    update)  shift; parse_opts "$@"; cmd_update ;;
    add)     cmd_add "${2:-}" ;;
    remove)  cmd_remove "${2:-}" ;;
    list)    cmd_list ;;
    *) # $0 is not a file when piped via curl/wget
       if [[ -f $0 ]]; then grep '^#' "$0" | head -37 | sed 's/^# \{0,1\}//'
       else echo "usage: install | update | add <name> | remove <name> | list"; fi
       exit 1 ;;
esac
