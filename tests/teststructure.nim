import std/[unittest]

import ../src/lint

# The config macro runs the whole pipeline on expansion, so a run is verified by
# `tests/trun.nim`. Compile-time guarantees (a misspelled settings key, an
# unknown check, an unknown config field) are verified by building
# `tests/tconfig_errors.nim`, which is expected to fail compilation.

suite "core types":
  test "findings carry position and message":
    let f = Finding(line: 3, col: 2, msg: "nope")
    check f.line == 3
    check f.col == 2
    check f.msg == "nope"
