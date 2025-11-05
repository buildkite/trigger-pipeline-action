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

function get_author_name() {
  local NAME

  # 1. Try pusher.name from event (existing behavior)
  if NAME=$(jq -r ".pusher.name // empty" "$GITHUB_EVENT_PATH") && [[ -n "$NAME" ]]; then
    : # NAME is already set
  # 2. Try head_commit.author.name from event (for push events)
  elif NAME=$(jq -r ".head_commit.author.name // empty" "$GITHUB_EVENT_PATH") && [[ -n "$NAME" ]]; then
    : # NAME is already set
  # 3. Try commit.commit.author.name from event (for status events)
  elif NAME=$(jq -r ".commit.commit.author.name // empty" "$GITHUB_EVENT_PATH") && [[ -n "$NAME" ]]; then
    : # NAME is already set
  # 4. Use default input parameter if provided
  elif [[ -n "${INPUT_COMMIT_AUTHOR_NAME:-}" ]]; then
    NAME="$INPUT_COMMIT_AUTHOR_NAME"
  # 5. Try to get from git commit (if we're in a git repo and commit exists)
  elif [[ -d .git ]] && NAME=$(git show -s --format=%an "${COMMIT}" 2>/dev/null) && [[ -n "$NAME" ]]; then
    : # NAME is already set
  else
    NAME=""
  fi

  echo "$NAME"
}

