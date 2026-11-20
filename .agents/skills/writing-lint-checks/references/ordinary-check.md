# Ordinary checks

Read this after choosing an ordinary rule. These examples target Lint's
source-aware `addCheck` API; confirm the project's installed version first.

An ordinary callback is:

```nim
proc runRule(source: string, ast: PNode, settings: Settings): seq[Finding]
```

`source` is the original text. `ast` is the parsed, not semantically analyzed,
file. Both are available; unused inputs are fine. Prefer parsing to regexes for
Nim structure, and source text for details the parser discards. Walk children with
`for child in node`, guard nil and node kinds before accessing variant fields,
and respect the rule's scope rather than recursively scanning everything.

## Complete example: trailing whitespace

`whitespacelinter.nim`:

```nim
import std/strutils
import compiler/ast
import lint

type WhitespaceSettings* = object

proc runTrailingWhitespace(
    source: string, ast: PNode, settings: WhitespaceSettings
): seq[Finding] =
  let lines = source.splitLines()
  for index, line in lines:
    var ending = line.len
    while ending > 0 and line[ending - 1] in {' ', '\t'}:
      dec ending
    if ending < line.len:
      result.add Finding(
        line: index + 1, col: ending, msg: "trailing whitespace"
      )

let
  whitespaceLinter* = Linter()
  trailingWhitespace* = whitespaceLinter.addCheck(runTrailingWhitespace)
```

`linter.nim`:

```nim
import lint
import whitespacelinter

runLint:
  sources = ["src"]
  step "Whitespace":
    check trailingWhitespace:
      severity = hint
```

This rule intentionally examines all source lines, including multiline string
contents. If the user wants string contents excluded, implement lexical handling
or choose a narrower contract; do not pretend this example already does that.

## Build configuration

The Lint package is resolved by the project's dependency setup. Compiler modules
also need the compiler-source search path. Where not already configured, a
`config.nims` affecting both modules can contain:

```nim
--path:"$nim/"
```

Do not replace an existing config to add this line. Compiler tree definitions
come from the Nim installation selected to build the executable.

## Settings and findings

A check's exported settings object provides fields the config can override:

```nim
check someRule:
  severity = error
  settings:
    minimum = 3
```

Use only real fields from that rule's settings type. Omitting `settings` uses the
registered defaults. `linter.addCheck(callback, Settings(...))` can supply those
defaults explicitly. Registration does not name the report entry; the config's
check identifier does.

Return findings without severity or file paths. For a parsed node:

```nim
result.add node.toFinding("explain the observation")
```

Do not import the compiler's `Severity` merely to configure lint severity. The
config DSL accepts `hint` or `error`; compiler diagnostic severity is a different
type.

## Execution boundaries

Lint parses the file before running ordinary checks; parse-invalid input does
not reach the callback. Nim rejects tabs in some source positions, so this rule
does not replace the parser's diagnostics. Findings point to the original source,
not a transformed string. The runner handles `#nolint` suppression and line-range
filtering. Explicit CLI targets override all config ignored patterns.

Compile and try the linter against existing project sources. Do not add tests or
fixtures for these framework behaviors; tests for custom rule logic are optional
and user-requested.
