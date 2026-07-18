#!/usr/bin/env bash
# Install Headroom into one self-contained directory on macOS or Linux.
#
# Usage:
#   ./install_headroom.sh /path/to/headroom
#
# Nothing is added to the system Python or to the user's global PATH. If no
# Python 3.10+ is available on PATH, a uv-managed Python 3.13 is placed under
# the requested installation directory and used only by Headroom.

set -Eeuo pipefail

HEADROOM_PACKAGE='headroom-ai[all]'
PY_MIN_CHECK='import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)'

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

if [[ $# -ne 1 || -z "$1" ]]; then
    printf 'Usage: %s INSTALL_DIR\nExample: %s "$HOME/.headroom"\n' \
        "${0##*/}" "${0##*/}" >&2
    exit 2
fi

KERNEL="$(uname -s)"
[[ "$KERNEL" == Darwin || "$KERNEL" == Linux ]] ||
    die "this installer supports macOS and Linux only (detected kernel: $KERNEL)"

for cmd in curl tar mktemp install grep; do
    command -v "$cmd" >/dev/null 2>&1 || die "required command not found: $cmd"
done

mkdir -p -- "$1"
INSTALL_DIR="$(CDPATH='' cd -- "$1" && pwd -P)"
VENV_DIR="$INSTALL_DIR/venv"
BIN_DIR="$INSTALL_DIR/bin"
UV_BIN="$INSTALL_DIR/.tools/uv"
mkdir -p "$INSTALL_DIR/.tools" "$INSTALL_DIR/.cache/uv" "$BIN_DIR"

TEMP_DIR=''
trap '[[ -z "$TEMP_DIR" ]] || rm -rf "$TEMP_DIR"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Every uv invocation keeps its cache and managed interpreters below INSTALL_DIR.
uv() {
    UV_CACHE_DIR="$INSTALL_DIR/.cache/uv" \
    UV_PYTHON_INSTALL_DIR="$INSTALL_DIR/python" \
        "$UV_BIN" "$@"
}

python_ok() { "$1" -c "$PY_MIN_CHECK" >/dev/null 2>&1; }

# Print the first PATH-visible interpreter whose actual version is >= 3.10,
# preferring 3.13 because it is Headroom's recommended CLI version.
find_system_python() {
    local name path
    for name in python3.13 python3.14 python3.15 python3.12 python3.11 \
                python3.10 python3 python; do
        path="$(command -v "$name" 2>/dev/null)" || continue
        if python_ok "$path"; then
            printf '%s\n' "$path"
            return 0
        fi
    done
    return 1
}

# Print 'gnu' or 'musl' for the current Linux system; fail if undeterminable.
detect_linux_libc() {
    local ldd_output='' loader
    if command -v ldd >/dev/null 2>&1; then
        # musl's ldd exits non-zero and reports on stderr; capture both anyway.
        ldd_output="$(ldd --version 2>&1 || true)"
    fi
    if grep -qi 'musl' <<<"$ldd_output"; then
        printf 'musl\n'
    elif grep -Eqi 'glibc|gnu libc|gnu c library' <<<"$ldd_output" ||
         getconf GNU_LIBC_VERSION >/dev/null 2>&1; then
        printf 'gnu\n'
    else
        for loader in /lib/ld-musl-*.so*; do
            [[ -e "$loader" ]] && { printf 'musl\n'; return 0; }
        done
        return 1
    fi
}

# Print the uv release target triple for this kernel/architecture/libc.
uv_target() {
    local arch libc
    arch="$(uname -m)"
    if [[ "$KERNEL" == Darwin ]]; then
        case "$arch" in
            arm64|aarch64) printf 'aarch64-apple-darwin\n' ;;
            x86_64)        printf 'x86_64-apple-darwin\n' ;;
            *)             die "unsupported macOS architecture: $arch" ;;
        esac
    else
        libc="$(detect_linux_libc)" ||
            die 'could not determine whether this Linux system uses glibc or musl'
        case "$arch" in
            x86_64|amd64)  printf 'x86_64-unknown-linux-%s\n' "$libc" ;;
            aarch64|arm64) printf 'aarch64-unknown-linux-%s\n' "$libc" ;;
            *)             die "unsupported Linux architecture: $arch" ;;
        esac
    fi
}

install_local_uv() {
    local target url
    # Re-download when the local copy is missing, truncated, or built for a
    # different machine (e.g. the directory was copied across architectures).
    if [[ -x "$UV_BIN" ]] && "$UV_BIN" --version >/dev/null 2>&1; then
        return 0
    fi
    target="$(uv_target)"
    url="https://github.com/astral-sh/uv/releases/latest/download/uv-${target}.tar.gz"
    TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/headroom-install.XXXXXX")"

    printf 'Downloading a local copy of uv...\n'
    curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 \
        "$url" -o "$TEMP_DIR/uv.tar.gz" || die "failed to download uv from $url"
    tar -xzf "$TEMP_DIR/uv.tar.gz" -C "$TEMP_DIR" || die 'failed to extract the uv archive'
    [[ -f "$TEMP_DIR/uv-$target/uv" ]] || die 'the downloaded archive did not contain uv'
    install -m 0755 "$TEMP_DIR/uv-$target/uv" "$UV_BIN"
    rm -rf "$TEMP_DIR"
    TEMP_DIR=''
}

SYSTEM_PYTHON=''
if SYSTEM_PYTHON="$(find_system_python)"; then
    printf 'Using existing Python %s: %s\n' \
        "$("$SYSTEM_PYTHON" -c 'import platform; print(platform.python_version())')" \
        "$SYSTEM_PYTHON"
else
    printf 'No Python 3.10+ found on PATH; Python 3.13 will be installed locally.\n'
fi

install_local_uv

if python_ok "$VENV_DIR/bin/python"; then
    printf 'Reusing Headroom virtual environment: %s\n' "$VENV_DIR"
elif [[ -n "$SYSTEM_PYTHON" ]]; then
    rm -rf "$VENV_DIR"
    uv venv --python "$SYSTEM_PYTHON" --no-python-downloads "$VENV_DIR"
else
    # --no-bin prevents uv from creating Python links in ~/.local/bin.
    uv python install 3.13 --no-bin
    rm -rf "$VENV_DIR"
    uv venv --python 3.13 --managed-python --no-python-downloads "$VENV_DIR"
fi

printf 'Installing %s...\n' "$HEADROOM_PACKAGE"
uv pip install --python "$VENV_DIR/bin/python" --upgrade "$HEADROOM_PACKAGE"

[[ -x "$VENV_DIR/bin/headroom" ]] ||
    die 'installation completed without creating the headroom command'
# A real directory here would swallow the link (ln would create a nested
# symlink inside it); refuse rather than delete user data.
[[ -d "$BIN_DIR/headroom" && ! -L "$BIN_DIR/headroom" ]] &&
    die "cannot create the headroom command: $BIN_DIR/headroom is a directory"
ln -sfn '../venv/bin/headroom' "$BIN_DIR/headroom"

PYTHON_VERSION="$("$VENV_DIR/bin/python" -c 'import platform; print(platform.python_version())')"
HEADROOM_VERSION="$("$VENV_DIR/bin/python" -c \
    'from importlib.metadata import version; print(version("headroom-ai"))')"

printf '\nHeadroom %s installed successfully with Python %s.\n' \
    "$HEADROOM_VERSION" "$PYTHON_VERSION"
printf 'Command: %s\n' "$BIN_DIR/headroom"
printf 'Run now: "%s" doctor\n' "$BIN_DIR/headroom"
printf 'Optional PATH setup: export PATH="%s:$PATH"\n' "$BIN_DIR"
