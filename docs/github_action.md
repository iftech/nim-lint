.. title:: GitHub Action

The repository ships a GitHub Action that lints only the files a pull request changes. Findings appear as inline annotations on the diff, so review focuses on new code rather than on everything that was already wrong.

# Usage

Add a workflow that checks out the repository and runs the action:

```yaml
name: Lint

on:
  pull_request:
  merge_group:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6
        with:
          fetch-depth: 2
      - name: Run Lint
        uses: iftech/nim-lint@1.0.0
```

Possible inputs:

| Input         | Default      | Meaning                               |
| ------------- | ------------ | ------------------------------------- |
| `config`      | `linter.nim` | Path to the config file.              |
| `nim-version` | `stable`     | Nim version used to build the config. |

What the action does:

1. Installs the Lint version that matches the action's own ref, so `uses: iftech/nim-lint@1.0.0` pins both the action and the library.

.. important::
  Your project does not need `lint` in its own `.nimble`.

2. Compiles your config, caching the binary.
3. Diffs the pull request against its base commit and passes the changed files to the executable.

The compiled binary is cached under a key derived from the config file, the linters it imports, your dependency manifests, and the Nim version.

The action detects linters imported by the config with a simple pattern: `import a` and `import a/b/c`. Relative imports (`import ./a`, `import ../a`), bracket groups (`import a/[b, c]`), `from x import y`, and `include` are not detected. If your config imports a linter that way, changes to it will not invalidate the cache; write the import as a plain `import a/b` line instead.

## Merge queues

The action also works on `merge_group` events, which GitHub fires when a pull request enters a merge queue. The diff is then taken against the queue's base commit, so findings may include code from pull requests merged ahead of yours. That is intentional: the merge queue tests the combined result.
