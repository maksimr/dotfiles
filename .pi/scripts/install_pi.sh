#!/usr/bin/env bash
# apt update && apt install -y curl unzip git
# curl -fsSL https://raw.githubusercontent.com/maksimr/dotfiles/main/.pi/scripts/install_pi.sh | bash
#
# Set up the pi coding agent on Linux (e.g. inside a Docker container):
#   1. Install fnm (checking its required dependencies).
#   2. Install Node.js 24 via fnm and make it the default.
#   3. Install dotfiles from https://github.com/maksimr/dotfiles.
#   4. Install the pi coding agent.
#   5. Run install_rtk.sh.
#   6. Add ~/.local/bin to PATH in the bash profile.

set -Eeuo pipefail

# Empty when piped via curl; the dotfiles clone is used as a fallback below.
SCRIPT_DIR=''
if [[ -f "${BASH_SOURCE:-}" ]]; then
    SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE:-}")" && pwd -P)"
fi
DOTFILES_REPO='https://github.com/maksimr/dotfiles'
DOTFILES_DIR="$HOME/.dotfiles"
BASH_PROFILE="$HOME/.bashrc"

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == Linux ]] || die 'this installer supports Linux only'

# fnm's install script needs curl and unzip; git is needed for the dotfiles.
for cmd in curl unzip git; do
    command -v "$cmd" >/dev/null 2>&1 || die "required command not found: $cmd"
done

# 1. fnm
if ! command -v fnm >/dev/null 2>&1 && [[ ! -x "$HOME/.local/share/fnm/fnm" ]]; then
    printf 'Installing fnm...\n'
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fi
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env)"

# 2. Node.js 24 as default
printf 'Installing Node.js 24...\n'
fnm install 24
fnm default 24
fnm use default

# 3. Dotfiles
if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    printf 'Cloning dotfiles...\n'
    git clone --depth 1 "$DOTFILES_REPO" "$DOTFILES_DIR"
fi
bash "$DOTFILES_DIR/bootstrap.sh"

# 4. pi coding agent
printf 'Installing pi...\n'
npm install -g @earendil-works/pi-coding-agent

# 5. rtk
[[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/install_rtk.sh" ]] ||
    SCRIPT_DIR="$DOTFILES_DIR/.pi/scripts"
bash "$SCRIPT_DIR/install_rtk.sh"

# 6. PATH and fnm in the bash profile
touch "$BASH_PROFILE"
if ! grep -qs '\.local/bin' "$BASH_PROFILE"; then
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >>"$BASH_PROFILE"
fi
if ! grep -qs 'fnm env' "$BASH_PROFILE"; then
    {
        printf 'export PATH="$HOME/.local/share/fnm:$PATH"\n'
        printf 'eval "$(fnm env --shell bash)"\n'
    } >>"$BASH_PROFILE"
fi

printf '\npi %s installed with Node.js %s.\n' "$(pi --version)" "$(node --version)"
