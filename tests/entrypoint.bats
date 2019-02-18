#!/usr/bin/env bats

load "$BATS_PATH/load.bash"

# Uncomment to enable stub debugging
# export CURL_STUB_DEBUG=/dev/tty

teardown() {
  unset BUILDKITE_API_ACCESS_TOKEN
  unset PIPELINE
  if [[ -f "$HOME/push.json" ]]; then rm "$HOME/push.json"; fi
}

@test "Without BUILDKITE_API_ACCESS_TOKEN prints error" {
  run $PWD/entrypoint.sh

  assert_output --partial "You must set the BUILDKITE_API_ACCESS_TOKEN environment variable"
  assert_failure
}

@test "Without PIPELINE prints error" {
  export BUILDKITE_API_ACCESS_TOKEN="123"

  run $PWD/entrypoint.sh

  assert_output --partial "You must set the PIPELINE environment variable"
  assert_failure
}

@test "Creates a build without a commit" {
  export BUILDKITE_API_ACCESS_TOKEN="123"
  export PIPELINE="my-org/my-pipeline"

  export GITHUB_SHA=a-sha
  export GITHUB_REF=refs/heads/a-branch
  export GITHUB_EVENT_PATH="tests/push.json"

  # TODO: This stub shouldn't pass without the JSON
  stub curl "--silent -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d : echo {}"

  run $PWD/entrypoint.sh

  assert_output --partial "Build created"
  assert_output --partial "Saved build JSON"
  assert_success

  unstub curl
}