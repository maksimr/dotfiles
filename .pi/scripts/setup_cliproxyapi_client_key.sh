#!/usr/bin/env bash
# Prompt for a CLIProxyAPI client API key and save it to ~/.cli-proxy-api/client.key,
# the first place Pi and Claude Code look for it:
#   cat ~/.cli-proxy-api/client.key 2>/dev/null || security find-generic-password -s cliproxyapi-client -w
# The key must match one of access.api-keys in the proxy config. Overwrites any existing key.
#
# Usage: bash ~/.dotfiles/.pi/scripts/setup_cliproxyapi_client_key.sh

set +x
set -Eeuo pipefail
umask 077

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[[ $# -eq 0 ]] || die "usage: ${0##*/}"

read -rsp 'CLIProxyAPI client API key: ' KEY || true
printf '\n' >&2
[[ -n "$KEY" ]] || die 'empty key'
[[ "$KEY" =~ ^[[:graph:]]+$ ]] || die 'key must not contain spaces or control characters'

DIR="$HOME/.cli-proxy-api"
mkdir -p "$DIR"
chmod 700 "$DIR"
TMP="$(mktemp "$DIR/client.key.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
printf '%s\n' "$KEY" > "$TMP"
mv -f "$TMP" "$DIR/client.key"
unset KEY
printf 'Saved client key to %s\n' "$DIR/client.key"
