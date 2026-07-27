#!/usr/bin/env bash
# Install rtk on macOS (Homebrew) or Linux (official install script) and
# initialize it globally for the pi agent.

set -Eeuo pipefail

if command -v brew >/dev/null 2>&1; then
    brew install rtk
elif [[ "$(uname -s)" == "Linux" ]]; then
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
else
    printf 'Error: no supported installation method (need Homebrew or Linux).\n' >&2
    exit 1
fi

rtk init -g --agent pi
