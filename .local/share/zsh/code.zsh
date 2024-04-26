if [ "$(command -v wslpath)"  ]; then
  function code() {
    VSCODE='cmd.exe /c code'
    WSL_DISTRO_NAME=$(wslpath -m / | awk -F/ '{print $4}')

    VSCODE_ARGS=()
    for arg in "$@"; do
      if [ -f "$arg" ] || [ -d "$arg" ]; then
        VSCODE_ARGS+=("$(wslpath -a "$FILEPATH")")
      else
        VSCODE_ARGS+=("$arg")
      fi
    done

    $VSCODE --remote wsl+$WSL_DISTRO_NAME "${VSCODE_ARGS[@]}"
  }
fi
