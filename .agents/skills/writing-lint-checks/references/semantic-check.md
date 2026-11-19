# Semantic checks

Read this only when resolved information is essential. Confirm the installed Lint
and Nim APIs before adapting the example.

A semantic callback is:

```nim
proc runRule(source: string, ast, typed: PNode, settings: Settings): seq[Finding]
```

Register with `linter.addCheck`; it returns `SemCheck[Settings]`. Use `semCheck` in
the config. Do not use a typed tree as a replacement for parsed syntax: identifiers
can become symbols, macros can expand, and dot calls can become ordinary calls.

## Complete example: inferred floating-point variables

`floatlinter.nim`:

```nim
import compiler/ast
import lint

type FloatSettings* = object

proc runFloatVariables(
    source: string, ast, typed: PNode, settings: FloatSettings
): seq[Finding] =
  var findings: seq[Finding]
  proc inspect(node: PNode) =
    if node.isNil:
      return
    if node.kind in {nkLetSection, nkVarSection}:
      for definition in node:
        if definition.kind == nkIdentDefs and definition.len >= 3:
          for index in 0 ..< definition.len - 2:
            let name = definition[index]
            if name.kind == nkSym and not name.typ.isNil and
                name.typ.kind in {tyFloat .. tyFloat128}:
              findings.add name.toFinding(
                "variable `" & name.sym.name.s & "` has a floating-point type"
              )
    for child in node:
      inspect(child)

  inspect(typed)
  findings

let
  floatLinter* = Linter()
  floatVariables* = floatLinter.addCheck(runFloatVariables)
```

`linter.nim`:

```nim
import lint
import floatlinter

runLint:
  sources = ["src"]
  step "Numeric types":
    semCheck floatVariables:
      severity = error
```

Tier justification: `let value = sqrt(2.0)` does not spell the variable's type;
the rule needs the compiler's resolved type. `let count = 2` is a near-miss.

This bounded example checks float/float32/float64/float128 directly. It is not a
complete numeric policy for aliases, distinct wrappers, or macro-generated code.
Do not expand it beyond the user's contract merely to add generality.

## Custom formatter policies

Before implementing "every type has a custom formatter," settle these separately:

1. Which types: module-level concrete objects, distinct types, ref objects,
   generic definitions, instantiations, or aliases?
2. Which formatter signatures and return types count?
3. Which declarations are searched: same module, import closure, or symbols
   actually visible at the call site?
4. Do generic overloads count? For a type-specific custom representation, a
   standard fallback or unconstrained generic procedure is not enough.

Collect type declarations and formatter candidates, then match resolved types
using the compiler's type comparison facilities (for example `sameType` from
`compiler/types`, after checking that version). Do not match just `typ`'s printed
name. Avoid stripping distinct wrappers unless the policy explicitly treats
those types as equivalent. Do not count a forward declaration as an implemented
formatter when a body is required.

An imported declaration existing does not prove it is visible or selected by
Nim overload resolution. An explicit formatter existing does not prove a call
uses it or that its body redacts secrets. If the user asks which formatter a
logging expression invokes, inspect the resolved call, not just declarations.
Some contracts need more compiler context than Lint supplies; describe that gap
instead of inventing access to a module graph or semantic resolver in callbacks.

## Partial trees and source attribution

Compiler errors do not automatically skip semantic checks. The typed tree may be
partial: guard nil types, error types, child counts, symbol kinds, and variant
fields before using them. Limit conclusions to information actually established.
Use `for child in node` rather than raw `.sons` field access on arbitrary nodes.
Inspect the compiler's actual AST representation when uncertain, not repeated
near-identical guesses or assumptions from another Nim version.

Typed node locations may refer to imported macro/template definitions. Attribute
findings to the checked file; reject or map foreign/generated locations when the
rule supports expansion. The simple example above has no such attribution
machinery: restrict it to directly written declarations and state that limitation.
Never silently report a dependency location as a line in the selected file.

## Execution and cost

Use the project's Nim version to compile the lint executable, with the compiler
source search path configured as in the ordinary reference. Keep the same Nim
installation on `PATH` at runtime; compiler code is embedded, but stdlib sources
are read from disk. Changing `PATH` does not switch the embedded compiler.

Run `./linter --semantic` (or `-s`) explicitly. It also runs ordinary checks.
Without the flag, semantic checks are skipped with a warning. Each applicable
entry file gets an independent compiler context and import closure, so analysis
can repeat costly configuration/stdlib work. Avoid semantic checks when source
and parsed AST suffice. Reordering checks does not provide earlier findings:
the report is buffered until the run completes.

Compiler configuration is loaded by Nim. Build-task-only arguments are not
inferred automatically. JavaScript semantic analysis is unsupported. Configs,
macros, and compile-time code execute; do not run untrusted input without the
appropriate isolation/permission.

Compiler diagnostics are warnings in Lint, separate from check findings; they are
not suppressed by line ranges or `#nolint` and do not alone change the exit code.
If no tree is available, the runner warns about unavailable checks. Some fatal
compiler failures can still terminate the process. A green run is not proof that
analysis was complete: inspect diagnostics when trying the generated linter.
Do not add semantic fixtures or recovery tests unless the user requests tests for
their custom rule logic.
