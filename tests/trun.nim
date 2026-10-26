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

echo "trun: ok"
