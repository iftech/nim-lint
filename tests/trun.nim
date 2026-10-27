import std/[os, osproc, strutils]

# Runs the example config against the fixture project and checks the report and
# the exit code, since `runLint` exits the process itself.

const
  nilmp = "nim"
  example = "examples/lint.nim"

proc build(outFile: string, src: string) =
  let cmd = quoteShellCommand(["nim", "c", "--hints:off", "--nimcache:" & outFile & "_cache", "-o:" & outFile, src])
  doAssert execCmd(cmd) == 0, "failed to build " & src

let tmp = getTempDir() / "lint_trun"
proc runExample(src: string): tuple[output: string, exitCode: int] =
  let bin = tmp / splitFile(src).name
  doAssert execCmd(quoteShellCommand([
    "nim", "c", "--hints:off", "--nimcache:" & bin & "_cache", "-o:" & bin, src
  ])) == 0, "failed to build " & src
  execCmdEx(quoteShell(bin))

removeDir(tmp)
createDir(tmp)

let bin = tmp / "example"
build(bin, example)

let output = execCmdEx(quoteShell(bin))
echo output.output
doAssert output.exitCode == 1, "errors found should exit with 1, got " & $output.exitCode
doAssert "constant `answer` should start with `k`" in output.output
doAssert "src/main.nim" in output.output
# global ignores
doAssert "ttest.nim" notin output.output
# step ignores
doAssert "skipped.nim" notin output.output

# Typed checks run when the project sems. `typePrefix` needs resolved type
# names, so this also proves the typed pipeline produces `nkSym` nodes.
let typed = runExample("tests/typedconfig.nim")
echo typed.output
doAssert typed.exitCode == 1, "typed errors found should exit 1"
doAssert "type `BadWidget` should start with `Good`" in typed.output
# The typed tree covers imported modules, not just the entry point.
doAssert "types.nim" in typed.output
# A well-prefixed type must not be reported.
doAssert "GoodWidget" notin typed.output

echo "trun: ok"
