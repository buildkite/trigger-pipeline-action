#!/bin/bash

set -euo pipefail

function is_delete_event() {
  if [[ "$GITHUB_EVENT_NAME" == "delete" ]]; then
    return 0
  else
    return 1
  fi
}

function get_delete_event_json() {
  local DELETE_EVENT_JSON
  local DELETE_EVENT_REF

  DELETE_EVENT_REF=$(jq --raw-output .ref "$GITHUB_EVENT_PATH")
  DELETE_EVENT_JSON=$(
    jq -c -n \
      --arg DELETE_EVENT_REF "$DELETE_EVENT_REF" \
      '{
        DELETE_EVENT_REF: $DELETE_EVENT_REF,
      }'
  )
  echo "$DELETE_EVENT_JSON"
}

function get_github_env_json() {
  local GITHUB_EVENT_JSON

  GITHUB_EVENT_JSON=$(
    jq -c -n \
      --arg GITHUB_REPOSITORY "$GITHUB_REPOSITORY" \
      --arg SOURCE_REPO_SHA "$GITHUB_SHA" \
      --arg SOURCE_REPO_REF "${GITHUB_REF#"refs/heads/"}" \
      '{
        GITHUB_REPOSITORY: $GITHUB_REPOSITORY,
        SOURCE_REPO_SHA: $SOURCE_REPO_SHA,
        SOURCE_REPO_REF: $SOURCE_REPO_REF,
      }'
  )
  echo "$GITHUB_EVENT_JSON"
}

function get_INPUT_BUILD_ENV_VARS_json() {
  INPUT_BUILD_ENV_VARS=$(
    jq -c -s 'add' \
      <(echo "$1") \
      <(echo "$2") \
      <(echo "$3")
  )

  echo "$INPUT_BUILD_ENV_VARS"
}

function wait_for_build() {
  local BUILD_ID
  local ORG_SLUG
  local PIPELINE_SLUG
  local WAIT_INTERVAL
  local WAIT_TIMEOUT
  local START_TIME
  local CURRENT_TIME
  local ELAPSED_TIME
  local BUILD_STATE
  
  BUILD_ID="$1"
  ORG_SLUG="$2"
  PIPELINE_SLUG="$3"
  WAIT_INTERVAL="${4:-10}"
  WAIT_TIMEOUT="${5:-3600}"
  
  echo "Waiting for build $BUILD_ID to complete..."
  START_TIME=$(date +%s)
  
  while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    
    if [ "$ELAPSED_TIME" -gt "$WAIT_TIMEOUT" ]; then
      echo "Timeout reached after ${WAIT_TIMEOUT} seconds"
      return 1
    fi
    
    BUILD_RESPONSE=$(curl \
      --fail-with-body \
      --silent \
      --show-error \
      -H "Authorization: Bearer ${INPUT_BUILDKITE_API_ACCESS_TOKEN}" \
      "https://api.buildkite.com/v2/organizations/${ORG_SLUG}/pipelines/${PIPELINE_SLUG}/builds/${BUILD_ID}")
    
    BUILD_STATE=$(echo "$BUILD_RESPONSE" | jq -r .state)
    
    case "$BUILD_STATE" in
      "passed")
        echo "Build passed!"
        echo "build_state=$BUILD_STATE" >>"${GITHUB_OUTPUT}"
        return 0
        ;;
      "failed"|"canceled"|"skipped"|"blocked")
        echo "Build finished with state: $BUILD_STATE"
        echo "build_state=$BUILD_STATE" >>"${GITHUB_OUTPUT}"
        return 1
        ;;
      "running"|"scheduled"|"waiting"|"waiting_failed")
        echo "Build status: $BUILD_STATE. Waiting ${WAIT_INTERVAL} seconds..."
        sleep "$WAIT_INTERVAL"
        ;;
      *)
        echo "Unknown build state: $BUILD_STATE"
        echo "build_state=$BUILD_STATE" >>"${GITHUB_OUTPUT}"
        return 1
        ;;
    esac
  done
}

if [[ -z "${INPUT_BUILDKITE_API_ACCESS_TOKEN:-}" ]]; then
  echo "You must set the buildkite_api_access_token input parameter (e.g. buildkite_api_access_token: \"1234567890\")"
  exit 1
fi

if [[ -z "${INPUT_PIPELINE:-}" ]]; then
  echo "You must set the pipeline input parameter (e.g. pipeline: \"my-org/my-pipeline\")"
  exit 1
fi

ORG_SLUG=$(echo "${INPUT_PIPELINE}" | cut -d'/' -f1)
PIPELINE_SLUG=$(echo "${INPUT_PIPELINE}" | cut -d'/' -f2)

COMMIT="${INPUT_COMMIT:-${GITHUB_SHA}}"
BRANCH="${INPUT_BRANCH:-${GITHUB_REF#"refs/heads/"}}"
MESSAGE="${INPUT_MESSAGE:-}"

NAME=$(jq -r ".pusher.name" "$GITHUB_EVENT_PATH")
EMAIL=$(jq -r ".pusher.email" "$GITHUB_EVENT_PATH")
PULL_REQUEST_ID=""
PULL_REQUEST_BASE_BRANCH="${INPUT_PULL_REQUEST_BASE_BRANCH:-}"
if [[ "${INPUT_SEND_PULL_REQUEST:-true}" == 'true' ]]; then
  PULL_REQUEST_ID=$(jq -r '.pull_request.number // ""' "$GITHUB_EVENT_PATH")
