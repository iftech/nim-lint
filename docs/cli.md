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

## Verbose progress

Pass `--verbose` (or `-v`) to report per-file progress in real time:

```shell
./linter -v foo.nim       # Checking: foo.nim
./linter -s -v foo.nim    # Semantic analysis: foo.nim, then Checking: foo.nim
```

Progress messages go to stderr and are flushed immediately. Semantic analysis is reported only for files with applicable semantic checks. Without `-v`, neither progress message is printed. Findings, summaries, skipped-check warnings, and analysis errors are unaffected by verbosity.

## Semantic checks

Pass `--semantic` (or `-s`) to run semantic checks in addition to ordinary checks:

```shell
nim --version                      # verify this is the project's Nim version
nim c -d:release linter.nim
./linter --semantic
```

.. important::
  Compile `linter.nim` with the Nim version your project uses, and keep that same Nim installation on `PATH` when running `./linter --semantic`. Recompile `linter.nim` whenever you change the project's Nim version.

The lint executable embeds the compiler front end it was built with, while semantic analysis reads standard-library sources from disk. Changing the Nim on `PATH` does not switch the executable's embedded compiler. For example, if your project uses Nim 2.2.12 but `linter.nim` was compiled with Nim 2.4.0, select Nim 2.2.12 and recompile `linter.nim` before running semantic checks.

Without `--semantic`, ordinary checks still run and Lint warns about configured semantic checks that were skipped.

.. tip::
  Semantic checks can be much slower than ordinary checks. To reserve them for manual runs on explicit targets, put them in a separate step that ignores all default sources:

  ```nim
  step "Semantic checks":
    ignoredPatterns = ["**/*"]
    semCheck customDollar:
      severity = error
  ```

  Use your own registered semantic rule in place of `customDollar`. A normal run still performs ordinary checks, while even `./linter -s` skips this step for the config's default sources. To run it on a specific file or directory, use `./linter -s path/to/source`. Explicit targets override all ignore patterns, including step-level ones, so this runs both ordinary and semantic checks on the selected path. This keeps expensive semantic analysis out of default whole-project runs; workflows that supply explicit targets with `-s` will still run it.

Each file with applicable semantic checks is analyzed as an entry point, including its recursive imports. The compiler loads the applicable Nim configuration files; Lint does not infer arguments supplied only by a Nimble task or custom build command. Analysis uses an independent compiler context per selected file, so overlapping dependencies can be analyzed again.

.. warning::
  Semantic analysis evaluates configuration scripts, macros, and compile-time code. Run it only on code you trust. It is more expensive than ordinary checking and is not sandboxed.

Compiler errors are reported as analysis warnings, with locations when available. Compiler warnings and hints are not printed; they are not lint findings. Semantic checks still run on partial typed trees after recoverable errors. If no tree is available, Lint names the checks that could not run and continues with ordinary checks and other files. These warnings alone do not fail the run; error findings and check exceptions retain the exit codes above. With `--verbose`, each analyzed target is identified by a `Semantic analysis: <file>` marker on stderr. Compiler errors are reported immediately and flushed, so diagnostics already received remain visible if analysis terminates directly. Some fatal compiler failures can terminate the process before recovery.

Line ranges and `#nolint` filter check findings, not compiler diagnostics or notices about unavailable analysis. JavaScript semantic analysis is not supported; a JS-configured file produces a warning and its semantic checks do not run.

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

`--format=github` (or `-f:github`) emits GitHub Actions workflow commands instead of the human-readable report, so findings appear as inline annotations on a pull request:

```shell
./linter --format=github src/foo.nim
```
