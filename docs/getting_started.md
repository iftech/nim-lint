.. title:: Getting Started

# Getting Started

## Install

Lint is a Nimble package:

```shell
nimble install lint
```

## Write a config

Create a file called `linter.nim` in the root of your project:

.. include:: ../tests/linter.nim
   :code:

Reading it top to bottom: `sources` are the directories to walk, `ignoredPatterns` are the files to skip everywhere. Each `step` names a linter and lists the checks to run. Each `check` says how its findings are reported and, if the check takes settings, the values for this run.

Two conventions worth knowing, because they are Nim rather than Lint:

- `key = value` assigns a value; `key:` opens a block. That is why `severity =` and `settings:` differ by one character.
- `settings:` values are checked against the settings type the check declares, so a misspelled key is a compile error.

## Run

```shell
nim r linter.nim
```

The exit code tells you what happened:

| Exit code | Meaning                                                                                  |
| --------- | ---------------------------------------------------------------------------------------- |
| 0         | No errors. Hints may still have been reported.                                           |
| 1         | At least one finding was reported as an error.                                           |
| 2         | A source file could not be parsed.                                                       |
| 3         | The run could not start: a source path does not exist, or an ignore pattern is unusable. |
| 4         | A check raised an exception. This is a bug in the check, not in your code.               |

## What a run looks like

```
[Check naming][varNames][hint][src/foo.nim:7:2] variable `ok` is shorter than 3 characters
[Check naming][constNames][error][src/foo.nim:4:2] constant `answer` should start with `k`
hints: 1, errors: 1
```

Each line carries the step label, the check name, the severity, the position, and the message. The last line summarises the run.

## Next steps

- [Config File](./config.html) — every part of the config, in detail.
- [Command Line](./cli.html) — linting a single file or a subset of the project.
- [Suppressing Findings](./suppression.html) — silencing a finding on one line.
- [GitHub Action](./github_action.html) — linting only the files a pull request changes.
