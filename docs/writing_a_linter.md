.. title:: Writing a Linter
.. importdoc:: api/lint/private/types

A linter is a Nim module that declares ordinary [Check] or semantic [SemCheck] rules and exports a [Linter] value. Like any other Nim module, it can sit next to the config that uses it in your project or be installed with Nimble.

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

## Semantic checks

A semantic check receives a separate typed AST in addition to the original source and parsed AST. Its callback has the signature `proc(source: string, ast, typed: PNode, settings: S): seq[Finding]`, where `S` is the check's settings type.

Register it with [addCheck], just like an ordinary check. The callback's extra `typed` parameter selects the overload returning a [SemCheck]. The config declares it with `semCheck` rather than `check`; using the wrong declaration is a compile error. Settings and defaults work the same way for both.

This example requires an explicit, type-specific `$` proc or func for every non-generic object or distinct type declared at module level. It compares resolved parameter types rather than names. Standard or user-defined generic fallbacks do not satisfy the rule. The example deliberately searches only declarations in the checked module; it does not perform overload resolution or verify the safety of the formatter's body.

.. include:: ../tests/stringifylinter.nim
  :code:

The parsed and typed trees both use `PNode`, but they are separate inputs. Semantic analysis resolves identifiers into symbols and can expand or transform code; it does not preserve every syntactic distinction. A semantic check can still consult the parsed tree or original source when it needs those distinctions.

.. warning::
  Semantic checks also run on partial trees after compiler errors. Nodes can have missing types, error types, or incomplete children. Check the information needed by a rule before using it, and do not infer a result from unavailable information. Nodes originating in imported macros or templates can refer to another file; findings refer only to the file being checked.

Semantic checks run only with `--semantic`. See [the CLI guide](./cli.html#semantic-checks) for the matching Nim installation requirement, compiler configuration, and analysis limitations.

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

For findings in source text, construct a [Finding] with a 1-based line, a 0-based column, and a message, as in the comment check above.

Use [toFinding] to build one from an AST node; it extracts the position from the node:

.. include:: ../tests/namelinter.nim
  :code:
  :start-after:#ANCHOR: runConstNames
  :end-before:#ANCHOR_END: runConstNames
