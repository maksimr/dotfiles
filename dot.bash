#!/bin/bash
# Main script which provide external
# functions for manipulatio dotfiles

if [ ! -d "$DOTFILE_DIR" ]
then
  export DOTFILE_DIR="$(cd $(dirname ${BASH_SOURCE[0]:-$0}); pwd)"
fi

# add bin dotfiles to PATH
export PATH="$DOTFILE_DIR/bin:$PATH"

function require() {
  local EXT="$2"
  if [ ! "$EXT" ];then
    EXT="bash"
  fi
  source "$DOTFILE_DIR/lib/$1.$EXT"
}

require dot_alias
require dot_commit
require dot_linking
require dot_update

function dot() {
  local ALIASES="$DOTFILE_DIR/aliases"

  case "$1" in
    "help" | "--help" )
        echo
        echo "Dotfiles Manager"
        echo
        echo "Usage:"
        echo "    dot help                  Show this message"
        echo "    dot upgrade               Upgrade dotfiles"
        echo "    dot [linking | ln]        Create symlinks"
        echo "    dot lns                   Soft linking. Doesn't replace existing files"
        echo "    dot [destroy | rm]        Remove all created symlinks"
        echo "    dot destroy <alias>       Remove symlink with name <alias>"
        echo "    dot [save | ci]           Save changes in dotfile and push to remote server"
        echo "    dot [alias | ls]          Show list of created symlinks"
        echo "    dot alias <pattern>       Show all aliases beginning with <pattern>"
        echo "    dot alias <file> <alias>  Create symlink <alias> on file/directory <file>"
        echo
        ;;
    "init" )
          local CURRENT_DIR="$(pwd)"
          cd "$DOTFILE_DIR"
          git submodule update --init --recursive 2>/dev/null
          cd $CURRENT_DIR

          dot upgrade
        ;;
    "upgrade" )
        local DIST="$2"
        if [ ! "$DIST" ]; then
          DIST="$DOTFILE_DIR/export"
        fi

        dot_upgrade
        local alias="$(dot_linking_soft $DIST $3)"
        echo "$alias" >> "$ALIASES"
        dot alias
      ;;
    "linking" | "ln" )
        local DIST="$2"
        if [ ! "$DIST" ]; then
          DIST="$DOTFILE_DIR/export"
        fi

        local alias="$(dot_linking $DIST $3)"

        echo "$alias" >> "$ALIASES"
        dot alias
      ;;
    "lns" )
      # soft linking
        local DIST="$2"
        if [ ! "$DIST" ]; then
          DIST="$DOTFILE_DIR/export"
        fi
        local alias="$(dot_linking_soft $DIST $3)"
        echo "$alias" >> "$ALIASES"
      ;;
    "destroy" | "rm" )
        local CURRENT_DIR="$(pwd)"
        local ALIASES_TMP="$DOTFILE_DIR/~aliases"

        cd "$HOME"

        if [ -f "$ALIASES" ]
        then
          local PATTERN="$2"
          if [ ! "$PATTERN" ]; then
             PATTERN=".*"
          fi

          for al in $(cat "$ALIASES" | sort -t. -u | grep -w "$PATTERN"); do
            rm -rf $al
            echo -e "    \\033[0;31m x \\033[0m $al"
          done
        fi

        echo "$(cat $ALIASES)" | sort -u | grep -v -w "$PATTERN" > "$ALIASES_TMP"
        mv "$ALIASES_TMP" "$ALIASES"

        cd "$CURRENT_DIR"
      ;;
     "save" | "ci" )
        dot_commit
      ;;
    "alias" | "ls" )
        dot_alias $2 $3
      ;;
    * )
        dot help
      ;;
  esac

  return 0
}

unset require
