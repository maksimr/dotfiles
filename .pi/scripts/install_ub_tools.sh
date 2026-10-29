#!/usr/bin/env bash
# Install or update Uncle Bob's tools in isolated uv environments.
# Requires git and uv (https://docs.astral.sh/uv/getting-started/installation/).
# Usage: .pi/scripts/install_ub_tools.sh

set -Eeuo pipefail

for cmd in git uv; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf 'Error: required command not found: %s\n' "$cmd" >&2
        exit 1
    fi
done

for tool in crapper dryer; do
    uv tool install --python 3.11 --upgrade "git+https://github.com/unclebob/$tool.git"
done

# mutator imports crapper but does not declare it as a package dependency.
uv tool install --python 3.11 --upgrade \
    --with 'git+https://github.com/unclebob/crapper.git' \
    'git+https://github.com/unclebob/mutator.git'

printf '\nInstalled crapper, dryer, and mutator. Add their directory to PATH if needed:\n'
printf 'export PATH="%s:$PATH"\n' "$(uv tool dir --bin)"
