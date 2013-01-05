#!/bin/bash
# Commit and push changes in dotfiles

# @param {[Dir]} DIR The dotfiles directory
# by default $DOTFILE_DIR
function dot_commit() {
  local DIR="${1:-$DOTFILE_DIR}"
  local CURRENT_DIR="$(pwd)"
  local message="${USER} "
  cd "$DIR"

  local changes="$(git status --porcelain)"

  echo 'Save changes in Dotfiles directory....'

  if [ "$changes"  ]; then
    for line in $changes; do
      #?? - add new file
      #M  - change existing file
      #D  - delete existing file
      case "$line" in
        "??" | "D" | "M")
          line="${line}"
          ;;
        * )
          line=" ${line}"
          ;;
      esac

      message="${message}${line}"
    done

    git add -A
    git commit -m "${message}"
    git push origin --progress 2>/dev/null
    echo "Wooh $USER...Changes was saved successfully!"
  else
    echo 'You did not change anything'
  fi

  cd "$CURRENT_DIR"
  return 0
}
