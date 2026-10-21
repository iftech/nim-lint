import compiler/lineinfos

import std/strformat

import pkg/chronicles

type Issue* = object
  level*: LogLevel
  rulename*: string
  filepath*: string
  line*: int # 1-indexed
  col*: int # 0-indexed
  msg*: string

proc init*(
    T: type Issue,
    level: LogLevel,
    rulename: string,
    filepath: string,
    lineinfo: TLineInfo,
    msg: string,
): T =
  T(
    level: level,
    rulename: rulename,
    filepath: filepath,
    line: int(lineinfo.line),
    col: int(lineinfo.col),
    msg: msg,
  )

proc `$`*(issue: Issue): string =
  &"[{issue.rulename}][{issue.level}][{issue.filepath}:{issue.line}:{issue.col}] {issue.msg}"
