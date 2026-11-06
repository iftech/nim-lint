.. title:: GitHub Action

# GitHub Action

The repository ships a GitHub Action that lints only the files a pull request changes. Findings appear as inline annotations on the diff, so review focuses on new code rather than on everything that was already wrong.

## Setup

Add a workflow that checks out the repository and runs the action:

```yaml
name: lint

on:
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          # The action diffs against the base commit, so the history has to be
          # there.
          fetch-depth: 0
      - uses: iftech/nim-lint@v1
        with:
          config: linter.nim
```

`fetch-depth: 0` matters: the default shallow checkout does not contain the base commit, and the action needs it to compute the diff.

## Inputs

| Input         | Default      | Meaning                               |
| ------------- | ------------ | ------------------------------------- |
| `config`      | `linter.nim` | Path to the config file.              |
| `nim-version` | `2.2.12`     | Nim version used to build the config. |

## What it does

1. Installs the lint version that matches the action's own ref, so `uses: iftech/nim-lint@v1` pins both the action and the library. Your project does not need `lint` in its own `.nimble`.
2. Compiles your config, caching the binary.
3. Diffs the pull request against its base commit and passes the changed files to the executable.

The tool itself knows nothing about git: the action computes the file list and the executable lints what it is given.

## Caching

The compiled binary is cached under a key derived from the config file, the linters it imports, your dependency manifests, and the Nim version.

Your project's sources are deliberately not part of the key. They are read at run time, so changing them must not force a rebuild.

The action detects linters imported by the config with a simple pattern: `import a` and `import a/b/c`. Relative imports (`import ./a`, `import ../a`), bracket groups (`import a/[b, c]`), `from x import y`, and `include` are not detected. If your config imports a linter that way, changes to it will not invalidate the cache; write the import as a plain `import a/b` line instead.

## Merge queues

The action also works on `merge_group` events, which GitHub fires when a pull request enters a merge queue. The diff is then taken against the queue's base commit, so findings may include code from pull requests merged ahead of yours. That is intentional: the merge queue tests the combined result.
