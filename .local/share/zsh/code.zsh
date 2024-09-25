if [ "$(command -v wslpath)"  ]; then
  function code() {
    WSL_DISTRO_NAME=$(wslpath -m / | awk -F/ '{print $4}')

    VSCODE_ARGS=()
    for arg in "$@"; do
      if [ -f "$arg" ] || [ -d "$arg" ]; then
        VSCODE_ARGS+=("$(wslpath -a "$FILEPATH")")
      else
        VSCODE_ARGS+=("$arg")
      fi
    done

    # prefer code-insiders over code if it's installed
    CODE_EXE_NAME=$(\
      cmd.exe /c code-insiders --version > /dev/null 2>&1 \
      && echo "code-insiders" \
      || echo "code" \
    )

    cmd.exe /c $CODE_EXE_NAME --remote wsl+$WSL_DISTRO_NAME "${VSCODE_ARGS[@]}"
  }
fi