function get_author_email() {
  local EMAIL

  # 1. Try pusher.email from event (existing behavior)
  if EMAIL=$(jq -r ".pusher.email // empty" "$GITHUB_EVENT_PATH") && [[ -n "$EMAIL" ]]; then
    : # EMAIL is already set
  # 2. Try head_commit.author.email from event (for push events)
  elif EMAIL=$(jq -r ".head_commit.author.email // empty" "$GITHUB_EVENT_PATH") && [[ -n "$EMAIL" ]]; then
    : # EMAIL is already set
  # 3. Try commit.commit.author.email from event (for status events)
  elif EMAIL=$(jq -r ".commit.commit.author.email // empty" "$GITHUB_EVENT_PATH") && [[ -n "$EMAIL" ]]; then
    : # EMAIL is already set
  # 4. Use default input parameter if provided
  elif [[ -n "${INPUT_COMMIT_AUTHOR_EMAIL:-}" ]]; then
    EMAIL="$INPUT_COMMIT_AUTHOR_EMAIL"
  # 5. Try to get from git commit (if we're in a git repo and commit exists)
  elif [[ -d .git ]] && EMAIL=$(git show -s --format=%ae "${COMMIT}" 2>/dev/null) && [[ -n "$EMAIL" ]]; then
    : # EMAIL is already set
  else
    EMAIL=""
  fi

  echo "$EMAIL"
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

function calculate_backoff_delay() {
  local BASE_DELAY="$1"
  local ATTEMPT="$2"
  local DELAY=$((BASE_DELAY * (2 ** (ATTEMPT - 1))))
  local JITTER=$((RANDOM % (DELAY / 4 + 1)))
  local TOTAL_DELAY=$((DELAY + JITTER))

  if [ "$TOTAL_DELAY" -gt 60 ]; then
    TOTAL_DELAY=60
  fi

  echo "$TOTAL_DELAY"
}

function curl_with_retry() {
  local URL="$1"
  local AUTH_TOKEN="$2"
  local MAX_ATTEMPTS="${3:-5}"
  local BASE_DELAY="${4:-2}"
  local ATTEMPT=1
  local HTTP_CODE
  local RESPONSE
  local TEMP_FILE

  TEMP_FILE=$(mktemp)

  while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do

    HTTP_CODE=$(curl \
      --silent \
      --show-error \
      --write-out '%{http_code}' \
      --output "$TEMP_FILE" \
      -H "Authorization: Bearer ${AUTH_TOKEN}" \
      "$URL" 2>&1 | tail -n1)

    RESPONSE=$(cat "$TEMP_FILE")

    # Check HTTP code
    if [[ "$HTTP_CODE" =~ ^[0-9]{3}$ ]]; then
      if [[ "$HTTP_CODE" =~ ^2[0-9]{2}$ ]]; then
        rm -f "$TEMP_FILE"
        echo "$RESPONSE"
        return 0
      fi

      # Throw fast fail for 4xx codes except 429
      if [[ "$HTTP_CODE" =~ ^4[0-9]{2}$ ]] && [[ "$HTTP_CODE" != "429" ]]; then
        echo "API request failed with HTTP $HTTP_CODE (non-retryable client error)" >&2
        echo "$RESPONSE" >&2
        rm -f "$TEMP_FILE"
        return 1
      fi

      # Retry 5xx and 429 with exponential backoff
      if [[ "$HTTP_CODE" =~ ^5[0-9]{2}$ ]] || [[ "$HTTP_CODE" == "429" ]]; then
        if [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; then
          local TOTAL_DELAY
          TOTAL_DELAY=$(calculate_backoff_delay "$BASE_DELAY" "$ATTEMPT")

          echo "API request failed with HTTP $HTTP_CODE: $RESPONSE" >&2
          echo "Retrying in ${TOTAL_DELAY}s (attempt $ATTEMPT/$MAX_ATTEMPTS)..." >&2

          sleep "$TOTAL_DELAY"
          ATTEMPT=$((ATTEMPT + 1))
          continue
        else
          echo "API request failed with HTTP $HTTP_CODE after $MAX_ATTEMPTS attempts" >&2
          echo "$RESPONSE" >&2

          rm -f "$TEMP_FILE"

          return 1
        fi
      fi
    else
      if [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; then
        local TOTAL_DELAY
        TOTAL_DELAY=$(calculate_backoff_delay "$BASE_DELAY" "$ATTEMPT")

        echo "Network error or curl failure. Retrying in ${TOTAL_DELAY}s (attempt $ATTEMPT/$MAX_ATTEMPTS)..." >&2

        sleep "$TOTAL_DELAY"

        ATTEMPT=$((ATTEMPT + 1))

        continue
      else
        echo "Network error or curl failure after $MAX_ATTEMPTS attempts" >&2
        echo "$HTTP_CODE" >&2
        rm -f "$TEMP_FILE"
        return 1
      fi
    fi
  done
}

function wait_for_build() {
  local BUILD_ID
  local ORG_SLUG
  local PIPELINE_SLUG
  local WAIT_INTERVAL
  local WAIT_TIMEOUT
  local RETRY_MAX_ATTEMPTS
  local RETRY_BASE_DELAY
  local START_TIME
  local CURRENT_TIME
  local ELAPSED_TIME
  local BUILD_STATE
  local BUILD_RESPONSE

  BUILD_ID="$1"
  ORG_SLUG="$2"
  PIPELINE_SLUG="$3"
  WAIT_INTERVAL="${4:-10}"
  WAIT_TIMEOUT="${5:-3600}"
  RETRY_MAX_ATTEMPTS="${6:-5}"
  RETRY_BASE_DELAY="${7:-2}"

  echo "Waiting for build $BUILD_ID to complete..."
  START_TIME=$(date +%s)

  while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))

    if [ "$ELAPSED_TIME" -gt "$WAIT_TIMEOUT" ]; then
      echo "Timeout reached after ${WAIT_TIMEOUT} seconds"
      return 1
    fi

    BUILD_RESPONSE=$(curl_with_retry \
      "https://api.buildkite.com/v2/organizations/${ORG_SLUG}/pipelines/${PIPELINE_SLUG}/builds/${BUILD_ID}" \
      "${INPUT_BUILDKITE_API_ACCESS_TOKEN}" \
      "$RETRY_MAX_ATTEMPTS" \
      "$RETRY_BASE_DELAY")

    if [ $? -ne 0 ]; then
      echo "Failed to fetch build status after retries"
      return 1
    fi

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

NAME=$(get_author_name)
EMAIL=$(get_author_email)
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
  if ! wait_for_build "$BUILD_NUMBER" "$ORG_SLUG" "$PIPELINE_SLUG" "${INPUT_WAIT_INTERVAL:-10}" "${INPUT_WAIT_TIMEOUT:-3600}" "${INPUT_RETRY_MAX_ATTEMPTS:-5}" "${INPUT_RETRY_BASE_DELAY:-2}"; then
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
