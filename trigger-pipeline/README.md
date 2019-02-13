# Buildkite Pipeline GitHub Action

A GitHub Action for triggering a build on a Buildkite pipeline. You can configure the action to continue as soon as the build is created, or to wait for the Buildkite build to finish.

Features:

* Creates builds in Buildkite pipelines.
* Can set commit, branch, message and author.
* Saves build JSON response to `${HOME}/${GITHUB_ACTION}.json` for downstream actions.

## Usage

Triggering a build for every push:

```workflow
workflow "Buildkite Build" {
  on = "push"
  resolves = ["Create Buildkite Build"]
}

action "Create Buildkite Build" {
  uses = "toolmantim/actions/pipeline@master"
  secrets = ["BUILDKITE_API_ACCESS_TOKEN"]
  env = {
    PIPELINE = "my-org/my-pipeline"
    # Pass through commit, branch, message and author
  }
}
```

Trigger a deploy build for pushes to the master branch:

```workflow
workflow "Deploy to Buildkite" {
  on = "push"
  resolves = ["Trigger Buildkite Deploy"]
}

action "Filter to master Branch" {
  uses = "actions/bin/filter@master"
  args = ["branch", "master"]
}

action "Trigger Buildkite Deploy" {
  needs = "Filter to master Branch"
  uses = "toolmantim/actions/pipeline@master"
  secrets = ["BUILDKITE_API_ACCESS_TOKEN"]
  env = {
    PIPELINE = "my-org/my-deploy-pipeline"
    COMMIT = "HEAD"
    BRANCH = "master"
    MESSAGE = ":github: Deployed from a GitHub Action"
  }
}
```

## TODO

- [x] Decide if this is a good idea
- [x] Implement everything
- [ ] Add support for `WAIT` - so the action can wait until a build has finished, and then continue on (for example, to a Slack notification action)
