# Trigger Buildkite Pipeline GitHub Action

A [GitHub Action](https://github.com/actions) for triggering a build on a [Buildkite](https://buildkite.com/) pipeline.

## Features

* Creates builds in Buildkite pipelines, setting commit, branch, message.
* Provides the build JSON response and the build URL as outputs for downstream actions.

## Usage

Create a [Buildkite API Access Token](https://buildkite.com/docs/apis/rest-api#authentication) with `write_builds` scope, and save it to your GitHub repository’s **Settings → Secrets**. Then you can configure your Actions workflow with the details of the pipeline to be triggered, and the settings for the build.


## Configuration Options

### Configuration as Input Parameters

The following workflow creates a new Buildkite build to the target `pipeline` on every commit.

```
on: [push]

steps:
  - name: Trigger a Buildkite Build
    uses: "buildkite/trigger-pipeline-action@v2.1.0"
    with:
      buildkite_api_access_token: ${{ secrets.TRIGGER_BK_BUILD_TOKEN }} 
      pipeline: "my-org/my-deploy-pipeline"
      branch: "master"
      commit: "HEAD"
      message:  ":github: Triggered from a GitHub Action"
      build_env_vars: '{"TRIGGERED_FROM_GHA": "true"}'
      build_meta_data: '{"FOO": "bar"}'
      ignore_pipeline_branch_filter: true     
      send_pull_request: true
      wait: true
      wait_interval: 10
      wait_timeout: 300
```

## Outputs

The following outputs are provided by the action:

|Output var|Description|
|-|-|
|url|The URL of the Buildkite build.|
|json|The JSON response returned by the Buildkite API.|


## Development

To run the test workflow, you use [act](https://github.com/nektos/act) which will run it just as it does on GitHub:

```bash
act -n
```

## Testing

To run the tests locally, use the plugin tester (that has everything already installed) by running the Docker command

```bash
docker run --rm -ti -v "$PWD":/plugin buildkite/plugin-tester:v4.0.0
```

## Contributing

* Fork this repository
* Create a new branch for your work
* Push up any changes to your branch, and open a pull request. Don't feel it needs to be perfect — incomplete work is totally fine. We'd love to help get it ready for merging.

## Releasing

* Create a new GitHub release. The version numbers in the readme will be automatically updated.

## Roadmap

* Add a `WAIT` option for waiting for the Buildkite build to finish.
* Support other properties available in the [Buildkite Builds REST API](https://buildkite.com/docs/apis/rest-api/builds#create-a-build), such as environment variables and meta-data.

Contributions welcome! ❤️
