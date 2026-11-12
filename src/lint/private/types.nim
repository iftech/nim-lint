# lint
# Copyright 2025-2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

## Core types shared by the library, the linters, and the config file.
##
## The types a linter author needs are re-exported by `lint`. The rest are
## internal to the runner and the config macro.

import compiler/ast

type
  Severity* {.pure.} = enum
    hint
    error

  Finding* = object
    ## What a check returns. Deliberately carries no severity, no label, and
    ## no file path: the runner stamps those.
    line*: int
    col*: int
    msg*: string

  Check*[S] = object ## One check declared by a linter, bound to its settings type.
    run*: proc(ast: PNode, settings: S): seq[Finding]
    defaults*: S ## Used when a config declares the check without settings.

  Linter* = object ## A group of checks. A linter module exports one `Linter` value.

  StepSetting* = object
    ## Runtime form of one `check` entry: the check plus its settings,
    ## type-erased at the last moment.
    name*: string
    severity*: Severity
    run*: proc(ast: PNode): seq[Finding]

  Step* = object ## One declared `step` block.
    label*: string
    ignoredPatterns*: seq[string]
    checks*: seq[StepSetting]

  Config* = object
    sources*: seq[string]
    ignoredPatterns*: seq[string]
    steps*: seq[Step]

proc addCheck*[S](
    linter: Linter,
    run: proc(ast: PNode, settings: S): seq[Finding],
    defaults: S = default(S),
): Check[S] =
  ## Used by linter modules to declare one check, its settings type, and the
  ## settings to use when a config does not provide any.
  ##
  ## The check has no name of its own: a config refers to it by the identifier
  ## it binds the result to, and that identifier is what the report shows.

  Check[S](run: run, defaults: defaults)

proc toFinding*(node: PNode, msg: string): Finding =
  ## Builds a finding located at a node.

  Finding(line: int(node.info.line), col: int(node.info.col), msg: msg)

