import std/[unittest]

import ../src/lint/suppress

suite "per-line suppression":
  test "a line with the marker is suppressed":
    check isSuppressed("var ok = 1  #nolint")

  test "a line without the marker is not suppressed":
    check not isSuppressed("var ok = 1")

  test "the marker may follow other code":
    check isSuppressed("proc foo*( #nolint")

  test "a marker inside a string literal does not suppress":
    check not isSuppressed("""echo "#nolint"""")

  test "a marker after a string literal still suppresses":
    check isSuppressed("""echo "text"  #nolint""")

  test "the marker must be at the end of the line":
    check not isSuppressed("var ok = 1  #nolint because reasons")

  test "trailing whitespace after the marker is allowed":
    check isSuppressed("var ok = 1  #nolint   ")

  test "lookup by 1-based line number":
    let lines = @["var ok = 1  #nolint", "var x = 2"]
    check isSuppressed(lines, 1)
    check not isSuppressed(lines, 2)

  test "out-of-range lines are never suppressed":
    let lines = @["var ok = 1  #nolint"]
    check not isSuppressed(lines, 0)
    check not isSuppressed(lines, 2)
