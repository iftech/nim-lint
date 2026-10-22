import compiler/lineinfos

import std/strformat

type
  Severity* = enum
    hint
    error

  Finding* = object
    severity*: Severity
    rulename*: string
    filepath*: string
    line*: int # 1-indexed
    col*: int # 0-indexed
    msg*: string

proc init*(
    T: type Finding,
    severity: Severity,
    rulename: string,
    filepath: string,
    lineinfo: TLineInfo,
    msg: string,
): T =
  T(
    severity: severity,
    rulename: rulename,
    filepath: filepath,
    line: int(lineinfo.line),
    col: int(lineinfo.col),
    msg: msg,
  )

proc `$`*(issue: Finding): string =
  &"[{issue.rulename}][{issue.severity}][{issue.filepath}:{issue.line}:{issue.col}] {issue.msg}"
