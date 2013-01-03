#!/bin/bash
# Pull changes from origin remote repository and
# update git submodules

# @param {[Dir]} DIR The dotfiles directory
# by default $DOTFILE_DIR
function dot_upgrade() {
  local DIR="$1"
  local CURRENT_DIR="$(pwd)"
  if [ ! "$DIR" ];then
    DIR="$DOTFILE_DIR"
  fi

  cd "$DIR"

  echo 'Upgrading Dotfiles directory....'
  local CHANGES="$(git pull origin master 2>/dev/null)"


  if [ "$CHANGES" ]
  then
      echo

      if [ "$CHANGES" = 'Already up-to-date.' ]; then
        echo -e '\033[1;32mYou are already up-to-date.\033[0m'
      else

        git submodule update --init --recursive 2>/dev/null

        echo
        echo -e '\033[1;32mDotfiles has been updated.\033[0m'
      fi

      echo
  else
      echo -e '\033[0;31m There was an error updating. Try again later? \033[0m\n'
  fi

  cd "$CURRENT_DIR"
  return 0
}
