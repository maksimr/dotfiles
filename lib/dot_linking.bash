#!/bin/bash
# This function create links(symlink)
# on source files and directories like 'file.symlink' to 'file'.
# Note if file or directory start with '_' then it will be replaced
# on '.'

# @param {[Dir]} DIR The directory where the source files
# by default $DOTFILE_DIR
# @param {[Dir]} DIST The destination directory where will be created links
# by default $HOME
function dot_linking() {
  local DIR="${1:-$DOTFILE_DIR}"
  local DIST="${2:-$HOME}"
  local CURRENT_DIR="$(pwd)"

  # change current directory
  cd "$DIST"

  # iterate by source files and create links
  for file in $(find $DIR -iname "*.symlink"); do
    # get directory name relative DIST directory
    local directory="$(dirname $file)"
    directory="${directory#"$DIR"}"
    directory="${directory#*/}"

    # get name dotfile .file from file.symlink
    local lfile="$(basename ${file%.symlink})"

    # replace leader '_' on '.'
    directory="${directory/#_/.}"
    lfile="${lfile/#_/.}"

    if [ "$directory" ]
    then
      # if directory doesn't exist
      # then create it
      mkdir -p "$directory"
      lfile="$directory/$lfile"
    fi

    # if file exist then prompt message
    if [ -e "$lfile" ]
    then
      if [ "$DOT_LINKING_SOFT" ]
      then
        continue
      fi

      echo "" 1>&0
      echo "linking: replace $lfile?" 1>&0
      read REPLY

      # failed to load module: zsh/regex
      if [ "$REPLY" = "Y" -o "$REPLY" = "y" ]
      then
        rm -rf "$lfile"
        echo "$lfile"
        ln -s $file $lfile
      fi

    else
      echo "$lfile"
      ln -s $file $lfile
    fi
  done

  # restore current directory
  cd "$CURRENT_DIR"

  return 0
}

function dot_linking_soft() {
  export DOT_LINKING_SOFT='true'

  dot_linking $1 $2

  unset DOT_LINKING_SOFT
}
