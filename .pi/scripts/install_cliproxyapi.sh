#!/usr/bin/env bash
# Install CLIProxyAPI on macOS (Homebrew) or Linux (x86_64/aarch64 releases).
# Requires Homebrew on macOS; curl and Python 3 on Linux; OpenSSL for new keys.
# New installs listen on localhost:8317. Existing config, keys and logins stay intact.
# Starts at user login via Homebrew/systemd; without a user systemd, run manually.
# Does not import accounts or change Pi, Claude Code, T3 Code, PATH or sleep settings.
#
# Usage: bash ~/.dotfiles/.pi/scripts/install_cliproxyapi.sh
# Sign in afterward with the printed -claude-login / -codex-device-login commands.
# Rerun to update to the latest v8 release; the service restarts only if it changed.
#
# Uninstall macOS:
#   brew services stop cliproxyapi
#   brew uninstall cliproxyapi
#   rm -f "$(brew --prefix)/etc/cliproxyapi.conf"
# Uninstall Linux:
#   systemctl --user disable --now cliproxyapi.service  # skip without systemd
#   rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/cliproxyapi.service"
#   systemctl --user daemon-reload                    # skip without systemd
#   rm -rf "$HOME/cliproxyapi"
# Both: stop any manually started process, then optionally delete ALL saved
# accounts and proxy keys with: rm -rf "$HOME/.cli-proxy-api"
# Restore any client routing separately before removing a proxy they depend on.
# If you separately enabled lingering, undo it only if no other services need it:
#   loginctl disable-linger "$USER"

set +x
set -Eeuo pipefail
umask 077

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[[ $# -eq 0 ]] || die "usage: ${0##*/}"
KERNEL="$(uname -s)"
case "$KERNEL" in
    Darwin)
        command -v brew >/dev/null 2>&1 || die 'install Homebrew first: https://brew.sh'
        CONFIG="$(brew --prefix)/etc/cliproxyapi.conf"
        BINARY="$(brew --prefix)/bin/cliproxyapi"
        ;;
    Linux)
        CONFIG="$HOME/cliproxyapi/config.yaml"
        BINARY="$HOME/cliproxyapi/cli-proxy-api"
        case "$(uname -m)" in
            x86_64|amd64) ARCH=amd64 ;;
            aarch64|arm64) ARCH=aarch64 ;;
            *) die 'Linux requires x86_64 or aarch64' ;;
        esac
        for cmd in curl python3; do
            command -v "$cmd" >/dev/null 2>&1 || die "required command not found: $cmd"
        done
        ;;
    *) die "unsupported operating system: $KERNEL" ;;
esac

NEW_CONFIG=false
if [[ ! -e "$CONFIG" ]]; then
    [[ ! -L "$CONFIG" ]] || die "config is a broken symlink: $CONFIG"
    NEW_CONFIG=true
    command -v openssl >/dev/null 2>&1 || die 'OpenSSL is required to generate proxy keys'
    for key in client management; do
        [[ ! -e "$HOME/.cli-proxy-api/$key.key" && ! -L "$HOME/.cli-proxy-api/$key.key" ]] ||
            die "config is missing but $key.key exists; restore the config before reinstalling"
    done
elif grep -q 'your-api-key-' "$CONFIG"; then
    # Homebrew installs config.example.yaml here: all interfaces, public sample keys.
    die "config is the unedited example; delete $CONFIG and rerun"
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cliproxyapi-install.XXXXXX")"
trap 'rm -rf -- "$TEMP_DIR"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

UPDATED=false
if [[ "$KERNEL" == Darwin ]]; then
    brew update --quiet  # the formula API cache can lag releases by a day
    [[ "$(brew info --json=v2 cliproxyapi)" == *'"stable": "8.'* ]] ||
        die 'Review the configuration schema before installing a new major version'
    BEFORE="$(brew list --versions cliproxyapi 2>/dev/null || true)"
    if [[ -n "$BEFORE" ]]; then
        HOMEBREW_NO_INSTALL_CLEANUP=1 brew upgrade cliproxyapi
    else
        HOMEBREW_NO_INSTALL_CLEANUP=1 brew install cliproxyapi
    fi
    [[ "$(brew list --versions cliproxyapi)" == "$BEFORE" ]] || UPDATED=true
else
    # shortcut: downloads the release on every run; compare tags first if bandwidth matters.
    curl -fsSL --proto '=https' --proto-redir '=https' \
        https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest \
        -o "$TEMP_DIR/release.json"
    # shortcut: portable no-plugin builds support glibc/musl; use a standard build for native plugins.
    URL="$(python3 - "$TEMP_DIR/release.json" "$ARCH" <<'PY'
import json, sys
release = json.load(open(sys.argv[1]))
if not release['tag_name'].startswith('v8.'):
    sys.exit('Review the configuration schema before installing a new major version')
suffix = '_linux_' + sys.argv[2] + '_no-plugin.tar.gz'
assets = [a for a in release['assets'] if a['name'].endswith(suffix)]
if len(assets) != 1:
    sys.exit('Expected exactly one portable Linux release asset')
