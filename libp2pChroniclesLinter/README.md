# libp2pChroniclesLinter

A [lint](https://github.com/iftech/nim-lint) linter that enforces the Chronicle logging rules currently checked by nim-libp2p's [`tools/audit_logs.py`](https://github.com/iftech/nim-libp2p/blob/master/tools/audit_logs.py).

It exists to test two things: whether a project-specific linter is easy to build and ship outside of lint's own repository, and how much of the Python script can be replaced with rules that need only the parsed AST.

## Implemented rules

Five of the script's seven checks. Every one is syntactic: it reads the parsed Chronicle statement and needs nothing else.

| Check | Rule | Replaces (audit_logs.py) |
|---|---|---|
| `messageEndsWithPeriod` | Log messages must not end with a full stop | `message.endswith(".")` |
| `messageOneSentence` | Log messages must be a single sentence | `MULTI_SENTENCE` regex |
| `fieldNameLength` | Field names must be at least 3 characters | `FIELD_ASSIGNMENT` + `short_positional_fields` |
| `errForException` | Use `err` for exception text, not `msg`/`message`/`error`/`description` | `EXCEPTION_ALIAS` |
| `noPayloadWhenElevated` | `warn`/`error` must not carry payload fields | `PAYLOAD_FIELD` |

Both Chronicle call shapes are handled:

```nim
info "named fields", peerId = peerId, peerCount = count   # command syntax
info("named fields", peerId = peerId)                     # call syntax
```

Findings are reported at the offending log statement's line, which points at the statement rather than at the exact argument the Python script points to. That matches how the rest of lint reports and is more useful in a CI comment than a character offset.

## Not implemented: unbounded fields

The script's remaining rule is:

```
potentially unbounded log field must use shortLog
```

It is not implemented, because it cannot be decided from the syntax tree. To know whether a field is bounded, the check has to know the field's **type** and whether that type has a `shortLog` formatter. `audit_logs.py` approximates this by building a repository-wide symbol table with regular expressions (`source_types`), inferring types from `let x: T =`, parameter lists, object fields, and function return types, then intersecting the set of types with a `shortLog` against those with a `formatIt`.

A linter that walks a `PNode` sees identifiers, not resolved symbols: every variable in a parse-only AST is an `nkIdent` with no type attached. So there are three options:

1. **Port the heuristic.** Faithful to current behavior, including its blind spots, but it puts a fragile whole-repository regex symbol table inside a linter whose value is that it does not guess.
2. **Make it a project-level check.** It genuinely needs several files at once — `shortLog` is declared in one module, the field's type in another, and used in a third. lint does not have a project-level check kind yet. This is the first concrete rule that would justify one.
3. **Split the rule.** Keep the per-file part ("a field that looks unbounded has neither `shortLog` nor `.len`") and accept false positives on values that are actually bounded. This is a hint, not an error.

Which one is worth doing depends on how load-bearing this rule is in practice. See "Open questions" below.

## Usage

The linter is a normal lint linter, so it is configured the same way as any other:

```nim
import lint
import linters/chronicles

runLint:
  sources = ["./libp2p"]

  step "Check chronicles messages":
    linter = chronicles
    check messageEndsWithPeriod:
      severity = error
    check messageOneSentence:
      severity = error

  step "Check chronicles fields":
    linter = chronicles
    check fieldNameLength:
      severity = error
      settings:
        exceptions = ["ip"]
    check errForException:
      severity = error
    check noPayloadWhenElevated:
      severity = error
```

Compile and run it like any lint config:

```shell
nim c -r examples/chronicles_lint.nim
```

`examples/chronicles_lint.nim` runs against the fixture project in `tests/testproject/`.

## Settings

Every rule that encodes project policy is a setting. The defaults reproduce what `audit_logs.py` enforces today, so an unconfigured linter behaves like the script; a project with different conventions configures the check instead of forking the linter.

| Check | Setting | Default |
|---|---|---|
| `fieldNameLength` | `minLength` | `3` |
| | `exceptions` | `["id", "ip"]` |
| `errForException` | `field` | `"err"` |
| | `aliases` | `["description", "error", "message", "msg"]` |
| `noPayloadWhenElevated` | `levels` | `["warn", "error"]` |
| | `fields` | `msg`, `message`, `buffer`, `record`, `reply`, `response`, `rpcMsg`, `data`, `encoded`, `certificate`, `ticket`, `key` |
| `messageEndsWithPeriod` | `allowTrailingPeriod` | `false` |
| `messageOneSentence` | — | — |

A check uses its settings exactly as written: there are no "empty means default" rules, so an empty list really means "none". The defaults above apply only when the `settings:` block is omitted entirely, and they live on the check itself, so a linter author declares them once. `examples/chronicles_lint.nim` spells every setting out to show the surface; all of it can be omitted.

## Deviations from the script

- **Location granularity.** The script reports the offending line; so does this linter, but the column points at the log statement, not at the field.
- **Statement detection.** The script finds log calls with a line-oriented regex (`LOG_START`) and then treats the following indented lines as part of the block. This linter works on the AST, so multi-line calls, calls inside string literals, and calls nested in expressions are handled without the string-and-brace scanner the script needs.
- **No `formatIt` / `shortLog` resolution.** Follows from the rule above being unimplemented.

## Open questions for the maintainer

1. **How important is the unbounded-field rule?** If most real violations are caught by the five implemented checks, this linter can replace the script without typed analysis. If it is the rule that matters most, that is a strong argument for lint to support type-aware checks.
2. **Is line-level rather than argument-level reporting acceptable?** The script reports `file:line`; so does this, but through lint's normal finding format.
3. **Are the defaults right?** `fields`, `aliases`, `levels`, and the `id`/`ip` exceptions are copied from the script as defaults, but every one of them is now a setting. Tell us if any should differ per module rather than per project, since a setting applies to the whole step.
