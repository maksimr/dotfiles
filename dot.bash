#!/bin/bash
# Main script which provide external
# functions for manipulatio dotfiles

if [ ! -d "$DOTFILE_DIR" ]
then
  export DOTFILE_DIR="$(cd $(dirname ${BASH_SOURCE[0]:-$0}); pwd)"
fi

function require() {
  local EXT="$2"
  [[ "$EXT" ]] || EXT="bash"
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
        echo "    dot help         Show this message"
        echo "    dot upgrade      Upgrade dotfiles"
        echo
        echo "    dot linking      Create symlinks"
        echo "    dot destroy      Remove created symlinks"
        echo "    dot save         Save changes in dotfile and push on remote server"
        echo "    dot alias        Show list of created symlinks"
        echo
        ;;
    "upgrade" )
        dot_upgrade
      ;;
    "linking" | "ln" )
        local DIST="$2"
        [[ "$DIST" ]] || DIST="$DOTFILE_DIR/export"

        local alias=$(dot_linking $DIST $3)

        echo "$alias" >> "$ALIASES"
        dot alias
      ;;
    "destroy" )
        local CURRENT_DIR="$(pwd)"
        local ALIASES_TMP="$DOTFILE_DIR/~aliases"

        cd "$HOME"

        if [ -f "$ALIASES" ]
        then
          local PATTERN="$2"
          [[ "$PATTERN" ]] || PATTERN=".*"

          for al in $(cat "$ALIASES" | sort -t. -u | grep -w "$PATTERN"); do
            rm -rf $al
            echo -e "    \\033[0;31m x \\033[0m $al"
          done
        fi

        echo "$(cat $ALIASES)" | sort -u | grep -v -w "$PATTERN" > "$ALIASES_TMP"
        mv "$ALIASES_TMP" "$ALIASES"

        cd "$CURRENT_DIR"
      ;;
     "save" | "commit" )
        dot_commit
      ;;
    "alias" )
        dot_alias $2 $3
      ;;
    * )
        dot help
      ;;
  esac

  return 0
}

unset require
