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

  removeLinterExecutable()
