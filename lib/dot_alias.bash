#!/bin/bash
# Create and show alias

# @param {[RegExp|File]} PATTERN The pattern or name of file
# @param {[String]} ALIAS The name of alias
function dot_alias() {
  local ALIASES="$DOTFILE_DIR/aliases"

  # if count of passed arguments
  # less/equal one then show list of
  # aliases
  if [ $# -le 1 ]
  then
    if [ ! -e "$ALIASES" ];then
      return
    fi

    local PATTERN="$1"
    [[ "$PATTERN" ]] || PATTERN=".*"

    for al in $(cat "$ALIASES" | sort -u | grep "$PATTERN"); do
      echo -e "    \\033[1;32m • \\033[0m $al"
    done
    return
  fi

  # create symlink and add it to aliases file
  ln -s $1 "$HOME/$2"

  echo $2 >> $ALIASES
  echo -e "    \\033[1;32m • \\033[0m $2"

  return 0
}
