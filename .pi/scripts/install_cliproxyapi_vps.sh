#!/usr/bin/env bash
# Install or update on systemd Linux. Run as root on the destination server.
# ssh root@<ip> 'bash -s' < install_cliproxyapi_vps.sh
set -euo pipefail
umask 077

die() { echo "$*" >&2; exit 1; }
[[ $(uname -s) == Linux && -d /run/systemd/system && $EUID == 0 ]] || die 'Run as root on Linux with systemd.'
case $(uname -m) in
  x86_64) arch=amd64 ;;
  aarch64|arm64) arch=aarch64 ;;
  *) die "Unsupported CPU: $(uname -m)" ;;
esac
bin=/usr/local/bin/cli-proxy-api
conf=/etc/cliproxyapi/config.yaml
unit=/etc/systemd/system/cliproxyapi.service
updating=false
if [[ -f $bin && -x $bin && ! -L $bin && -f $conf && -f $unit ]]; then
  updating=true
else
  for path in "$bin" "${conf%/*}" "$unit" /var/lib/cliproxyapi; do
    [[ ! -e $path && ! -L $path ]] || die "Incomplete or different installation: $path exists; nothing changed."
  done
  if systemctl cat cliproxyapi.service >/dev/null 2>&1; then die 'Service already exists outside this installation.'; fi
fi
for cmd in curl openssl sha256sum tar; do command -v "$cmd" >/dev/null || die "Missing command: $cmd"; done

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cd "$tmp"
releases=https://github.com/router-for-me/CLIProxyAPI/releases
fetch() { curl --proto '=https' --proto-redir '=https' -fsSL --retry 2 -o "$1" "$2"; }
fetch checksums.txt "$releases/latest/download/checksums.txt"
pattern="^([[:xdigit:]]{64})[[:space:]]+(CLIProxyAPI_([0-9]+\.[0-9]+\.[0-9]+)_linux_${arch}_no-plugin\.tar\.gz)$"
asset=
while IFS= read -r line || [[ -n $line ]]; do
  [[ $line =~ $pattern ]] || continue
  [[ -z $asset ]] || die "Multiple $arch archives in release checksums."
  sha=${BASH_REMATCH[1]} asset=${BASH_REMATCH[2]} version=${BASH_REMATCH[3]}
done < checksums.txt
[[ -n $asset ]] || die "No matching $arch archive in latest release checksums."
if $updating; then
  # The binary prints its version banner with -h, without starting a server.
  banner=$("$bin" -h 2>&1)
  version_pattern='^CLIProxyAPI Version: v?([0-9]+\.[0-9]+\.[0-9]+),'
  [[ $banner =~ $version_pattern ]] || die 'Cannot determine installed version; nothing changed.'
  installed=${BASH_REMATCH[1]}
  if printf '%s\n' "$version" "$installed" | sort -V -C; then
    echo "Installed CLIProxyAPI $installed; latest release $version. No update needed."
    exit 0
  fi
fi
fetch "$asset" "$releases/download/v${version}/${asset}"
printf '%s  %s\n' "$sha" "$asset" | sha256sum -c -
tar -xzf "$asset" cli-proxy-api
if $updating; then
  # Stage on the binary's filesystem so the rename is atomic even if /tmp is separate.
  stage=$(mktemp -d "${bin%/*}/.cliproxyapi.XXXXXXXX")
  trap 'rm -rf -- "$tmp" "$stage"' EXIT
  ln "$bin" "$stage/previous"
  install -m 0755 cli-proxy-api "$stage/new"
  mv -f "$stage/new" "$bin"
  if systemctl restart cliproxyapi.service && systemctl is-active --quiet cliproxyapi.service; then
    echo "Updated CLIProxyAPI from $installed to $version."
    exit 0
  fi
  mv -f "$stage/previous" "$bin"
  systemctl restart cliproxyapi.service || die 'Restored previous binary, but restart failed. Check journalctl -u cliproxyapi.'
  die 'Update failed its service check; restored the previous binary and restarted.'
fi
key=$(openssl rand -hex 32)
read -r server_id < /proc/sys/kernel/random/uuid
install -D -m 0755 cli-proxy-api "$bin"
install -d -m 0700 "${conf%/*}"
cat > "$conf" <<EOF
config-version: 8
server:
  server-id: "$server_id"
  commercial-mode: true
  host: "127.0.0.1"
  port: 8317
access:
  api-keys:
    - "$key"
oauth:
  auth-dir: /var/lib/cliproxyapi/auth
routing:
  strategy: "round-robin"
  session-affinity: true
  session-affinity-ttl: "1h"
  retry:
    request-retry: 3
    max-retry-interval: 30
observability:
  logs:
    debug: false
    logging-to-file: false
    request-log: false
EOF
cat > "$unit" <<'EOF'
[Unit]
Description=CLIProxyAPI
After=network.target

[Service]
DynamicUser=yes
StateDirectory=cliproxyapi
StateDirectoryMode=0700
WorkingDirectory=/var/lib/cliproxyapi
LoadCredential=config.yaml:/etc/cliproxyapi/config.yaml
ExecStart=/usr/local/bin/cli-proxy-api -config %d/config.yaml
Restart=on-failure
UMask=0077

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 "$unit"
systemctl daemon-reload
systemctl enable --now cliproxyapi.service
url=http://127.0.0.1:8317/v1/models
for ((i=0; i<20; i++)); do
  status=$(curl --noproxy '*' -s --max-time 2 -o /dev/null -w '%{http_code}' "$url") || status=000
  if [[ $status == 401 ]] && printf 'Authorization: Bearer %s\n' "$key" | curl --noproxy '*' -fsS --max-time 2 -H @- "$url" -o /dev/null && systemctl is-active --quiet cliproxyapi; then
    echo "CLIProxyAPI $version is ready at $url. Client key: see $conf."
    exit 0
  fi
  sleep 1
done
die 'Startup check failed. Inspect: journalctl -u cliproxyapi -n 50 --no-pager'
