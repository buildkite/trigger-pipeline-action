#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment to enable stub debugging
# export CURL_STUB_DEBUG=/dev/tty

setup() {
  export GITHUB_SHA=a-sha
  export GITHUB_REF=refs/heads/a-branch
  export GITHUB_EVENT_PATH="tests/push.json"
  export GITHUB_ACTION="push"
  export GITHUB_REPOSITORY="buildkite/test-repo"
  export HOME='/root' # necessary for output checking
}

teardown() {
  unset INPUT_BUILDKITE_API_ACCESS_TOKEN
  unset INPUT_PIPELINE
  if [[ -f "$HOME/push.json" ]]; then rm "$HOME/push.json"; fi
}

@test "Prints error and fails if \${{ inputs.buildkite_api_access_token }} isn't set" {
  run "${PWD}"/entrypoint.sh
  assert_output --partial "You must set the buildkite_api_access_token input parameter"
  assert_failure
}

@test "Prints error and fails if \${{ inputs.pipeline }}  isn't set" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"

  run "${PWD}"/entrypoint.sh 
  assert_output --partial "You must set the pipeline input parameter" 
  assert_failure
}

@test "Creates a build with defaults" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export GITHUB_EVENT_NAME="create"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_JSON='{"web_url": "https://buildkite.com/build-url"}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_output --partial "::set-output name=json::$RESPONSE_JSON"
  assert_output --partial "::set-output name=url::https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Creates a build with commit from \${{ inputs.commit }}" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export INPUT_COMMIT="custom-commit"
  export GITHUB_EVENT_NAME="create"

  EXPECTED_JSON='{"commit":"custom-commit","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_JSON='{"web_url": "https://buildkite.com/build-url"}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_output --partial "::set-output name=json::$RESPONSE_JSON"
  assert_output --partial "::set-output name=url::https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Creates a build with branch from \${{ inputs.branch }}" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export INPUT_BRANCH="custom-branch"
  export GITHUB_EVENT_NAME="create"

  EXPECTED_JSON='{"commit":"a-sha","branch":"custom-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_JSON='{"web_url": "https://buildkite.com/build-url"}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_output --partial "::set-output name=json::$RESPONSE_JSON"
  assert_output --partial "::set-output name=url::https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Creates a build from pull request" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export GITHUB_EVENT_PATH="tests/pullrequest.json"
  export GITHUB_EVENT_NAME="create"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"pull_request_id":"1337","env":{"GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_JSON='{"web_url": "https://buildkite.com/build-url"}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_output --partial "::set-output name=json::$RESPONSE_JSON"
  assert_output --partial "::set-output name=url::https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Creates a build with branch from \${{ inputs.message }}" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export INPUT_MESSAGE="A custom message"
  export GITHUB_EVENT_NAME="create"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"A custom message","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_JSON='{"web_url": "https://buildkite.com/build-url"}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_output --partial "::set-output name=json::$RESPONSE_JSON"
  assert_output --partial "::set-output name=url::https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Creates a build with build env vars from \${{ inputs.build_env_vars }}" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export INPUT_BUILD_ENV_VARS="{\"FOO\": \"bar\"}"
  export GITHUB_EVENT_NAME="create"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"FOO":"bar","GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_JSON='{"web_url": "https://buildkite.com/build-url"}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_output --partial "::set-output name=json::$RESPONSE_JSON"
  assert_output --partial "::set-output name=url::https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Creates a build with build meta-data vars from \${{ inputs.build_meta_data }}" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export BUILD_META_DATA="{\"FOO\": \"bar\"}"
  export GITHUB_EVENT_NAME="create"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"meta_data":{"FOO":"bar"},"env":{"GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_JSON='{"web_url": "https://buildkite.com/build-url"}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_output --partial "::set-output name=json::$RESPONSE_JSON"
  assert_output --partial "::set-output name=url::https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Creates a build with ignore_pipeline_branch_filters set to true from \${{ inputs.ignore_pipeline_branch_filter }}" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export INPUT_BUILD_ENV_VARS="{\"FOO\": \"bar\"}"
  export IGNORE_PIPELINE_BRANCH_FILTER="true"
  export GITHUB_EVENT_NAME="create"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"ignore_pipeline_branch_filters":true,"env":{"FOO":"bar","GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_JSON='{"web_url": "https://buildkite.com/build-url"}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run $PWD/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"
  assert_output --partial "::set-output name=json::$RESPONSE_JSON"
  assert_output --partial "::set-output name=url::https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Writes outputs to \$GITHUB_OUTPUT file if defined" {
  TEST_TEMP_DIR="$(temp_make)"

  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export INPUT_BUILD_ENV_VARS="{\"FOO\": \"bar\"}"
  export GITHUB_OUTPUT=$TEST_TEMP_DIR/github_output_file
  export GITHUB_EVENT_NAME="create"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"FOO":"bar","GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_JSON='{"web_url": "https://buildkite.com/build-url"}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

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

@test "Prints curl error on HTTP error" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export GITHUB_EVENT_NAME="create"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo 'curl: (22) The requested URL returned error: 401' >&2; exit 22"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "curl: (22) The requested URL returned error: 401"
  refute_output --partial "Buildkite API call failed"

  assert_failure 22

  unstub curl
}

@test "Prints curl error and ignores non-JSON response on HTTP error" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export GITHUB_EVENT_NAME="create"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_HTML='<html></html>'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_HTML'; echo 'curl: (22) The requested URL returned error: 401' >&2; exit 22"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "curl: (22) The requested URL returned error: 401"
  refute_output --partial "Buildkite API call failed"
  refute_output --partial "parse error"

  assert_failure 22

  unstub curl
}

@test "Prints curl error but not null JSON response message on HTTP error" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export GITHUB_EVENT_NAME="create"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_JSON='{"message": null}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'; echo 'curl: (22) The requested URL returned error: 401' >&2; exit 22"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "curl: (22) The requested URL returned error: 401"
  refute_output --partial "Buildkite API call failed"

  assert_failure 22

  unstub curl
}

@test "Prints curl error and JSON response message on HTTP error" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export GITHUB_EVENT_NAME="create"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_JSON='{"message": "Error Message."}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'; echo 'curl: (22) The requested URL returned error: 401' >&2; exit 22"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "curl: (22) The requested URL returned error: 401"
  assert_output --partial 'Buildkite API call failed: "Error Message."'

  assert_failure 22

  unstub curl
}

