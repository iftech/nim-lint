import std/[os, osproc, strutils]

# Runs the example config against the fixture project and checks the report and
# the exit code, since `runLint` exits the process itself.

const
  nilmp = "nim"
  example = "examples/linter.nim"

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

# Command-line arguments override the config's sources and top-level ignores.
let explicit = execCmdEx(quoteShell(bin) & " tests/testproject/tests/ttest.nim")
doAssert explicit.exitCode == 0, "hints only should exit 0"
doAssert "ttest.nim" in explicit.output,
  "an explicit file must be linted even though the config ignores it"

# An explicit target overrides step-level ignores too: naming a file is a
# request to lint it.
let stepIgnored = execCmdEx(quoteShell(bin) & " tests/testproject/src/skip/skipped.nim")
doAssert "skipped.nim" in stepIgnored.output,
  "an explicit file must be linted even though a step ignores it"

# Line ranges filter findings by position.
let ranged = execCmdEx(quoteShell(bin) & " tests/testproject/src/main.nim:6")
doAssert "variable `ok`" in ranged.output
doAssert "constant `answer`" notin ranged.output,
  "findings outside the requested range must be dropped"

# Several ranges in one argument.
let multi = execCmdEx(quoteShell(bin) & " tests/testproject/src/main.nim:1-2,6")
doAssert "variable `ok`" in multi.output, "line 6 is in the second range"
doAssert "constant `answer`" notin multi.output, "line 3 is in no range"

# GitHub format emits workflow commands and no summary line.
let gh = execCmdEx(quoteShell(bin) & " --format=github tests/testproject/src/main.nim")
doAssert "::error file=tests/testproject/src/main.nim,line=3" in gh.output
doAssert "hints:" notin gh.output

echo "trun: ok"
