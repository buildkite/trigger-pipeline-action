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

function get_build_env_vars_json() {
    BUILD_ENV_VARS=$(
      jq -c -s 'add' \
        <(echo "$1") \
        <(echo "$2") \
        <(echo "$3")
    )
  echo "$BUILD_ENV_VARS"
}

if [[ -z "${BUILDKITE_API_ACCESS_TOKEN:-}" ]]; then
  echo "You must set the BUILDKITE_API_ACCESS_TOKEN environment variable (e.g. BUILDKITE_API_ACCESS_TOKEN = \"xyz\")"
  exit 1
fi

if [[ -z "${PIPELINE:-}" ]]; then
  echo "You must set the PIPELINE environment variable (e.g. PIPELINE = \"my-org/my-pipeline\")"
  exit 1
fi

ORG_SLUG=$(echo "${PIPELINE}" | cut -d'/' -f1)
PIPELINE_SLUG=$(echo "${PIPELINE}" | cut -d'/' -f2)

COMMIT="${COMMIT:-${GITHUB_SHA}}"
BRANCH="${BRANCH:-${GITHUB_REF#"refs/heads/"}}"
MESSAGE="${MESSAGE:-}"

NAME=$(jq -r ".pusher.name" "$GITHUB_EVENT_PATH")
EMAIL=$(jq -r ".pusher.email" "$GITHUB_EVENT_PATH")

PULL_REQUEST_ID=$(jq -r '.pull_request.number // ""' "$GITHUB_EVENT_PATH")

BUILD_ENV_VARS="${BUILD_ENV_VARS:-}"

DELETE_EVENT_JSON=""
if is_delete_event; then
    DELETE_EVENT_JSON="$(get_delete_event_json)"
fi

if [[ "$BUILD_ENV_VARS" ]]; then
    if ! echo "$BUILD_ENV_VARS" | jq empty; then
      echo ""
      echo "Error: BUILD_ENV_VARS provided invalid JSON: $BUILD_ENV_VARS"
      exit 1
  fi
fi

BUILD_ENV_VARS_JSON="$(get_build_env_vars_json "$DELETE_EVENT_JSON" "$BUILD_ENV_VARS" "$(get_github_env_json)")"


# Use jq’s --arg properly escapes string values for us
JSON=$(
  jq -c -n \
    --arg COMMIT  "$COMMIT" \
    --arg BRANCH  "$BRANCH" \
    --arg MESSAGE "$MESSAGE" \
    --arg NAME    "$NAME" \
    --arg EMAIL   "$EMAIL" \
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

# Link pull request if pull request id is specified
if [[ ! -z "$PULL_REQUEST_ID" ]]; then
  JSON=$(echo "$JSON" | jq -c --arg PULL_REQUEST_ID "$PULL_REQUEST_ID" '. + {pull_request_id: $PULL_REQUEST_ID}')
fi

# Set build meta data, if specified
if [[ "${BUILD_META_DATA:-}" ]]; then
  if ! JSON=$(echo "$JSON" | jq -c --argjson BUILD_META_DATA "$BUILD_META_DATA" '. + {meta_data: $BUILD_META_DATA}'); then
    echo ""
    echo "Error: BUILD_META_DATA provided invalid JSON: $BUILD_META_DATA"
    exit 1
  fi
fi

# Merge in ignore_pipeline_branch_filters, if they specified a value
if [[ "${IGNORE_PIPELINE_BRANCH_FILTER:-}" ]]; then
  if ! JSON=$(echo "$JSON" | jq -c --argjson IGNORE_PIPELINE_BRANCH_FILTER "$IGNORE_PIPELINE_BRANCH_FILTER" '. + {ignore_pipeline_branch_filters: $IGNORE_PIPELINE_BRANCH_FILTER}'); then
    echo ""
    echo "Error: Could not set ignore_pipeline_branch_filters"
    exit 1
  fi
fi

# Add additional env vars as a nested object
FINAL_JSON=""
if [[ "$BUILD_ENV_VARS_JSON" ]]; then
    FINAL_JSON=$(
      echo "$JSON" | jq -c --argjson env "$BUILD_ENV_VARS_JSON" '. + {env: $env}'
    )
else
    FINAL_JSON=$JSON
fi

echo $FINAL_JSON

CODE=0
RESPONSE=$(
  curl \
    --fail-with-body \
    --silent \
    --show-error \
    -X POST \
    -H "Authorization: Bearer ${BUILDKITE_API_ACCESS_TOKEN}" \
    "https://api.buildkite.com/v2/organizations/${ORG_SLUG}/pipelines/${PIPELINE_SLUG}/builds" \
    -d "$FINAL_JSON" | tr -d '\n'
) || CODE=$?

if [ $CODE -ne 0 ]; then
  MESSAGE=$(echo "$RESPONSE" | jq .message 2> /dev/null || true)
  if [[ -n "$MESSAGE" ]] && [[ "$MESSAGE" != 'null' ]]; then
    echo -n "Buildkite API call failed: $MESSAGE"
  fi
  exit $CODE
fi

echo ""
echo "Build created:"
URL=$(echo "$RESPONSE" | jq --raw-output ".web_url")
echo $URL

# Provide JSON and Web URL as outputs for downstream actions
# use environment variable $GITHUB_OUTPUT, or fall back to deprecated set-output command
# https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands/
if [[ -n "${GITHUB_OUTPUT:-}" ]]
then
  echo "json=$RESPONSE" >> ${GITHUB_OUTPUT}
  echo "url=$URL" >> ${GITHUB_OUTPUT}
else
  echo "::set-output name=json::$RESPONSE"
  echo "::set-output name=url::$URL"
fi

