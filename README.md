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
  uses = "buildkite/trigger-pipeline-action@v1.0.0"
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

To run the test workflow, you use [act](https://github.com/nektos/act) which will run it just as it does on GitHub:

```bash
act
```

## Contributing

* Fork this repository
* Create a new branch for your work
* Push up any changes to your branch, and open a pull request. Don't feel it needs to be perfect — incomplete work is totally fine. We'd love to help get it ready for merging.

## Roadmap

* Add a `WAIT` option for waiting for the Buildkite build to finish.

Contributions welcome! ❤️
