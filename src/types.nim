import compiler/lineinfos

import std/strformat
import std/sequtils

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

  Report* = object
    filepath*: string
    findings*: seq[Finding]

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

proc init*(T: type Report, filepath: string, findings: seq[Finding]): T =
  T(filepath: filepath, findings: findings)

proc `$`*(finding: Finding): string =
  &"[{finding.rulename}][{finding.severity}][{finding.line}:{finding.col}] {finding.msg}"

proc `$`*(report: Report): string =
  let
    hintCount = report.findings.countIt(it.severity == Severity.hint)
    errorCount = report.findings.countIt(it.severity == Severity.error)
  result.add(&"[{report.filepath}] hints: {hintCount}, errors: {errorCount}\n")
  for finding in report.findings:
    result.add(&"\t{finding}\n")

proc hasErrors*(report: Report): bool =
  for finding in report.findings:
    if finding.severity == Severity.error:
      return true
