.. title:: Config File

.. importdoc:: api/lint/private/config

The config file is a Nim program. It imports Lint, imports the linters you want, and calls [runLint] with a block describing the run:

.. include:: ../tests/linter.nim
  :code:

Compiling this file produces your lint executable.

.. important::
  To make `compiler/ast` importable in your linter and the Lint config, you have to add the Nim compiler source path to the compiler config:

  .. include:: ../tests/linter.nims
    :code:

  Put that in a [config file](https://nim-lang.org/docs/nimc.html#compiler-usage-configuration-files) affecting your linter and Lint config, e.g. `linter.nims` for `linter.nim`.

# Global config

The top of the block configures global settings for the run:

.. include:: ../tests/linter.nim
  :code:
  :start-after: #ANCHOR: globalConfig
  :end-before: #ANCHOR_END: globalConfig

`sources` lists the locations of the `.nim` files to lint. Each entry is either path to a file, a path to a directory, or a glob pattern.

.. note::
  Paths are resolved relative to the current working directory, so run the executable from your project root.

`ignoredPatterns` lists glob patterns for files to skip everywhere. `*` matches within a path segment, `**` crosses segments, and `?` matches one character.

.. important::
  Patterns are always written in UNIX form, with `/` as the separator, even on Windows: `src/generated/**/*`, never `src\generated\**\*`.

# Step config

A `step` selects checks from the imported linters. Steps run in declaration order. Ordinary checks receive the original source and parsed AST; semantic checks additionally receive the typed AST.

.. include:: ../tests/linter.nim
  :code:
  :start-after: #ANCHOR: stepConfig
  :end-before: #ANCHOR_END: stepConfig

The label in quotes is a human-readable of the step in the report.

A step may declare its own `ignoredPatterns`. Those are added to the top-level ones for that step only, so you can run a linter everywhere except a directory without excluding that directory from every other linter.

The same linter can be used by more than one step, for example to run the same checks strictly on production code and leniently on tests.

# Checks

A `check` selects an ordinary rule from a linter. For example, the step "Check naming" above uses `varNames` and `constNames`. A `semCheck` selects a semantic rule that also reads the typed AST. Both declarations accept the same settings and severity fields.

The example config also imports a linter requiring custom string representations and declares:

```nim
step "Check string representations":
  semCheck customDollar:
    severity = error
```

Ordinary and semantic checks can share a step and run in declaration order. The declaration matches the rule's registered interface: using `check` for a semantic rule, or `semCheck` for an ordinary rule, is a compile error.

A check section specifies how to report its findings.

`severity` is either `hint` or `error`:

- **hints** are informational. A run with only hints still succeeds.
- **errors** fail the run.

`settings` is optional. When present, its keys are checked against the settings type the check declares, so a misspelled key is a compile error. When absent, the check's own defaults apply.

Semantic checks are disabled unless the executable is run with `--semantic` (or `-s`). Without that flag, ordinary checks still run and a warning names the configured semantic checks that were skipped. Declaring `semCheck` does not implicitly enable expensive analysis. See [the CLI guide](./cli.html#semantic-checks).

# Linters

Lint ships no linters of its own: a linter is a Nim module you import, whether it comes from your repository or from a Nimble package. The repository's `tests/namelinter.nim` is just an example to start from.

See [Writing a Linter](./writing_a_linter.html) for the details.

