# Actions for trigger-pipeline

workflow "trigger-pipeline" {
  on = "push"
  resolves = "Lint & Test trigger-pipeline"
}

action "Lint trigger-pipeline" {
  uses = "actions/bin/shellcheck@master"
  args = "trigger-pipeline/*.sh"
}

action "Test trigger-pipeline" {
  uses = "actions/bin/bats@master"
  args = "trigger-pipeline/test/*.bats"
}

action "Lint & Test trigger-pipeline" {
  needs = ["Lint trigger-pipeline", "Test trigger-pipeline"]
}
