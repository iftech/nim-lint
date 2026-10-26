## Core types shared by the library, the linters, and the config file.

import compiler/ast

type
  Severity* = enum
    hint
    error

  Finding* = object
    ## What a check returns. Deliberately carries no severity, no label, and
    ## no file path: the runner stamps those.
    line*: int
    col*: int
    msg*: string

  Check*[S] = object
    ## One check declared by a linter, bound to its settings type.
    name*: string
    run*: proc(ast: PNode, settings: S): seq[Finding]

  Linter* = object
    ## A group of checks. A linter module exports one `Linter` value.
    name*: string

  StepSetting* = object
    ## Runtime form of one `check` entry: the check plus its settings,
    ## type-erased at the last moment.
    name*: string
    severity*: Severity
    run*: proc(ast: PNode): seq[Finding]

  Step* = object
    ## One declared `step` block.
    label*: string
    linter*: string
    ignoredPatterns*: seq[string]
    checks*: seq[StepSetting]

  Config* = object
    sources*: seq[string]
    ignoredPatterns*: seq[string]
    steps*: seq[Step]

proc newLinter*(name: string): Linter =
  Linter(name: name)

proc check*[S](
    linter: Linter, name: string, run: proc(ast: PNode, settings: S): seq[Finding]
): Check[S] =
  ## Used by linter modules to declare one check and its settings type.
  Check[S](name: name, run: run)

proc finding*(node: PNode, msg: string): Finding =
  ## Builds a finding located at a node.
  Finding(line: int(node.info.line), col: int(node.info.col), msg: msg)
