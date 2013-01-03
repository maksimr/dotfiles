#!/bin/bash
# Pull changes from origin remote repository and
# update git submodules

# @param {[Dir]} DIR The dotfiles directory
# by default $DOTFILE_DIR
function dot_upgrade() {
  local DIR="$1"
  local CURRENT_DIR="$(pwd)"
  [[ "$DIR" ]] || DIR="$DOTFILE_DIR"

  cd "$DIR"

  echo 'Upgrading Dotfiles directory....'

  if [ "$(git pull origin master 2>/dev/null)" ]
  then
      echo '....updating submodules....'
      git submodule update --init --recursive 2>/dev/null

      echo 'Dotfiles has been updated and/or is at the current version.'
  else
      echo -e '\033[0;31m There was an error updating. Try again later? \033[0m\n'
  fi

  cd "$CURRENT_DIR"
  return 0
}
