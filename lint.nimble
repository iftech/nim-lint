# Package

version       = "0.1.0"
author        = "Constantine Molchanov"
description   = "Library for creating a linter for your Nim project."
license       = "MIT"
srcDir        = "src"


const testBinaries = "tests/teststructure tests/trun tests/tconfig_errors tests/typedconfig examples/lint"


# Dependencies

requires "nim >= 2.2.12"
requires "glob >= 0.11.3"


proc run(cmd: string) =
  echo "  " & cmd
  exec cmd


proc mustNotCompile(src: string) =
  ## Compiles `src` and fails the task if it succeeds.
  echo "  " & src & " (must not compile)"
  # The compiler's error output is expected here, so it is only shown when the
  # check itself fails.
  try:
    exec "nim c --hints:off --compileOnly " & src
  except OSError, CatchableError:
    echo "    ok: rejected as expected"
    return
  echo "    FAILED: " & src & " compiled, but it must not"
  quit(1)


task test, "Run the test suite and verify config mistakes fail to compile":
  run "nim c -r --hints:off tests/teststructure.nim"
  run "nim c -r --hints:off tests/trun.nim"
  mustNotCompile "tests/tconfig_errors.nim"
  echo "all tests passed"


task cleanBins, "Remove built test and example binaries":
  for bin in testBinaries.splitWhitespace:
    if fileExists(bin):
      try:
        exec "rm -f " & bin
        echo "removed " & bin
      except OSError, CatchableError:
        discard


task lintExample, "Build and run the example config":
  run "nim c --hints:off examples/lint.nim"
  # The example project has lint errors on purpose, so a non-zero exit is
  # expected and is not a task failure.
  echo "  examples/lint"
  try:
    exec "./examples/lint"
  except OSError, CatchableError:
    discard
