#!../lib/bats/bin/bats

bats="$(cd $(dirname ${BASH_SOURCE[0]:-$0}); pwd)/../lib/bats/bin/bats"

@test "dot_alias test" {
  run bats tests/dot_alias/dot_alias.bats
  echo $output
  [ $status -eq 0  ]
}

@test "dot_linking test" {
  run bats tests/dot_linking/dot_linking.bats
  echo $output
  [ $status -eq 0  ]
}
