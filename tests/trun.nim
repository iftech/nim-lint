import std/[unittest, os, osproc, strutils]

const
  config = "linter.nim"
  linterExecutable = config.splitFile().name
  testsDir = currentSourcePath().parentDir

proc compileLinter() =
  let (output, exitCode) =
    execCmdEx("nim c -d:release $#" % config, workingDir = testsDir)
  if exitCode != 0:
    echo output
    quit(exitCode)

proc runLinter(targets = ""): tuple[output: string, exitCode: int] =
  let command = "$# $#" % [findExe(testsDir / linterExecutable), targets]
  execCmdEx(command, workingDir = testsDir)

proc removeLinterExecutable() =
  removeFile findExe(testsDir / linterExecutable)

suite "Run options":
  compileLinter()

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

  removeLinterExecutable()