fi

INPUT_BUILD_ENV_VARS="${INPUT_BUILD_ENV_VARS:-}"

DELETE_EVENT_JSON=""
if is_delete_event; then
  DELETE_EVENT_JSON="$(get_delete_event_json)"
fi

if [[ "$INPUT_BUILD_ENV_VARS" ]]; then
  if ! echo "$INPUT_BUILD_ENV_VARS" | jq empty; then
    echo ""
    echo "Error: build_env_vars provided invalid JSON: $INPUT_BUILD_ENV_VARS" 
    exit 1
  fi
fi


INPUT_BUILD_ENV_VARS_JSON="$(get_INPUT_BUILD_ENV_VARS_json "$DELETE_EVENT_JSON" "$INPUT_BUILD_ENV_VARS" "$(get_github_env_json)")"
 
# Use jq’s --arg properly escapes string values for us
JSON=$(
  jq -c -n \
    --arg COMMIT "$COMMIT" \
    --arg BRANCH "$BRANCH" \
    --arg MESSAGE "$MESSAGE" \
    --arg NAME "$NAME" \
    --arg EMAIL "$EMAIL" \
    '{
      "commit": $COMMIT,
      "branch": $BRANCH,
      "message": $MESSAGE,
      "author": {
        "name": $NAME,
        "email": $EMAIL
      }
    }'
)

# Link pull request and pull request base branch if pull request id is specified
if [[ -n "$PULL_REQUEST_ID" ]]; then
  JSON=$(echo "$JSON" | jq -c --arg PULL_REQUEST_ID "$PULL_REQUEST_ID" '. + {pull_request_id: $PULL_REQUEST_ID}')
  if [[ -n "$PULL_REQUEST_BASE_BRANCH" ]]; then
    JSON=$(echo "$JSON" | jq -c --arg PULL_REQUEST_BASE_BRANCH "$PULL_REQUEST_BASE_BRANCH" '. + {pull_request_base_branch: $PULL_REQUEST_BASE_BRANCH}')
  fi
fi

# Set build meta data, if specified
if [[ "${INPUT_BUILD_META_DATA:-}" ]]; then
  if ! JSON=$(echo "$JSON" | jq -c --argjson INPUT_BUILD_META_DATA "$INPUT_BUILD_META_DATA" '. + {meta_data: $INPUT_BUILD_META_DATA}'); then
    echo ""
    echo "Error: build_meta_data provided invalid JSON: $INPUT_BUILD_META_DATA"
    exit 1
  fi
fi

# Merge in ignore_pipeline_branch_filters, if they specified a value
if [[ "${INPUT_IGNORE_PIPELINE_BRANCH_FILTER:-}" ]]; then
  if ! JSON=$(echo "$JSON" | jq -c --argjson INPUT_IGNORE_PIPELINE_BRANCH_FILTER "$INPUT_IGNORE_PIPELINE_BRANCH_FILTER" '. + {ignore_pipeline_branch_filters: $INPUT_IGNORE_PIPELINE_BRANCH_FILTER}'); then
    echo ""
    echo "Error: Could not set ignore_pipeline_branch_filters"
    exit 1
  fi
fi

# Add additional env vars as a nested object
FINAL_JSON=""
if [[ "$INPUT_BUILD_ENV_VARS_JSON" ]]; then
  FINAL_JSON=$(
    echo "$JSON" | jq -c --argjson env "$INPUT_BUILD_ENV_VARS_JSON" '. + {env: $env}'
  )
else
  FINAL_JSON=$JSON
fi

CODE=0
RESPONSE=$(
  curl \
    --fail-with-body \
    --silent \
    --show-error \
    -X POST \
    -H "Authorization: Bearer ${INPUT_BUILDKITE_API_ACCESS_TOKEN}" \
    "https://api.buildkite.com/v2/organizations/${ORG_SLUG}/pipelines/${PIPELINE_SLUG}/builds" \
    -d "$FINAL_JSON" | tr -d '\n'
) || CODE=$?

if [ $CODE -ne 0 ]; then
  MESSAGE=$(echo "$RESPONSE" | jq .message 2>/dev/null || true)
  if [[ -n "$MESSAGE" ]] && [[ "$MESSAGE" != 'null' ]]; then
    echo -n "Buildkite API call failed: $MESSAGE"
  fi
  exit $CODE
fi

echo ""
echo "Build created:"
URL=$(echo "$RESPONSE" | jq --raw-output ".web_url")
echo "$URL"

# Extract build number from response
BUILD_NUMBER=$(echo "$RESPONSE" | jq --raw-output ".number")

# Wait for build if requested
if [[ "${INPUT_WAIT:-false}" == 'true' ]]; then
  if ! wait_for_build "$BUILD_NUMBER" "$ORG_SLUG" "$PIPELINE_SLUG" "${INPUT_WAIT_INTERVAL:-10}" "${INPUT_WAIT_TIMEOUT:-3600}"; then
    echo "Build did not complete successfully"
    exit 1
  fi
fi

# Provide JSON and Web URL as outputs for downstream actions
# use environment variable $GITHUB_OUTPUT, or fall back to deprecated set-output command
# https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "json=$RESPONSE" >>"${GITHUB_OUTPUT}"
  echo "url=$URL" >>"${GITHUB_OUTPUT}"
else
  echo "::set-output name=json::$RESPONSE"
  echo "::set-output name=url::$URL"
fi
