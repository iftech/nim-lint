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

suite "Exit codes":
  compileLinter()

  test "Invalid source file":
    let (_, exitCode) = runLinter("src/skip2/invalid.nim")
    check exitCode == 2

  test "Missing source file":
    let (_, exitCode) = runLinter("src/skip2/missing.nim")
    check exitCode == 3

  test "Bug in check":
    let (_, exitCode) = runLinter("src/skip2/bug.nim")
    check exitCode == 4

  test "Non-CatchableError bug in check":
    let (_, exitCode) = runLinter("src/skip2/bug2.nim")
    check exitCode == 4

  test "Compiler diagnostics alone do not fail the run":
    let (output, exitCode) = runLinter("--semantic src/skip2/broken_stringify.nim:7")
    check exitCode == 0
    check "type mismatch" in output
    check "hints: 0, errors: 0" in output

  removeLinterExecutable()
