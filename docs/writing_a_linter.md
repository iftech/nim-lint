.. title:: Writing a Linter
.. importdoc:: api/lint/private/types

A linter is a Nim module that declares one or more [Check] and exports a [Linter] value. Like any other Nim module, it can sit next to the config that uses it in your project or be installed with Nimble.

# A minimal linter

This is an example linter from the tests:

.. include:: ../tests/namelinter.nim
  :code:

Three things make this a linter:

- a settings type, which may be empty
- a proc taking the original source text, the file's AST, and the settings, returning a sequence of [Finding]
- a [Linter] value and one [Check] per rule, created with [addCheck]

Checks receive the original source as a `string` and the parsed file as a `PNode` from Nim's own compiler AST module (`compiler/ast`). Lint neither converts the tree nor provides a tree type of its own: the node a check walks is exactly the node the parser produced.

A check can inspect the source text, match on AST nodes, or combine both. It doesn't modify its inputs: the source and AST are shared by every step that runs against the file.

The old `proc(ast: PNode, settings: S): seq[Finding]` registration remains available but is deprecated. Add `source: string` as the first parameter to migrate; checks that only inspect the AST can leave it unused.

.. important::
  To make `compiler/ast` importable in your linter and the Lint config, you have to add the Nim compiler source path to the compiler config:

  .. include:: ../tests/linter.nims
    :code:

  Put that in a [config file](https://nim-lang.org/docs/nimc.html#compiler-usage-configuration-files) affecting your linter and Lint config, e.g. `linter.nims` for `linter.nim`.

## Checking comments

The original source preserves comments, whitespace, and line endings. This example checks standalone comment lines for TODO markers:

.. include:: ../tests/commentlinter.nim
  :code:

This is a deliberately small example, not a full Nim comment lexer: distinguishing comments from text inside multiline string literals needs additional parsing.

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

For findings in source text, construct a `Finding` with a 1-based line, a 0-based column, and a message, as in the comment check above.

Use [toFinding] to build one from an AST node; it extracts the position from the node:

.. include:: ../tests/namelinter.nim
  :code:
  :start-after:#ANCHOR: runConstNames
  :end-before:#ANCHOR_END: runConstNames
