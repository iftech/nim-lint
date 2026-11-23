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
  Lint:
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
| `semantic`    | `false`      | Enable semantic checks (`--semantic`). |
| `setup`       | `nimble setup -y` | Dependency setup command; runs only with `semantic: 'true'`. Empty to skip. |

Enable semantic checks explicitly and select the Nim version your project uses:

```yaml
- name: Run Lint with semantic checks
  uses: iftech/nim-lint@develop
  with:
    nim-version: '2.2.14'
    semantic: 'true'
```

With semantic checks enabled, the action runs `nimble setup -y` in the project workspace after setting up Nim and before restoring or building the linter. This also runs when the compiled linter is cached: semantic analysis needs the project's dependencies at runtime. A setup failure stops the action.

Override `setup` when your project needs a different dependency policy:

```yaml
- name: Run Lint with semantic checks
  uses: iftech/nim-lint@develop
  with:
    semantic: 'true'
    setup: nimble --noLockfile --resolver:minver -l setup -y
```

Use `setup: ''` if dependencies and their compiler paths are already prepared, or if the project has no dependencies to set up. The setup command is not run when semantic checks are disabled.

Pin the action to a release or commit that includes semantic-check support when using it in production. The `semantic` input affects the run, not compilation, so both modes reuse the same cached executable.

.. warning::
  Semantic checks analyze import dependencies and execute compiler configuration scripts, macros, and compile-time code. They can be substantially more expensive than ordinary checks. Enable them only for code you trust and ensure the analysis configuration contains the project's dependency paths and build settings.

What the action does:

1. Installs the Lint version that matches the action's own ref, so `uses: iftech/nim-lint@1.0.0` pins both the action and the library.

.. important::
  Your project does not need `lint` in its own `.nimble`.

2. Compiles your config, caching the binary.
3. Diffs the pull request against its base commit and passes the changed files to the executable.

The compiled binary is cached under a key derived from the config file, the linters it imports, your dependency manifests, and the Nim version.

The action detects linters imported by the config with a simple pattern: `import a` and `import a/b/c`. Relative imports (`import ./a`, `import ../a`), bracket groups (`import a/[b, c]`), `from x import y`, and `include` are not detected. If your config imports a linter that way, changes to it will not invalidate the cache; write the import as a plain `import a/b` line instead.

For pull requests, file selection compares the recorded PR base with the PR head, not GitHub's synthetic merge commit. This excludes unrelated changes from a newer base branch. Files are still analyzed in the checked-out workspace (normally the synthetic merge), so checks see the integrated code.

## Merge queues

The action also works on `merge_group` events, which GitHub fires when a pull request enters a merge queue. The diff is then taken against the queue's base commit, so findings may include code from pull requests merged ahead of yours. That is intentional: the merge queue tests the combined result.
