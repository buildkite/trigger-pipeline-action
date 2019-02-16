# Trigger Buildkite Pipeline GitHub Action

A [GitHub Action](https://github.com/actions) for triggering a build on a Buildkite pipeline.

Features:

* Creates builds in Buildkite pipelines, setting commit, branch, message.
* Saves build JSON response to `${HOME}/${GITHUB_ACTION}.json` for downstream actions.

## Usage

```workflow
workflow "Trigger a Buildkite Build" {
  on = "push"
  resolves = ["Build"]
}

action "Build" {
  secrets = ["BUILDKITE_API_ACCESS_TOKEN"]
  env = {
    PIPELINE = "my-org/my-deploy-pipeline"
    COMMIT = "HEAD"
    BRANCH = "master"
    MESSAGE = ":github: Triggered from a GitHub Action"
  }
}
```

## Configuration Options

The following environment variable options can be configured:

|Env var|Description|Default|
|-|-|-|
|PIPELINE|The pipline to create a build on, in the format `<org-slug>/<pipeline-slug>`||
|COMMIT|The commit SHA of the build. Optional.|`$GITHUB_SHA`|
|BRANCH|The branch of the build. Optional.|`$GITHUB_REF`|
|MESSAGE|The message for the build. Optional.||

## Development

Install [act](https://github.com/nektos/act) and run it locally, to run the tests:

```bash
act
```

## Roadmap

* Add a `WAIT` option for waiting for the Buildkite build to finish.