#!../../lib/bats/bin/bats

load ../test_helper

@test "It should print aliases" {
  require dot_alias
  run dot_alias

  [ "$(echo $output | grep 'config/bash')" ]
}

@test "It should print aliases matching passed patter" {
  require dot_alias
  run dot_alias 'file'

  [ "$(echo $output | grep 'file')" ]
  [ ! "$(echo $output | grep 'config')" ]
}

@test "It should create alias" {
  require dot_alias
  mv "$DOTFILE_DIR/aliases" "$DOTFILE_DIR/_aliases"

  run dot_alias "aliases" "alias"
  run dot_alias

  rm -rf "$DOTFILE_DIR/aliases"
  mv "$DOTFILE_DIR/_aliases" "$DOTFILE_DIR/aliases"

  [ "$(echo $output | grep 'alias')" ]
}

#vim: set ft=sh
