## The runner: walks sources, parses files, runs steps, assembles reports.

import std/[algorithm, os, sets, strformat]

import glob

import compiler/[ast, parser, idents, options]
import compiler/lineinfos except Severity

import ./types


type
  ExitMode* = enum
    emClean = 0
    emErrorsFound = 1
    emParseError = 2
    emConfigError = 3
    emCheckError = 4

  FindingTag* = object
    ## A finding with everything the runner knows attached.
    severity*: Severity
    stepLabel*: string
    checkName*: string
    file*: string
    finding*: Finding

  StepReport* = object
    label*: string
    linter*: string
    findings*: seq[FindingTag]

  FileReport* = object
    file*: string
    stepReports*: seq[StepReport]

  RunReport* = object
    fileReports*: seq[FileReport]

proc normalize(path: string): string =
  ## The glob library matches against patterns without a leading `./`.
  result = path
  while result.len > 2 and result[0] == '.' and result[1] == '/':
    result = result[2 .. ^1]

proc isIgnored(file: string, patterns: seq[string]): bool =
  let f = normalize(file)
  for p in patterns:
    if f.matches(normalize(p)):
      return true

proc collectFiles(config: Config): seq[string] =
  ## Walks the sources and returns matching files in ascending path order.
  var seen = initHashSet[string]()
  for source in config.sources:
    if not dirExists(source) and not fileExists(source):
      raise newException(IOError, "source path does not exist: " & source)
    if fileExists(source):
      if not seen.contains(source):
        seen.incl(source)
        result.add(source)
      continue
    for path in walkDirRec(source):
      if splitFile(path).ext == ".nim" and
          not isIgnored(path, config.ignoredPatterns):
        if not seen.contains(path):
          seen.incl(path)
          result.add(path)
  result.sort()

type ParseFailure* = object of CatchableError

proc raiseParseError(conf: ConfigRef; info: TLineInfo; msg: TMsgKind; arg: string) =
  ## The default parser error handler calls `quit`, which would kill the whole
  ## run on one bad file. Raise instead so the runner can report it.
  raise newException(ParseFailure, "(" & $info.line & ", " & $info.col & ") " & arg)

proc parseFile(path: string): PNode =
  let
    src = readFile(path)
    cache = newIdentCache()
    conf = newPartialConfigRef()
  result = parseString(src, cache, conf, path, errorHandler = raiseParseError)

proc renderFinding(tag: FindingTag): string =
  result = &"[{tag.stepLabel}][{tag.checkName}][{tag.severity}][{tag.file}:{tag.finding.line}:{tag.finding.col}] {tag.finding.msg}"

proc `$`*(report: RunReport): string =
  var hints, errors = 0
  for fileReport in report.fileReports:
    for stepReport in fileReport.stepReports:
      for tag in stepReport.findings:
        case tag.severity
        of Severity.hint: inc hints
        of Severity.error: inc errors
        result.add renderFinding(tag) & "\n"
  result.add &"hints: {hints}, errors: {errors}\n"

proc exitMode*(report: RunReport): ExitMode =
  for fileReport in report.fileReports:
    for stepReport in fileReport.stepReports:
      for tag in stepReport.findings:
        if tag.severity == Severity.error:
          return emErrorsFound
  emClean

proc run*(config: Config) =
  ## Runs the config and exits with the code for the resulting exit mode.
  var exitCode = ExitMode.emClean

  var files: seq[string]
  try:
    files = collectFiles(config)
  except IOError as e:
    stderr.writeLine "config error: " & e.msg
    quit(ord(ExitMode.emConfigError))

  var report = RunReport()

  for file in files:
    var fileReport = FileReport(file: file)
    var ast: PNode
    var parseFailed = false
    try:
      ast = parseFile(file)
    except CatchableError as e:
      parseFailed = true
      fileReport.stepReports.add StepReport(
        label: "runner",
        linter: "",
        findings:
          @[
            FindingTag(
              severity: Severity.error,
              stepLabel: "runner",
              checkName: "",
              file: file,
              finding: Finding(line: 0, col: 0, msg: "parse error: " & e.msg),
            )
          ],
      )
      exitCode = ExitMode.emParseError

    if not parseFailed:
      for step in config.steps:
        if isIgnored(file, step.ignoredPatterns):
          continue
        var stepReport = StepReport(label: step.label, linter: step.linter)
        for check in step.checks:
          var findings: seq[Finding]
          try:
            findings = check.run(ast)
          except CatchableError as e:
            stderr.writeLine &"check error: [{step.label}][{check.name}] {file}: {e.msg}"
            quit(ord(ExitMode.emCheckError))
          for f in findings:
            stepReport.findings.add FindingTag(
              severity: check.severity,
              stepLabel: step.label,
              checkName: check.name,
              file: file,
              finding: f,
            )
        fileReport.stepReports.add stepReport
    report.fileReports.add fileReport

  stdout.write $report
  let mode = report.exitMode
  if exitCode != ExitMode.emParseError:
    exitCode = mode
  quit(ord(exitCode))
