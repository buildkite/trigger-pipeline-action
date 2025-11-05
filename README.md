# Trigger Buildkite Pipeline GitHub Action

A [GitHub Action](https://github.com/actions) for triggering a build on a [Buildkite](https://buildkite.com/) pipeline.

## Features

* Creates builds in Buildkite pipelines, setting commit, branch, message.
* Provides the build JSON response and the build URL as outputs for downstream actions.
* Automatic retry with exponential backoff for transient API failures during build status polling.

## Usage

Create a [Buildkite API Access Token](https://buildkite.com/docs/apis/rest-api#authentication) with `write_builds` scope, and save it to your GitHub repository’s **Settings → Secrets**. Then you can configure your Actions workflow with the details of the pipeline to be triggered, and the settings for the build.

## Inputs

Refer to the [action.yml](./action.yml) for more detailed information on parameter use.

### Author Information

The action automatically determines the commit author from the GitHub event payload using the following priority order:

1. `.pusher.name` and `.pusher.email` from the event payload (existing behavior)
2. `.head_commit.author.name` and `.head_commit.author.email` from the event payload (for push events)
3. `.commit.commit.author.name` and `.commit.commit.author.email` from the event payload (for status events)
4. `commit_author_name` and `commit_author_email` input parameters (user-provided defaults)
5. Git commit information from the repository (last resort)

**Note:** Some GitHub events (like `status` events) don't include a `pusher` field. The action will automatically fall back through these options to find author information. You can provide default values using the `commit_author_name` and `commit_author_email` parameters if the event payload doesn't contain author information.

### Retry Behavior

The action implements automatic retry logic with exponential backoff for all Buildkite API calls (both build creation and status polling). This will occur for 5xx server errors, or for 429 rate limited codes. If a 4xx code is received, a fast failure will be served.

### Example

The following workflow creates a new Buildkite build to the target `pipeline` on every commit.

```yaml
on: [push]

steps:
  - name: Trigger a Buildkite Build
    uses: "buildkite/trigger-pipeline-action@v2.4.1"
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

#### Example with Default Author Values

For events without a `pusher` field (like `status` events), you can provide default author values:

```yaml
on: [status]

steps:
  - name: Trigger a Buildkite Build
    uses: "buildkite/trigger-pipeline-action@v2.4.1"
    with:
      buildkite_api_access_token: ${{ secrets.TRIGGER_BK_BUILD_TOKEN }}
      pipeline: "my-org/my-deploy-pipeline"
      commit_author_name: ${{ github.event.commit.commit.author.name }}
      commit_author_email: ${{ github.event.commit.commit.author.email }}
```

#### Example with Custom Retry Configuration

To customize the retry behavior for all Buildkite API calls (build creation and status polling):

```yaml
on: [push]

steps:
  - name: Trigger a Buildkite Build
    uses: "buildkite/trigger-pipeline-action@v2.4.1"
    with:
      buildkite_api_access_token: ${{ secrets.TRIGGER_BK_BUILD_TOKEN }}
      pipeline: "my-org/my-deploy-pipeline"
      wait: true
      retry_max_attempts: 10
      retry_base_delay: 3
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

* Support other properties available in the [Buildkite Builds REST API](https://buildkite.com/docs/apis/rest-api/builds#create-a-build), such as environment variables and meta-data.

Contributions welcome! ❤️
