#!/usr/bin/env bats

@test "adds the defaults" {
  run src/app
  [ "$status" -eq 0 ]
  [ "$output" = 5 ]
}

@test "adds from the environment" {
  A=-1 B=1 run src/app
  [ "$output" = 0 ]
}
