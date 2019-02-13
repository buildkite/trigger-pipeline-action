# Actions for trigger-pipeline

workflow "Test trigger-pipeline" {
  on = "push"
  resolves = "trigger-pipeline bats"
}

workflow "Lint trigger-pipeline" {
  on = "push"
  resolves = "trigger-pipeline shellcheck"
}

action "trigger-pipeline shellcheck" {
  uses = "actions/bin/shellcheck@master"
  args = "trigger-pipeline/*.sh"
}

action "trigger-pipeline bats" {
  uses = "actions/bin/bats@master"
  args = "trigger-pipeline/test/*.bats"
}