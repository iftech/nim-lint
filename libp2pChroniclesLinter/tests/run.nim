import std/[os, osproc, strutils]

# Builds the example and checks its findings and exit code. `runLint` exits the
# process itself, so this has to shell out.
let tmp = getTempDir() / "chronicles_linter_test"
removeDir(tmp)
createDir(tmp)

let bin = tmp / "example"
doAssert execCmd(quoteShellCommand(["nim", "c", "--hints:off", "-o:" & bin, "examples/chronicles_lint.nim"])) == 0

let output = execCmdEx(quoteShell(bin))
echo output.output
doAssert output.exitCode == 1, "errors found should exit 1, got " & $output.exitCode
for expected in [
  "message must not end with a full stop",
  "message must contain one sentence",
  "bare field 'ab' is too short",
  "field 'c' is too short",
  "use `err` for exception text",
  "elevated log contains payload field `data`",
  "elevated log contains payload field `encoded`",
]:
  doAssert expected in output.output, "missing finding: " & expected
# Valid statements and ignored paths must stay quiet.
doAssert "clean.nim" notin output.output
doAssert "vendor/" notin output.output
# The unimplemented rule must not fire.
doAssert "shortLog" notin output.output
echo "run: ok"
