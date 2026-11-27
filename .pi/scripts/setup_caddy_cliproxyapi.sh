#!/usr/bin/env bash
# Run on a Debian/Ubuntu VPS: sudo bash setup_caddy_cliproxyapi.sh PUBLIC_IPV4
# ssh root@<ip> 'bash -s -- <ip>' < ~/.dotfiles/.pi/scripts/setup_caddy_cliproxyapi.sh
set -euo pipefail
export LC_ALL=C

die() { echo "$*" >&2; exit 1; }
[[ $# == 1 ]] || die 'Usage: setup_caddy_cliproxyapi.sh PUBLIC_IPV4'
ip=$1
python3 - "$ip" <<'PY'
import ipaddress, sys
try:
    ip = ipaddress.IPv4Address(sys.argv[1])
except ValueError:
    sys.exit('Expected a public IPv4 address.')
if not ip.is_global or ip.is_multicast or str(ip) != sys.argv[1]:
    sys.exit('Expected a public IPv4 address.')
PY
[[ $EUID == 0 && -f /etc/debian_version && -d /run/systemd/system ]] || die 'Run as root on Debian/Ubuntu with systemd.'
url=http://127.0.0.1:8317/v1/models
status=$(curl -q --noproxy '*' -sS --max-time 5 -o /dev/null -w '%{http_code}' "$url")
[[ $status == 401 ]] || die "Expected CLIProxyAPI to require authentication on $url; got HTTP $status."

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
conf=/etc/caddy/Caddyfile
cat > "$work/Caddyfile" <<EOF
{
	default_sni $ip
	servers {
		protocols h1 h2
	}
}

https://$ip {
	tls {
		issuer acme https://acme-v02.api.letsencrypt.org/directory {
			profile shortlived
		}
	}

	handle /v1/* {
		reverse_proxy 127.0.0.1:8317
	}
	handle {
		respond 404
	}
}
EOF

# Only replace an unmodified package default; a custom site needs a manual merge.
if [[ -L $conf ]]; then die "Refusing to replace symlink $conf."; fi
if [[ -e $conf ]] && ! cmp -s "$conf" "$work/Caddyfile"; then
  stock=$(dpkg-query -W -f='${Conffiles}\n' caddy 2>/dev/null | awk -v p="$conf" '$1 == p {print $2}') || stock=
  [[ -n $stock && $(md5sum < "$conf") == "$stock  -" ]] || die "Custom $conf found; nothing changed."
fi

if ! command -v caddy >/dev/null; then
  [[ -z $(ss -Hlt 'sport = :80 or sport = :443') ]] || die 'TCP 80 or 443 already in use; nothing changed.'
  releases=https://api.github.com/repos/caddyserver/caddy/releases/latest
  curl -q -fsSL --retry 2 --max-time 30 "$releases" -o "$work/release.json"
  python3 - "$work/release.json" "$(dpkg --print-architecture)" > "$work/asset" <<'PY'
import json, re, sys
with open(sys.argv[1]) as f:
    release = json.load(f)
tag = release['tag_name']
if not re.fullmatch(r'v\d+\.\d+\.\d+', tag):
    sys.exit('Unexpected Caddy release tag.')
name = f'caddy_{tag[1:]}_linux_{sys.argv[2]}.deb'
for asset in release['assets']:
    if asset['name'] == name and re.fullmatch(r'sha256:[0-9a-f]{64}', asset.get('digest') or ''):
        print(f'https://github.com/caddyserver/caddy/releases/download/{tag}/{name}', asset['digest'][7:])
        break
else:
    sys.exit('No checksummed Caddy package for this architecture.')
PY
  read -r download sha < "$work/asset"
  curl -q --proto '=https' --proto-redir '=https' -fsSL --retry 2 --max-time 120 "$download" -o "$work/caddy.deb"
  printf '%s  %s\n' "$sha" "$work/caddy.deb" | sha256sum -c -
  DEBIAN_FRONTEND=noninteractive dpkg -i "$work/caddy.deb"
fi

caddy validate --config "$work/Caddyfile" --adapter caddyfile
if command -v ufw >/dev/null && [[ $(ufw status) == 'Status: active'* ]]; then
  ufw allow 80/tcp comment 'Caddy HTTP ACME'
  ufw allow 443/tcp comment 'Caddy HTTPS'
fi
if ! cmp -s "$work/Caddyfile" "$conf"; then
  install -m 0644 "$work/Caddyfile" "$conf"
fi
systemctl enable --now caddy
systemctl reload caddy

# Verify the IP certificate locally without depending on NAT hairpin support.
for ((i=0; i<30; i++)); do
  status=$(curl -q --noproxy '*' --connect-to "$ip:443:127.0.0.1:443" -s --max-time 3 -o /dev/null -w '%{http_code}' "https://$ip/v1/models") || status=000
  if [[ $status == 401 ]]; then
    echo "Verified https://$ip/v1/models requires an API key. Allow inbound TCP 80/443 in the provider firewall."
    exit 0
  fi
  sleep 2
done
die 'HTTPS check failed. Check journalctl -u caddy and inbound TCP 80/443; leave port 8317 private.'
