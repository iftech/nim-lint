.. title:: Writing a Linter
.. importdoc:: api/lint/private/types

A linter is a Nim module that declares one or more [Check] and exports a [Linter] value. Like any other Nim module, it can sit next to the config that uses it in your project or be installed with Nimble.

# A minimal linter

This is an example linter from the tests:

.. include:: ../tests/namelinter.nim
  :code:

Three things make this a linter:

- a settings type, which may be empty
- a proc taking the file's AST and the settings, returning a sequence of [Finding]
- a [Linter] value and one [Check] per rule, created with [addCheck]

Checks receive the parsed file as a `PNode` from Nim's own compiler AST module (`compiler/ast`). Lint neither converts the tree nor provides a tree type of its own: the node a check walks is exactly the node the parser produced.

Writing a check means importing `compiler/ast` and matching on nodes. A check doesn't modify the tree: the same AST is shared by every step that runs against the file.

.. important::
  To make `compiler/ast` importable in your linter and the Lint config, you have to add the Nim compiler source path to the compiler config:

  .. include:: ../tests/linter.nims
    :code:

  Put that in a [config file](https://nim-lang.org/docs/nimc.html#compiler-usage-configuration-files) affecting your linter and Lint config, e.g. `linter.nims` for `linter.nim`.

## Settings

Settings are a plain object. Give the fields a default value in the type definition.

.. include:: ../tests/namelinter.nim
  :code:
  :start-after: #ANCHOR: settings
  :end-before: #ANCHOR_END: settings

A config that provides settings has its keys checked against this type, so a misspelled key is a compile error.

## Findings

A [Finding] carries a position and a message, and nothing else.

A check does not know the file it runs against, the linter it belongs to, or the severity its findings are reported with. The runner attaches all of that when it collects findings, which is what lets the same check run at different severities in different steps.

Use [toFinding] to build one from an AST node; it extracts the position from the node:

.. include:: ../tests/namelinter.nim
  :code:
  :start-after:#ANCHOR: runConstNames
  :end-before:#ANCHOR_END: runConstNames
