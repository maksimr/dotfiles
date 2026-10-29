#!/usr/bin/env bash
# Install uv on macOS or Linux without modifying shell profiles.
# Usage: .pi/scripts/install_uv.sh

set -Eeuo pipefail

case "$(uname -s)" in
    Darwin|Linux) ;;
    *)
        printf 'Error: this installer supports macOS and Linux only.\n' >&2
        exit 1
        ;;
esac

if command -v uv >/dev/null 2>&1; then
    uv --version
    exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
    printf 'Error: required command not found: curl\n' >&2
    exit 1
fi

INSTALL_DIR="${UV_INSTALL_DIR:-$HOME/.local/bin}"
INSTALLER="$(mktemp)"
trap 'rm -f "$INSTALLER"' EXIT

curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
    https://astral.sh/uv/install.sh -o "$INSTALLER"
UV_INSTALL_DIR="$INSTALL_DIR" UV_NO_MODIFY_PATH=1 sh "$INSTALLER"

"$INSTALL_DIR/uv" --version
printf 'Add uv to PATH if needed:\nexport PATH="%s:$PATH"\n' "$INSTALL_DIR"
