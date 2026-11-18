import std/[os, osproc, strutils, unittest]

const fixture = currentSourcePath().parentDir / "registration" / "config.nim"

proc validate(define = ""): tuple[output: string, exitCode: int] =
  let flag =
    if define.len == 0:
      ""
    else:
      " -d:" & define
  execCmdEx(
    quoteShell(findExe("nim")) & " check --hints:off" & flag & " " & quoteShell(fixture)
  )

suite "Check registration":
  test "Mixed check declarations, defaults, overrides, and qualified names compile":
    let (output, exitCode) = validate()
    checkpoint output
    check exitCode == 0

  test "An ordinary check cannot be declared as semantic":
    let (output, exitCode) = validate("ordinaryAsSemantic")
    check exitCode != 0
    check "`semCheck` requires a SemCheck value" in output

  test "A semantic check cannot be declared as ordinary":
    let (output, exitCode) = validate("semanticAsOrdinary")
    check exitCode != 0
    check "`check` requires a Check value" in output

  test "Semantic settings reject unknown fields":
    let (output, exitCode) = validate("unknownSetting")
    check exitCode != 0
    check "missing" in output

  test "Semantic settings reject wrong value types":
    let (output, exitCode) = validate("wrongSettingType")
    check exitCode != 0
    check "type mismatch" in output
