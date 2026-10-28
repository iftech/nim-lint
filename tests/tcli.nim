import std/[unittest]

import ../src/lint/cli

suite "argument parsing":
  test "a plain path is a target with no ranges":
    let t = parseTarget("src/foo.nim")
    check t.path == "src/foo.nim"
    check t.lines.len == 0

  test "a glob is a target":
    check parseTarget("src/module/*").path == "src/module/*"

  test "a single line":
    let t = parseTarget("src/foo.nim:10")
    check t.path == "src/foo.nim"
    check t.lines == @[(10, 10)]

  test "a line range":
    let t = parseTarget("src/foo.nim:10-12")
    check t.path == "src/foo.nim"
    check t.lines == @[(10, 12)]

  test "several ranges":
    let t = parseTarget("src/foo.nim:10-12,40")
    check t.lines == @[(10, 12), (40, 40)]

  test "a Windows path keeps its colon":
    let t = parseTarget(r"C:\src\foo.nim")
    check t.path == r"C:\src\foo.nim"
    check t.lines.len == 0

  test "a Windows path with ranges":
    let t = parseTarget(r"C:\src\foo.nim:3-4")
    check t.path == r"C:\src\foo.nim"
    check t.lines == @[(3, 4)]

  test "options are not targets":
    check parseOptions(@["--format=github", "src/foo.nim"]).targets.len == 1

  test "format defaults to text":
    check parseOptions(@["src/foo.nim"]).format == "text"

  test "format accepts =":
    check parseOptions(@["--format=github"]).format == "github"

  test "format accepts :":
    check parseOptions(@["--format:github"]).format == "github"

  test "options and targets mix in any order":
    let o = parseOptions(@["src/a.nim", "--format=github", "src/b.nim"])
    check o.format == "github"
    check o.targets.len == 2

  test "a Windows path survives option parsing":
    let o = parseOptions(@[r"C:\src\foo.nim:3-4"])
    check o.targets.len == 1
    check o.targets[0].path == r"C:\src\foo.nim"
    check o.targets[0].lines == @[(3, 4)]

suite "line ranges":
  test "an empty range list matches everything":
    check inRanges(42, @[])

  test "a line inside a range matches":
    check inRanges(11, @[(10, 12)])

  test "a line outside every range does not match":
    check not inRanges(13, @[(10, 12)])
    check not inRanges(9, @[(10, 12)])
