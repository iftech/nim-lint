import std/[unittest, osproc, strutils]

const
  config = "linter.nim"
  testsDir = "tests"

proc runLinter(args = ""): tuple[output: string, exitCode: int] =
  let command = "nim r $# $#" % [config, args]
  execCmdEx(command, workingDir = testsDir)

suite "Lint tests":
  test "Lint a project using the config":
    const
      expectedOutput =
        """[Check naming][varNames][hint][src/main.nim:8:2] variable `a` is shorter than 3 characters
[Check naming][varNames][hint][src/main.nim:10:2] variable `b` is shorter than 3 characters
[Check naming][constNames][error][src/main.nim:4:2] constant `invalid` should start with `k`
hints: 2, errors: 1"""
      expectedExitCode = 1

    let (output, exitCode) = runLinter()

    check:
      exitCode == expectedExitCode
      expectedOutput in output

  test "Lint a single file":
    const
      expectedExitCode = 0
      expectedOutput =
        """[Check naming][varNames][hint][src/skip/skipped.nim:3:4] variable `y` is shorter than 3 characters
hints: 1, errors: 0"""

    let (output, exitCode) = runLinter("src/skip/skipped.nim")

    check:
      exitCode == expectedExitCode
      expectedOutput in output

  test "Lint multiple files":
    const
      expectedExitCode = 0
      expectedOutput =
        """[Check naming][varNames][hint][src/skip/skipped.nim:3:4] variable `y` is shorter than 3 characters
[Check naming][varNames][hint][src/skip/skipped2.nim:3:4] variable `z` is shorter than 3 characters
hints: 2, errors: 0"""

    let (output, exitCode) = runLinter("src/skip/skipped.nim src/skip/skipped2.nim")

    check:
      exitCode == expectedExitCode
      expectedOutput in output

  test "Lint files specified with a glob pattern":
    const
      expectedExitCode = 0
      expectedOutput =
        """[Check naming][varNames][hint][src/skip/skipped.nim:3:4] variable `y` is shorter than 3 characters
[Check naming][varNames][hint][src/skip/skipped2.nim:3:4] variable `z` is shorter than 3 characters
hints: 2, errors: 0"""

    block unquoted:
      let (output, exitCode) = runLinter("src/skip/*")

      check:
        exitCode == expectedExitCode
        expectedOutput in output

    block quoted:
      let (output, exitCode) = runLinter("'src/skip/*'")

      check:
        exitCode == expectedExitCode
        expectedOutput in output

