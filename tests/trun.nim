import std/[unittest, os, osproc, strutils, sequtils]

const
  config = "linter.nim"
  linterExecutable = config.splitFile().name
  testsDir = currentSourcePath().parentDir

proc compileLinter(): string =
  let (output, exitCode) =
    execCmdEx("nim c -d:release $#" % config, workingDir = testsDir)
  if exitCode != 0:
    echo output
    quit(exitCode)
  output

proc runLinter(targets = ""): tuple[output: string, exitCode: int] =
  let command = "$# $#" % [findExe(testsDir / linterExecutable), targets]
  execCmdEx(command, workingDir = testsDir)

proc removeLinterExecutable() =
  removeFile findExe(testsDir / linterExecutable)

suite "Run options":
  let compilationOutput = compileLinter()

  test "Legacy check warns and still runs":
    check compilationOutput.splitLines().anyIt(
      "Warning:" in it and "addCheck is deprecated" in it and
        "proc(source: string, ast: PNode, settings: S)" in it
    )
    let (output, exitCode) = runLinter("src/skip/skipped.nim")
    check exitCode == 0
    check "variable `y` is shorter than 3 characters" in output
    check "hints: 1, errors: 0" in output

  test "Project using the config":
    const
      findings = [
        "variable `a` is shorter than 3 characters",
        "variable `b` is shorter than 3 characters",
        "constant `invalid` should start with `k`",
      ]
      summary = "hints: 2, errors: 1"

    let (output, exitCode) = runLinter()

    check exitCode == 1

    for finding in findings:
      check finding in output

    check summary in output

  test "Single file":
    const
      finding = "variable `y` is shorter than 3 characters"
      summary = "hints: 1, errors: 0"

    let (output, exitCode) = runLinter("src/skip/skipped.nim")

    check exitCode == 0
    check finding in output
    check summary in output

  test "Specific lines":
    const
      finding = "variable `y` is shorter than 3 characters"
      summaryFinding = "hints: 1, errors: 0"
      summaryNoFinding = "hints: 0, errors: 0"

    block withFindingOnLine:
      let (output, exitCode) = runLinter("src/skip/skipped.nim src/skip/skipped.nim:3")
      check exitCode == 0
      check finding in output
      check summaryFinding in output

    block withFindingInRange:
      let (output, exitCode) =
        runLinter("src/skip/skipped.nim src/skip/skipped.nim:2-3")
      check exitCode == 0
      check finding in output
      check summaryFinding in output

    block noFinding:
      let (output, exitCode) = runLinter("src/skip/skipped.nim src/skip/skipped.nim:2")
      check exitCode == 0
      check finding notin output
      check summaryNoFinding in output

  test "Multiple files":
    const
      findings = [
        "variable `y` is shorter than 3 characters",
        "variable `z` is shorter than 3 characters",
      ]
      summary = "hints: 2, errors: 0"

    let (output, exitCode) = runLinter("src/skip/skipped.nim src/skip/skipped2.nim")

    check exitCode == 0

    for finding in findings:
      check finding in output

    check summary in output

  test "Directory":
    const
      findings = [
        "variable `y` is shorter than 3 characters",
        "variable `z` is shorter than 3 characters",
      ]
      summary = "hints: 2, errors: 0"

    let (output, exitCode) = runLinter("src/skip")

    check exitCode == 0

    for finding in findings:
      check finding in output

    check summary in output

  test "Glob pattern":
    const
      findings = [
        "variable `y` is shorter than 3 characters",
        "variable `z` is shorter than 3 characters",
      ]
      summary = "hints: 2, errors: 0"

    let (output, exitCode) = runLinter("src/skip/*")

    check exitCode == 0

    for finding in findings:
      check finding in output

    check summary in output

  test "Source comments":
    let (output, exitCode) = runLinter("src/skip2/comments.nim")
    check exitCode == 0
    check "[Check comments][todoComments][hint]" in output
    check ":1:2] unfinished comment: TODO" in output
    check ":5:4] unfinished comment: TODO" in output
    check "hints: 2, errors: 0" in output
    check ":3:" notin output
    check ":4:" notin output

  test "Source comments respect line ranges and output format":
    let (output, exitCode) = runLinter("--format=github src/skip2/comments.nim:5")
    check exitCode == 0
    check "::warning file=" in output
    check ",line=5,col=4," in output
    check "unfinished comment: TODO" in output
    check "line=1," notin output

  test "Semantic checks are opt-in and skipped checks are named once":
    let (output, exitCode) = runLinter("src/stringify.nim")
    check exitCode == 0
    check output.count("warning: semantic checks skipped") == 1
    check "customDollar" in output
    check "pass --semantic" in output
    check "has no custom `$` overload" notin output

  test "Default semantic run requires custom string representations":
    let (output, exitCode) = runLinter("--semantic")
    check exitCode == 1
    check "type `Account` has no custom `$` overload" in output
    check "type `AccountId` has no custom `$` overload" in output
    check "type `SafeAccount` has no custom `$` overload" notin output
    check "type `SafeId` has no custom `$` overload" notin output
    check "type `GenericBox` has no custom `$` overload" notin output
    check "[Check string representations][customDollar][error]" in output
    check "variable `a` is shorter than 3 characters" in output
    check "constant `invalid` should start with `k`" in output
    check "hints: 2, errors: 3" in output
    check "type mismatch" notin output
    check "[Conf]" notin output

  test "Semantic findings respect line ranges and output format":
    let (output, exitCode) = runLinter("--semantic --format=github src/stringify.nim:2")
    check exitCode == 1
    check "::error file=" in output
    check ",line=2," in output
    check "type `Account` has no custom `$` overload" in output
    check "type `AccountId` has no custom `$` overload" notin output

  test "Partial typed trees and later files are still checked":
    let (output, exitCode) =
      runLinter("--semantic src/skip2/broken_stringify.nim src/stringify.nim")
    check exitCode == 1
    check output.count("type mismatch") == 1
    check "broken_stringify.nim:4:" in output
    check "type `BeforeError` has no custom `$` overload" in output
    check "type `AfterError` has no custom `$` overload" in output
    check "type `IgnoredType` has no custom `$` overload" notin output
    check "hints: 0, errors: 4" in output

  test "Compiler diagnostics bypass suppression and requested lines":
    let (output, exitCode) =
      runLinter("--semantic --format=github src/skip2/broken_stringify.nim:7")
    check exitCode == 0
    check "warning:" in output
    check "type mismatch" in output
    check "broken_stringify.nim:4:" in output
    check "has no custom `$` overload" notin output
    check "::error" notin output

  removeLinterExecutable()
