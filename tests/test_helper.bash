# Run before each test case
setup() {
  HOME_DIR="$BATS_TMPDIR/bats_tmp"
  mkdir -p $HOME_DIR

  export DOTFILE_DIR="$BATS_TEST_DIRNAME/dotfiles"
  export HOME="$HOME_DIR"
}

# Run after each test case
teardown() {
  rm -rf "$HOME_DIR"
}

# Load source library
require() {
  #load "../../lib/$1"
  source "$(cd $(dirname ${BASH_SOURCE[0]:-$0}); pwd)/../lib/$1.bash"
}
