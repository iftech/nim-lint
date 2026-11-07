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

  removeLinterExecutable()

