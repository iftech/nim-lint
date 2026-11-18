import std/[os, osproc, strutils, unittest]

const fixtures = currentSourcePath().parentDir / "semantic"

proc runLinter(executable, args: string): tuple[output: string, exitCode: int] =
  execCmdEx(quoteShell(executable) & " " & args, workingDir = fixtures)

suite "Semantic run options":
  let executable =
    getTempDir() / ("lint-semantic-dispatch-" & $getCurrentProcessId() & ExeExt)
  let (compiled, compileExit) = execCmdEx(
    quoteShell(findExe("nim")) & " c -d:release --hints:off --out:" &
      quoteShell(executable) & " linter.nim",
    workingDir = fixtures,
  )
  if compileExit != 0:
    echo compiled
    quit(compileExit)

  test "Semantic checks require explicit opt-in and warn once":
    let (output, exitCode) = runLinter(executable, "valid.nim")
    check exitCode == 0
    check "ordinary first" in output
    check "ordinary middle" in output
    check "typed call" notin output
    check "typed last" notin output
    check output.count("warning: semantic checks skipped") == 1
    check "semanticRule" in output
    check "pass --semantic" in output
    check "hints: 2, errors: 0" in output

  test "Ordinary and semantic checks retain declaration order and settings":
    let (output, exitCode) = runLinter(executable, "--semantic valid.nim")
    check exitCode == 1
    let
      first = output.find("ordinary first")
      typed = output.find("typed call")
      middle = output.find("ordinary middle")
      last = output.find("typed last")
    check first >= 0
    check first < typed
    check typed < middle
    check middle < last
    check output.count("typed call") == 2
    check "hints: 4, errors: 2" in output

  test "Excluded files are not analyzed and dependencies are not linted":
    let (output, exitCode) = runLinter(executable, "--semantic")
    check exitCode == 1
    check "excluded semantic input was analyzed" notin output
    check output.count("ordinary first") == 2
    check output.count("ordinary middle") == 1
    check output.count("typed call") == 2
    check "hints: 5, errors: 2" in output

  test "Explicit targets override global and step exclusions":
    let (output, exitCode) = runLinter(executable, "--semantic separate.nim")
    check exitCode == 1
    check output.count("ordinary first") == 1
    check output.count("typed call") == 1
    let (excludedOutput, excludedExit) =
      runLinter(executable, "--semantic no_analysis.nim")
    check excludedExit == 0
    check "excluded semantic input was analyzed" in excludedOutput

  test "Semantic findings use existing range and output handling":
    let (output, exitCode) =
      runLinter(executable, "--semantic --format=github valid.nim:11")
    check exitCode == 1
    check "::error file=" in output
    check ",line=11," in output
    check "typed call" in output
    check "ordinary first" notin output

  removeFile(executable)
