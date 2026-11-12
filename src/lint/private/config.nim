# lint
# Copyright 2025-2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

## The `runLint` macro: turns the config block into a typed `Config` value,
## then runs it.

import std/[macros, os]

import compiler/ast

import ./cli
import ./types
import ./runner

proc toSeverity(node: NimNode): Severity =
  case node.strVal
  of "hint":
    Severity.hint
  of "error":
    Severity.error
  else:
    error("severity must be `hint` or `error`, got `" & node.strVal & "`", node)

proc strList(node: NimNode): NimNode =
  ## Validates a sequence-of-strings literal and returns it.
  if node.kind != nnkBracket:
    error("expected a list of strings, e.g. [\"./src\"]", node)
  for item in node:
    if item.kind notin {nnkStrLit .. nnkTripleStrLit}:
      error("expected a string literal", item)
  node

macro mkStepCheck(check: typed, sev: static Severity, settings: untyped): untyped =
  ## Builds one `StepSetting`.
  ##
  ## The settings type comes from the check's own `Check[S]` type, so building
  ## an object constructor from it makes a misspelled key a compile error.
  let typ = check.getTypeInst
  if typ.kind != nnkBracketExpr or typ.len != 2 or typ[0].eqIdent("Check") == false:
    error("`" & check.strVal & "` is not a check", check)

  let settingsType = typ[1]

  # With no `settings:` block, the check's own declared defaults apply.
  var ctor: NimNode
  if settings.len == 0:
    ctor = newTree(nnkDotExpr, check, ident"defaults")
  else:
    ctor = newTree(nnkObjConstr, settingsType)
    for stmt in settings:
      if stmt.kind != nnkAsgn or stmt[0].kind != nnkIdent:
        error("settings entries must look like `name = value`", stmt)
      var value = copyNimTree(stmt[1])
      # Nim does not convert an array literal to `seq` inside an object
      # constructor, so wrap list values in `@`. The operator must be bound to
      # `system.@`; a bare `ident("@")` does not resolve and produces a broken
      # value for the field.
      if value.kind == nnkBracket:
        value = newTree(nnkPrefix, bindSym"@", value)
      ctor.add newTree(nnkExprColonExpr, stmt[0], value)

  # The check is identified by the identifier the config binds it to: that is
  # the name the user wrote and the name the report shows.
  let
    runId = check
    astId = genSym(nskParam, "ast")
    name = newLit(check.strVal)
    severity = newLit(sev)

  # The settings value is baked into the generated proc rather than captured
  # from an enclosing scope: a captured local is reconstructed from the syntax
  # tree inside the closure's scope, which loses `seq` fields (they come back
  # nil at run time).
  result = quote:
    StepSetting(
      name: `name`,
      severity: `severity`,
      run: proc(`astId`: PNode): seq[Finding] =
        `runId`.run(`astId`, `ctor`),
    )

proc parseCheck(stmt: NimNode): NimNode =
  if stmt.len != 3 or stmt[0].strVal != "check":
    error("expected `check <name>:`", stmt)
  let checkName = stmt[1]
  if checkName.kind notin {nnkIdent, nnkDotExpr}:
    error("expected a check name", checkName)

  var severity = newLit(Severity.hint)
  var settings = newNimNode(nnkStmtList)

  for entry in stmt[2]:
    case entry.kind
    of nnkAsgn:
      if entry[0].kind != nnkIdent:
        error("expected a check field name", entry[0])
      case entry[0].strVal
      of "severity":
        if entry[1].kind != nnkIdent:
          error("severity must be `hint` or `error`", entry[1])
        severity = newLit(toSeverity(entry[1]))
      else:
        error(
          "unknown check field `" & entry[0].strVal &
            "` (settings go in a `settings:` block)",
          entry[0],
        )
    of nnkCall:
      if entry[0].strVal != "settings":
        error("unknown check entry `" & entry[0].strVal & "`", entry[0])
      if settings.len != 0:
        error("`settings` is declared twice", entry[0])
      settings = entry[1]
    else:
      error("unexpected entry in check", entry)

  # `checkName` is passed as the first argument so it is resolved in the
  # enclosing scope and arrives at `mkStepCheck` as a typed symbol. It may be a
  # plain identifier or a qualified `linter.check` when two linters export
  # checks with the same name.
  result = newCall(bindSym"mkStepCheck", checkName, severity, settings)

proc parseStep(stmt: NimNode): NimNode =
  if stmt.kind != nnkCommand or stmt[0].strVal != "step":
    error("expected `step \"label\":`", stmt)
  if stmt.len != 3 or stmt[1].kind notin {nnkStrLit .. nnkTripleStrLit}:
    error("`step` takes a label string and a block", stmt)

  let label = newLit(stmt[1].strVal)
  var ignored: NimNode = nnkBracket.newTree()
  var checks = newNimNode(nnkBracket)

  for entry in stmt[2]:
    case entry.kind
    of nnkAsgn:
      if entry[0].kind != nnkIdent:
        error("expected a step field name", entry[0])
      case entry[0].strVal
      of "ignoredPatterns":
        ignored = strList(entry[1])
      else:
        error("unknown step field `" & entry[0].strVal & "`", entry[0])
    of nnkCommand:
      checks.add parseCheck(entry)
    else:
      error("unexpected entry in step", entry)

  let ignoredId = genSym(nskLet, "ignored")
  let checksId = genSym(nskLet, "checks")
  result = quote:
    block:
      let `ignoredId`: seq[string] = @`ignored`
      let `checksId`: seq[StepSetting] = @`checks`
      Step(label: `label`, ignoredPatterns: `ignoredId`, checks: `checksId`)

macro runLint*(body: untyped): untyped =
  ## Declares a lint config and runs it.
  var sources: NimNode = nnkBracket.newTree()
  var ignored: NimNode = nnkBracket.newTree()
  var steps = newNimNode(nnkBracket)

  for entry in body:
    case entry.kind
    of nnkAsgn:
      if entry[0].kind != nnkIdent:
        error("expected a config field name", entry[0])
      case entry[0].strVal
      of "sources":
        sources = strList(entry[1])
      of "ignoredPatterns":
        ignored = strList(entry[1])
      else:
        error("unknown config field `" & entry[0].strVal & "`", entry[0])
    of nnkCommand:
      steps.add parseStep(entry)
    else:
      error("unexpected entry in config", entry)

  let
    sourcesId = genSym(nskLet, "sources")
    ignoredId = genSym(nskLet, "ignored")
    stepsId = genSym(nskLet, "steps")
    configId = genSym(nskLet, "config")

  result = quote:
    block:
      let `sourcesId`: seq[string] = @`sources`
      let `ignoredId`: seq[string] = @`ignored`
      let `stepsId`: seq[Step] = @`steps`
      let `configId` =
        Config(sources: `sourcesId`, ignoredPatterns: `ignoredId`, steps: `stepsId`)
      let options = parseOptions(commandLineParams())
      if options.help:
        stdout.write helpText
        quit(0)
      run(`configId`, options.targets, options.format)