@test "Prints error and fails if \${{ inputs.build_env_vars }} is not valid JSON" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export INPUT_BUILD_ENV_VARS="broken"
  export GITHUB_EVENT_NAME="create"

  run "${PWD}"/entrypoint.sh

  assert_output --partial "Error: build_env_vars provided invalid JSON: broken"

  assert_failure
}

@test "Prints error and fails if \${{ inputs.build_meta_data }} is not valid JSON" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export BUILD_META_DATA="broken"
  export GITHUB_EVENT_NAME="create"

  run $PWD/entrypoint.sh

  assert_output --partial "Error: build_meta_data provided invalid JSON: broken"

  assert_failure
}

@test "Sets DELETED_EVENT_REF on delete event" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export GITHUB_ACTION="delete"
  export GITHUB_EVENT_NAME="delete"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"DELETE_EVENT_REF":"null","GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_JSON='{"web_url": "https://buildkite.com/build-url"}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run $PWD/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"

  assert_success

  unstub curl
}

@test "Combines DELETED_EVENT_REF and build_env_vars correctly" {
  export INPUT_BUILDKITE_API_ACCESS_TOKEN="123"
  export INPUT_PIPELINE="my-org/my-pipeline"
  export INPUT_BUILD_ENV_VARS="{\"FOO\": \"bar\"}"
  export GITHUB_ACTION="delete"
  export GITHUB_EVENT_NAME="delete"

  EXPECTED_JSON='{"commit":"a-sha","branch":"a-branch","message":"","author":{"name":"The Pusher","email":"pusher@pusher.com"},"env":{"DELETE_EVENT_REF":"null","FOO":"bar","GITHUB_REPOSITORY":"buildkite/test-repo","SOURCE_REPO_SHA":"a-sha","SOURCE_REPO_REF":"a-branch"}}'
  RESPONSE_JSON='{"web_url": "https://buildkite.com/build-url"}'

  stub curl "--fail-with-body --silent --show-error -X POST -H \"Authorization: Bearer 123\" https://api.buildkite.com/v2/organizations/my-org/pipelines/my-pipeline/builds -d '$EXPECTED_JSON' : echo '$RESPONSE_JSON'"

  run $PWD/entrypoint.sh

  assert_output --partial "Build created:"
  assert_output --partial "https://buildkite.com/build-url"

  assert_success

  unstub curl
}
