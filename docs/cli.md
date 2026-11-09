.. title:: CLI

Compile the config and run the executable:

```shell
nim c -d:release linter.nim
./linter
```

The output you get looks like this:

```
[Check naming][varNames][hint][src/foo.nim:7:2] variable `ok` is shorter than 3 characters
[Check naming][constNames][error][src/foo.nim:4:2] constant `answer` should start with `k`
hints: 1, errors: 1
```

Each line carries the step label, the check name, the severity, the position, and the message. The last line summarises the run.

The exit code tells you what happened:

| Exit code | Meaning                                                                                  |
| --------- | ---------------------------------------------------------------------------------------- |
| 0         | No errors. Hints may still have been reported.                                           |
| 1         | At least one finding was reported as an error.                                           |
| 2         | A source file could not be parsed.                                                       |
| 3         | Nothing to lint: no file matched the config's `sources` or the arguments.               |
| 4         | A check raised an exception. This is a bug in the check, not in your code.               |

# Run options

With no arguments, the executable lints the config's `sources`:

```shell
./linter
```

## Linting a subset

Arguments override `sources` and every `ignoredPatterns`, including step-level ones. An explicit argument is a request to lint exactly that, so nothing in the config can silently exclude it.

```shell
./linter src/foo.nim                 # one file
./linter 'src/module/*'              # a glob pattern
./linter src/a.nim src/b.nim         # several files
```

Quote glob patterns so your shell does not expand them first; Lint expands them itself, which keeps the behaviour the same on every platform.

## Linting specific lines

Append `:line` or `:start-end` to a file path to report only findings on those lines:

```shell
./linter src/foo.nim:10              # only line 10
./linter src/foo.nim:10-12           # lines 10 through 12
./linter src/foo.nim:10-12,40        # several ranges
```

This is useful when you want to check a change without being told about everything that was already wrong in the file.

## GitHub Actions output

`--format=github` emits GitHub Actions workflow commands instead of the human-readable report, so findings appear as inline annotations on a pull request:

```shell
./linter --format=github src/foo.nim
```

