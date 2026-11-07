.. title:: Config File

The config file is a Nim program. It imports Lint, imports the linters you want, and calls `runLint` with a block describing the run:

.. include:: ../tests/linter.nim
  :code:

Compiling this file produces your lint executable. There is no separate config format to learn: what you write is what runs.

Two conventions worth knowing, because they are Nim rather than Lint:

- `key = value` assigns a value; `key:` opens a block. That is why `severity =` and `settings:` differ by one character.
- `settings:` values are checked against the settings type the check declares, so a misspelled key is a compile error.

## Sources

`sources` lists the directories to walk. Every `.nim` file under them is checked.

.. include:: ../tests/linter.nim
  :code:
  :start-after: #startSources
  :end-before: #endSources

Paths are resolved relative to the current working directory, so run the executable from your project root.

## Ignored patterns

`ignoredPatterns` lists glob patterns for files to skip everywhere:

.. include:: ../tests/linter.nim
  :code:
  :start-after: #startIgnoredPatterns
  :end-before: #endIgnoredPatterns

`*` matches within a path segment, `**` crosses segments, and `?` matches one character.

Patterns are always written in UNIX form, with `/` as the separator, even on Windows: `src/generated/**/*`, never `src\generated\**\*`. Lint converts them for the platform it runs on.

## Steps

A `step` is one invocation of a linter. Steps run in the order they are declared, and each one gets the same parsed file.

.. include:: ../tests/linter.nim
  :code:
  :start-after: #startStep
  :end-before: #endStep

The label in quotes identifies the step in the report. It is for the reader, not an identifier: nothing is looked up by it, and two steps may share one.

A step may declare its own `ignoredPatterns`:

.. include:: ../tests/linter.nim
  :code:
  :start-after: #startStepIgnoredPatterns
  :end-before: #endStepIgnoredPatterns

Those are added to the top-level ones for that step only, so you can run a linter everywhere except a directory without excluding that directory from every other linter.

The same linter can be used by more than one step, for example to run the same checks strictly on production code and leniently on tests.

## Checks

A `check` names one rule from the linter and says how to report it:

.. include:: ../tests/linter.nim
  :code:
  :start-after: #startCheck
  :end-before: #endCheck

`severity` is either `hint` or `error`:

- **hints** are informational. A run with only hints still succeeds.
- **errors** fail the run.

`settings` is optional:

.. include:: ../tests/linter.nim
  :code:
  :start-after: #startSettings
  :end-before: #endSettings

When present, its keys are checked against the settings type the check declares, so a misspelled key is a compile error. When absent, the check's own defaults apply.

Settings are used exactly as written: there are no "empty means default" rules, so an empty list really means "none". The defaults apply only when the whole `settings:` block is omitted.

## Linters

Lint ships no linters of its own: a linter is a Nim module you import, whether it comes from your repository or from a Nimble package. The repository's `tests/namelinter.nim` is a small one to start from.

## Writing your own linter

A linter is a Nim module that declares checks and exports a linter value. Put it anywhere in your repository and import it from the config:

```nim
import lint
import tools/my_linter
```

See [Writing a Linter](./writing_a_linter.html) for the details.

## Running the linter

Compile the config and run the executable:

```shell
nim c -d:release linter.nim
./linter
```

The exit code tells you what happened:

| Exit code | Meaning                                                                                  |
| --------- | ---------------------------------------------------------------------------------------- |
| 0         | No errors. Hints may still have been reported.                                           |
| 1         | At least one finding was reported as an error.                                           |
| 2         | A source file could not be parsed.                                                       |
| 3         | Nothing to lint: no file matched the config's `sources` or the arguments.               |
| 4         | A check raised an exception. This is a bug in the check, not in your code.               |

## What a run looks like

```
[Check naming][varNames][hint][src/foo.nim:7:2] variable `ok` is shorter than 3 characters
[Check naming][constNames][error][src/foo.nim:4:2] constant `answer` should start with `k`
hints: 1, errors: 1
```

Each line carries the step label, the check name, the severity, the position, and the message. The last line summarises the run.
