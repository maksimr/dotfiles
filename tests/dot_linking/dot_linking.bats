#!../../lib/bats/bin/bats

load ../test_helper

@test "It should create symlink" {
  require dot_linking
  run dot_linking

  [ -L "$HOME/file" ]
}

@test "It should replace leader '_' on '.'" {
  require dot_linking
  run dot_linking

  [ -L "$HOME/.underline_file" ]
}

# It must repeat structure source directory
# and create nested symlink
@test "It should create nested symlink" {
  require dot_linking
  run dot_linking

  [ -L "$HOME/directory/nested_file" ]
  [ -L "$HOME/directory/second/second_nested_file" ]
}

@test "It should create symlink on files from passed directory" {
  require dot_linking
  run dot_linking "$BATS_TEST_DIRNAME/custom_dotfiles"

  [ -L "$HOME/custom_file" ]
}

@test "It should create symlink on directory" {
  require dot_linking
  run dot_linking

  [ -L "$HOME/.dir" ]
}

#vim: set ft=sh
