#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment to enable stub debugging
# export CURL_STUB_DEBUG=/dev/tty

setup() {
  export GITHUB_SHA=a-sha
  export GITHUB_REF=refs/heads/a-branch
  export GITHUB_EVENT_PATH="tests/push.json"
  export GITHUB_ACTION="push"

  export HOME='/root' # necessary for output checking
}

teardown() {
  unset BUILDKITE_API_ACCESS_TOKEN
  unset PIPELINE
  if [[ -f "$HOME/push.json" ]]; then rm "$HOME/push.json"; fi
}

@test "Prints error and fails if \$BUILDKITE_API_ACCESS_TOKEN isn't set" {
  run "${PWD}"/entrypoint.sh

  assert_output --partial "You must set the BUILDKITE_API_ACCESS_TOKEN environment variable"
  assert_failure
}

@test "Prints error and fails if \$PIPELINE isn't set" {
  export BUILDKITE_API_ACCESS_TOKEN="123"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "You must set the PIPELINE environment variable"
  assert_failure
}

@test "Creates a build with defaults" {
  export BUILDKITE_API_ACCESS_TOKEN="123"
  export PIPELINE="my-org/my-pipeline"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"}}'
  RESPONSE_JSON='{"id": "ID", "web_url": "https://buildkite.com/build-url"}'

  stub curl "--silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_output --partial "::set-output name=json::$RESPONSE_JSON"
  assert_output --partial "::set-output name=url::https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Creates a build with commit from \$COMMIT" {
  export BUILDKITE_API_ACCESS_TOKEN="123"
  export PIPELINE="my-org/my-pipeline"
  export COMMIT="custom-commit"

  EXPECTED_JSON='{"commit":"custom-commit","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"}}'
  RESPONSE_JSON='{"id": "ID", "web_url": "https://buildkite.com/build-url"}'

  stub curl "--silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_output --partial "::set-output name=json::$RESPONSE_JSON"
  assert_output --partial "::set-output name=url::https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Creates a build with branch from \$BRANCH" {
  export BUILDKITE_API_ACCESS_TOKEN="123"
  export PIPELINE="my-org/my-pipeline"
  export BRANCH="custom-branch"

  EXPECTED_JSON='{"commit":"a-sha","branch":"custom-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"}}'
  RESPONSE_JSON='{"id": "ID", "web_url": "https://buildkite.com/build-url"}'

  stub curl "--silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_output --partial "::set-output name=json::$RESPONSE_JSON"
  assert_output --partial "::set-output name=url::https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Creates a build with branch from \$MESSAGE" {
  export BUILDKITE_API_ACCESS_TOKEN="123"
  export PIPELINE="my-org/my-pipeline"
  export MESSAGE="A custom message"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"A custom message","author":{"name":"The Pusher","email":"pusher@pusher.com"}}'
  RESPONSE_JSON='{"id": "ID", "web_url": "https://buildkite.com/build-url"}'

  stub curl "--silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_output --partial "::set-output name=json::$RESPONSE_JSON"
  assert_output --partial "::set-output name=url::https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Creates a build with build env vars from \$BUILD_ENV_VARS" {
  export BUILDKITE_API_ACCESS_TOKEN="123"
  export PIPELINE="my-org/my-pipeline"
  export BUILD_ENV_VARS="{\"FOO\": \"bar\"}"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"FOO":"bar"}}'
  RESPONSE_JSON='{"id": "ID", "web_url": "https://buildkite.com/build-url"}'

  stub curl "--silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_output --partial "::set-output name=json::$RESPONSE_JSON"
  assert_output --partial "::set-output name=url::https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Writes outputs to \$GITHUB_OUTPUT file if defined" {
  TEST_TEMP_DIR="$(temp_make)"

  export BUILDKITE_API_ACCESS_TOKEN="123"
  export PIPELINE="my-org/my-pipeline"
  export BUILD_ENV_VARS="{\"FOO\": \"bar\"}"
  export GITHUB_OUTPUT=$TEST_TEMP_DIR/github_output_file

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"FOO":"bar"}}'
  RESPONSE_JSON='{"id": "ID", "web_url": "https://buildkite.com/build-url"}'

  stub curl "--silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  assert_file_not_exist $GITHUB_OUTPUT
  assert_not_exist $GITHUB_OUTPUT

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_file_exist $GITHUB_OUTPUT
  assert_exist $GITHUB_OUTPUT

  github_output=$(cat $GITHUB_OUTPUT)
  expected_output=$(echo -e "json=$RESPONSE_JSON\nurl=https://buildkite.com/build-url\n")
  assert_equal "$github_output" "$expected_output"

  assert_success

  unstub curl
}

@test "Prints response message and fails when no build id is returned" {
  export BUILDKITE_API_ACCESS_TOKEN="123"
  export PIPELINE="my-org/my-pipeline"
  export BUILD_ENV_VARS="{\"FOO\": \"bar\"}"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"FOO":"bar"}}'
  RESPONSE_JSON='{"message": "error message"}'

  stub curl "--silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run "${PWD}"/entrypoint.sh

  assert_output --partial 'Buildkite API call failed: "error message"'

  assert_failure

  unstub curl
}

@test "Prints error and fails if \$BUILD_ENV_VARS is not valid JSON" {
  export BUILDKITE_API_ACCESS_TOKEN="123"
  export PIPELINE="my-org/my-pipeline"
  export BUILD_ENV_VARS="broken"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Error: BUILD_ENV_VARS provided invalid JSON: broken"

  assert_failure
}