url = assets[0]['browser_download_url']
if not url.startswith('https://github.com/router-for-me/CLIProxyAPI/releases/download/'):
    sys.exit('Unexpected release download host/path')
print(url)
PY
    )"
    curl -fsSL --proto '=https' --proto-redir '=https' "$URL" -o "$TEMP_DIR/release.tar.gz"
    curl -fsSL --proto '=https' --proto-redir '=https' "${URL%/*}/checksums.txt" -o "$TEMP_DIR/checksums.txt"
    python3 - "$TEMP_DIR" "${URL##*/}" <<'PY'
import hashlib, pathlib, sys, tarfile
root = pathlib.Path(sys.argv[1])
archive = root / 'release.tar.gz'
checksums = [line.split()[0] for line in (root / 'checksums.txt').read_text().splitlines()
             if len(line.split()) == 2 and line.split()[1].lstrip('*') == sys.argv[2]]
if checksums != [hashlib.sha256(archive.read_bytes()).hexdigest()]:
    sys.exit('Release checksum mismatch; nothing installed')
with tarfile.open(archive) as package:
    binary = package.getmember('cli-proxy-api')
    if not binary.isfile():
        sys.exit('Release binary is not a regular file')
    (root / 'cli-proxy-api').write_bytes(package.extractfile(binary).read())
PY
    mkdir -p "$HOME/cliproxyapi"
    if ! cmp -s "$TEMP_DIR/cli-proxy-api" "$BINARY"; then
        install -m 0755 "$TEMP_DIR/cli-proxy-api" "$BINARY.new"
        mv -f "$BINARY.new" "$BINARY"  # rename is safe while the old binary runs
        UPDATED=true
    fi
fi

if [[ "$NEW_CONFIG" == true ]]; then
    mkdir -p "$HOME/.cli-proxy-api" "$(dirname "$CONFIG")"
    chmod 700 "$HOME/.cli-proxy-api"
    openssl rand -hex 32 > "$TEMP_DIR/client.key"
    openssl rand -hex 32 > "$TEMP_DIR/management.key"
    CLIENT_KEY="$(<"$TEMP_DIR/client.key")"
    MANAGEMENT_KEY="$(<"$TEMP_DIR/management.key")"
    cat > "$TEMP_DIR/config.yaml" <<EOF
config-version: 8
server:
  host: "127.0.0.1"
  port: 8317
  commercial-mode: true
management:
  allow-remote: false
  secret-key: "$MANAGEMENT_KEY"
  disable-auto-update-panel: true
access:
  api-keys: ["$CLIENT_KEY"]
routing:
  strategy: "round-robin"
  session-affinity: true
  session-affinity-ttl: "1h"
oauth:
  auth-dir: "~/.cli-proxy-api"
observability:
  logs:
    debug: false
    request-log: false
EOF
    install -m 0600 "$TEMP_DIR/client.key" "$HOME/.cli-proxy-api/client.key"
    install -m 0600 "$TEMP_DIR/management.key" "$HOME/.cli-proxy-api/management.key"
    install -m 0600 "$TEMP_DIR/config.yaml" "$CONFIG"
    unset CLIENT_KEY MANAGEMENT_KEY
    printf 'Created localhost-only config. Proxy keys are in ~/.cli-proxy-api/{client,management}.key\n'
else
    printf 'Preserving existing config, including its network binding and keys: %s\n' "$CONFIG"
fi

if [[ "$KERNEL" == Darwin ]]; then
    if [[ "$UPDATED" == true ]]; then
        brew services restart cliproxyapi
    else
        brew services start cliproxyapi
    fi
else
    UNIT="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/cliproxyapi.service"
    mkdir -p "$(dirname "$UNIT")"
    if [[ ! -e "$UNIT" && ! -L "$UNIT" ]]; then
        cat > "$UNIT" <<'EOF'
[Unit]
Description=CLIProxyAPI

[Service]
ExecStart="%h/cliproxyapi/cli-proxy-api" -config "%h/cliproxyapi/config.yaml"
WorkingDirectory=%h/cliproxyapi
Restart=on-failure
RestartSec=5
UMask=0077

[Install]
WantedBy=default.target
EOF
    fi
    if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
        systemctl --user daemon-reload
        [[ "$UPDATED" == false ]] || systemctl --user try-restart cliproxyapi.service
        systemctl --user enable --now cliproxyapi.service
        printf 'Starts at login. For startup before login, optionally run: loginctl enable-linger "$USER"\n'
    else
        printf 'No user systemd available. Start or restart manually: %q -config %q\n' "$BINARY" "$CONFIG"
    fi
fi

printf '\nConfig: %s\nSign in to your accounts:\n' "$CONFIG"
printf '  %q -config %q -claude-login\n' "$BINARY" "$CONFIG"
printf '  %q -config %q -codex-device-login\n' "$BINARY" "$CONFIG"
