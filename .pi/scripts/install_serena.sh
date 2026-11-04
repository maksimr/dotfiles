#!/usr/bin/env bash
# Install or update Serena (https://github.com/oraios/serena) in an isolated uv environment.
# Requires uv (https://docs.astral.sh/uv/getting-started/installation/).
# Usage: .pi/scripts/install_serena.sh

set -Eeuo pipefail

case "$(uname -s)" in
    Darwin|Linux) ;;
    *)
        printf 'Error: this installer supports macOS and Linux only.\n' >&2
        exit 1
        ;;
esac

if ! command -v uv >/dev/null 2>&1; then
    printf 'Error: required command not found: uv\n' >&2
    exit 1
fi

uv tool install --python 3.13 --upgrade serena-agent

printf '\nInstalled serena. Add its directory to PATH if needed:\n'
printf 'export PATH="%s:$PATH"\n' "$(uv tool dir --bin)"
printf 'Then run once: serena init\n'
