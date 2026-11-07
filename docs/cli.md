.. title:: Command Line

With no arguments, the executable lints the config's `sources`:

```shell
./linter
```

# Linting a subset

Arguments override `sources` and every `ignoredPatterns`, including step-level ones. An explicit argument is a request to lint exactly that, so nothing in the config can silently exclude it.

```shell
./linter src/foo.nim                 # one file
./linter 'src/module/*'              # a glob pattern
./linter src/a.nim src/b.nim         # several files
```

Quote glob patterns so your shell does not expand them first; Lint expands them itself, which keeps the behaviour the same on every platform.

# Linting specific lines

Append `:line` or `:start-end` to a file path to report only findings on those lines:

```shell
./linter src/foo.nim:10              # only line 10
./linter src/foo.nim:10-12           # lines 10 through 12
./linter src/foo.nim:10-12,40        # several ranges
```

This is useful when you want to check a change without being told about everything that was already wrong in the file.

# GitHub Actions output

`--format=github` emits GitHub Actions workflow commands instead of the human-readable report, so findings appear as inline annotations on a pull request:

```shell
./linter --format=github src/foo.nim
```

Both `--format=github` and `--format:github` are accepted.
