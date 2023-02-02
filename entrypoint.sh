#!/bin/bash

set -euo pipefail

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

# Merge in the build environment variables, if they specified any
if [[ "${BUILD_ENV_VARS:-}" ]]; then
  if ! JSON=$(echo "$JSON" | jq -c --argjson BUILD_ENV_VARS "$BUILD_ENV_VARS" '. + {env: $BUILD_ENV_VARS}'); then
    echo ""
    echo "Error: BUILD_ENV_VARS provided invalid JSON: $BUILD_ENV_VARS"
    exit 1
  fi
fi

RESPONSE=$(
  curl \
    --fail \
    --silent \
    -X POST \
    -H "Authorization: Bearer ${BUILDKITE_API_ACCESS_TOKEN}" \
    "https://api.buildkite.com/v2/organizations/${ORG_SLUG}/pipelines/${PIPELINE_SLUG}/builds" \
    -d "$JSON" | tr -d '\n'
)

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

