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

proc runLinter(args = ""): tuple[output: string, exitCode: int] =
  let command = "$# $#" % [findExe(testsDir / linterExecutable), args]
  execCmdEx(command, workingDir = testsDir)

suite "Lint tests":
  compileLinter()

  test "Lint a project using the config":
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

  test "Lint a single file":
    const
      finding = "variable `y` is shorter than 3 characters"
      summary = "hints: 1, errors: 0"

    let (output, exitCode) = runLinter("src/skip/skipped.nim")

    check exitCode == 0
    check finding in output
    check summary in output

  test "Lint multiple files":
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

  test "Lint files specified with a glob pattern":
    const
      findings = [
        "variable `y` is shorter than 3 characters",
        "variable `z` is shorter than 3 characters",
      ]
      summary = "hints: 2, errors: 0"

    block unquoted:
      let (output, exitCode) = runLinter("src/skip/*")

      check exitCode == 0

      for finding in findings:
        check finding in output
  
      check summary in output

    block quoted:
      let (output, exitCode) = runLinter("'src/skip/*'")

      check exitCode == 0

      for finding in findings:
        check finding in output

      check summary in output

  removeFile(testsDir / linterExecutable)

