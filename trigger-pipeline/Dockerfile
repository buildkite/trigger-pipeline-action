FROM alpine

LABEL version="1.0.0"
LABEL repository="http://github.com/buildkite/actions/trigger-pipeline"
LABEL homepage="http://github.com/toolmantim/actions/trigger-pipeline"
LABEL maintainer="Buildkite Support <support@buildkite.com>"

LABEL com.github.actions.name="Trigger Buildkite Pipeline"
LABEL com.github.actions.description="Triggers any Buildkite pipeline."
LABEL com.github.actions.icon="zap"
LABEL com.github.actions.color="blue"

RUN apk add --no-cache bash curl jq

COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
