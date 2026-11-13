# lint
# Copyright 2025-2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

## The runner: walks sources, parses files, runs steps, assembles reports.

import std/[algorithm, os, strformat, strutils, tables, sequtils]

import glob

import compiler/[ast, parser, idents, options]
import compiler/lineinfos except Severity

import ./[cli, suppress, types]

type
  ExitMode* {.pure.} = enum
    emClean = 0
    emErrorsFound = 1
    emParseError = 2
    emNoSources = 3
    emCheckError = 4

  FindingTag* = object ## A finding with everything the runner knows attached.
    severity*: Severity
    stepLabel*: string
    checkName*: string
    file*: string
    finding*: Finding

  StepReport* = object
    label*: string
    findings*: seq[FindingTag]

  FileReport* = object
    file*: string
    stepReports*: seq[StepReport]

  RunReport* = object
    fileReports*: seq[FileReport]

  ParseFailure* = object of CatchableError

proc normalize(path: string): string =
  ## The glob library matches against patterns without a leading `./`.

  if path.startsWith("./"):
    path[2 .. ^1]
  else:
    path

proc isIgnored(file: string, patterns: seq[string]): bool =
  let f = normalize(file)

  for p in patterns:
    if f.matches(normalize(p)):
      return true

proc nimFiles(pattern: string): seq[string] =
  ## Expands a glob pattern to the `.nim` files it matches.

  for path in walkGlob(pattern, options = {Files, FileLinks, DirLinks, Hidden}):
    if splitFile(path).ext == ".nim":
      result.add normalize(path)

proc collectFiles(config: Config, targets: seq[Target]): seq[string] =
  ## Returns the files to lint in ascending path order.
  ##
  ## With `targets`, they replace the config's sources and ignored patterns
  ## entirely: an explicit argument is a request to lint exactly that.

  let paths =
    if len(targets) == 0:
      config.sources
    else:
      targets.mapIt(it.path)

  for path in paths:
    if fileExists(path):
      result.addUnique(path)
    elif dirExists(path):
      for file in nimFiles("$#/**" % path):
        result.addUnique(file)
    else:
      for file in nimFiles(path):
        result.addUnique(file)

  if len(targets) == 0:
    result.keepItIf(not it.isIgnored(config.ignoredPatterns))

  result.sort()

proc raiseParseError(conf: ConfigRef, info: TLineInfo, msg: TMsgKind, arg: string) =
  ## The default parser error handler calls `quit`, which would kill the whole
  ## run on one bad file. Raise instead so the runner can report it.

  raise newException(ParseFailure, "(" & $info.line & ", " & $info.col & ") " & arg)

proc parseFile(path: string): tuple[ast: PNode, lines: seq[string]] =
  let
    src = readFile(path)
    cache = newIdentCache()
    conf = newPartialConfigRef()

  result.ast = parseString(src, cache, conf, path, errorHandler = raiseParseError)
  result.lines = src.splitLines()

proc renderFinding(tag: FindingTag): string =
  fmt"[{tag.stepLabel}][{tag.checkName}][{tag.severity}][{tag.file}:{tag.finding.line}:{tag.finding.col}] {tag.finding.msg}"

proc renderGithub(tag: FindingTag): string =
  ## A GitHub Actions workflow command, which the runner turns into an inline
  ## annotation on the pull request.

  let
    kind =
      if tag.severity == Severity.error: "error"
      else: "warning"
    title = tag.stepLabel & "/" & tag.checkName

  fmt"::{kind} file={tag.file},line={tag.finding.line},col={tag.finding.col},title={title}::{tag.finding.msg}"

proc `$`*(report: RunReport, format = Format.text): string =
  var hints, errors = 0

  for fileReport in report.fileReports:
    for stepReport in fileReport.stepReports:
      for tag in stepReport.findings:
        case tag.severity
        of Severity.hint:
          inc hints
        of Severity.error:
          inc errors

        case format
        of Format.github:
          result.add renderGithub(tag) & "\n"
        of Format.text:
          result.add renderFinding(tag) & "\n"

  if format != Format.github:
    result.add &"hints: {hints}, errors: {errors}\n"

proc exitMode*(report: RunReport): ExitMode =
  for fileReport in report.fileReports:
    for stepReport in fileReport.stepReports:
      for tag in stepReport.findings:
        if tag.severity == Severity.error:
          return ExitMode.emErrorsFound

  ExitMode.emClean

proc run*(config: Config, targets: seq[Target] = @[], format = Format.text) =
  ## Runs the config and exits with the code for the resulting exit mode.
  ##
  ## `targets` come from the command line and override the config's sources.

  var exitCode = ExitMode.emClean

  let files = collectFiles(config, targets)
  if files.len == 0:
    stderr.writeLine "no sources to lint"
    quit(ord(ExitMode.emNoSources))

  var report = RunReport()

  # Line ranges requested on the command line, keyed by path.
  var rangesByPath: Table[string, seq[tuple[first, last: int]]]
  for target in targets:
    if target.lines.len > 0:
      rangesByPath[target.path] = target.lines

  for file in files:
    var
      fileReport = FileReport(file: file)
      ast: PNode
      sourceLines: seq[string]
      parseFailed = false

    try:
      (ast, sourceLines) = parseFile(file)
    except CatchableError as e:
      parseFailed = true
      fileReport.stepReports.add StepReport(
        label: "runner",
        findings: @[
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
        # Explicit targets override every ignore, including step-level ones: a
        # named file is a request to lint it.
        if targets.len == 0 and isIgnored(file, step.ignoredPatterns):
          continue

        var stepReport = StepReport(label: step.label)
        for check in step.checks:
          var findings: seq[Finding]
          try:
            findings = check.run(ast)
          except Exception as e:
            stderr.writeLine &"check error: [{step.label}][{check.name}] {file}: {e.msg}"
            quit(ord(ExitMode.emCheckError))
          for f in findings:
            if rangesByPath.hasKey(file) and not inRanges(f.line, rangesByPath[file]):
              continue
            if isSuppressed(sourceLines, f.line):
              continue
            stepReport.findings.add FindingTag(
              severity: check.severity,
              stepLabel: step.label,
              checkName: check.name,
              file: file,
              finding: f,
            )
        fileReport.stepReports.add stepReport

    report.fileReports.add(fileReport)

  stdout.write report.`$`(format)

  let mode = report.exitMode

  if exitCode != ExitMode.emParseError:
    exitCode = mode

  quit(ord(exitCode))

