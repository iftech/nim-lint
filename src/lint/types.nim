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
    defaults*: S ## Used when a config declares the check without settings.
    requiresTyped*: bool ## Whether the check needs `nkSym` nodes with types.

  Linter* = object
    ## A group of checks. A linter module exports one `Linter` value.
    name*: string

  StepSetting* = object
    ## Runtime form of one `check` entry: the check plus its settings,
    ## type-erased at the last moment.
    name*: string
    severity*: Severity
    run*: proc(ast: PNode): seq[Finding]
    requiresTyped*: bool

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
    linter: Linter,
    name: string,
    run: proc(ast: PNode, settings: S): seq[Finding],
    defaults: S = default(S),
    requiresTyped: bool = false,
): Check[S] =
  ## Used by linter modules to declare one check, its settings type, and the
  ## settings to use when a config does not provide any.
  ##
  ## Set `requiresTyped` for checks that read types from the tree. Such a check
  ## cannot run when the project does not sem; the runner reports it as skipped
  ## instead of running it against a parse-only tree.
  Check[S](name: name, run: run, defaults: defaults, requiresTyped: requiresTyped)

proc finding*(node: PNode, msg: string): Finding =
  ## Builds a finding located at a node.
  Finding(line: int(node.info.line), col: int(node.info.col), msg: msg)
