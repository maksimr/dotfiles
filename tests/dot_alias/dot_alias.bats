#!../../lib/bats/bin/bats

load ../test_helper

@test "It should print aliases" {
  require dot_alias
  run dot_alias

  [[ "$output" == *config/bash* ]]
}

@test "It should print aliases matching passed patter" {
  require dot_alias
  run dot_alias 'file'

  [[ "$output" == *file* ]]
  [[ "$output" != *config* ]]
}

@test "It should create alias" {
  require dot_alias
  export DOTFILE_DIR="$HOME"

  run dot_alias "aliases" "alias"
  run dot_alias

  [[ "$output" == *alias* ]]
}

#vim: set ft=sh
