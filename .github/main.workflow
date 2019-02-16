# Actions for trigger-pipeline

workflow "Test" {
  on = "push"
  resolves = "bats"
}

workflow "Lint" {
  on = "push"
  resolves = "shellcheck"
}

action "shellcheck" {
  uses = "actions/bin/shellcheck@master"
  args = "*.sh"
}

action "bats" {
  uses = "actions/bin/bats@master"
  args = "test/*.bats"
}