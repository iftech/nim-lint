import std/[os, sequtils, strutils, unittest]

import compiler/[ast, lineinfos]

import lint/private/semanalysis

const fixtures = currentSourcePath().parentDir / "semantic"

proc calls(node: PNode): seq[PNode] =
  if node == nil:
    return
  if node.kind == nkCall and node[0].kind == nkSym and
      node[0].sym.name.s == "importedValue":
    result.add node
  for child in node:
    result.add calls(child)

suite "Semantic backend":
  test "Compiler configs and recursive imports resolve typed calls":
    let analyzed = analyzeFile(fixtures / "valid.nim")
    checkpoint $analyzed.diagnostics
    check not analyzed.diagnostics.anyIt(it.severity == lineinfos.Severity.Error)
    check analyzed.tree != nil
    let resolved = calls(analyzed.tree)
    require resolved.len == 2
    for call in resolved:
      check call.typ != nil
      check call.typ.kind == tyInt
      check call[0].sym.typ != nil
      check call[1].typ.kind == tyInt
    check resolved.mapIt(it[1].intVal) == @[123'i64, 456'i64]
    # The called procedure's body resolves a symbol from a transitive import.
    let body = resolved[0][0].sym.ast
    check body != nil
    proc hasLeafCall(node: PNode): bool =
      if node == nil:
        return false
      if node.kind == nkCall and node[0].kind == nkSym and
          node[0].sym.name.s == "leafValue":
        return node.typ != nil and node.typ.kind == tyInt
      for child in node:
        if hasLeafCall(child):
          return true
    check hasLeafCall(body)

  test "Partial tree retains valid calls before and after a type error":
    let analyzed = analyzeFile(fixtures / "broken.nim")
    check analyzed.tree != nil
    check analyzed.diagnostics.anyIt(
      it.severity == lineinfos.Severity.Error and "type mismatch" in it.message and
      it.file.endsWith("broken.nim") and it.line == 4 and it.col >= 0
    )
    let resolved = calls(analyzed.tree)
    check resolved.len == 2
    check resolved.mapIt(int(it.info.line)) == @[3, 5]
    for call in resolved:
      check call.typ.kind == tyInt

  test "Macro errors are reported without speculative compiler diagnostics":
    let analyzed = analyzeFile(fixtures / "macro_error.nim")
    let errors = analyzed.diagnostics.filterIt(it.severity == lineinfos.Severity.Error)
    checkpoint $errors
    check errors.len == 1
    check errors.anyIt("intentional semantic test error" in it.message)
    check calls(analyzed.tree).mapIt(int(it.info.line)) == @[4, 7]

  test "Missing input returns a diagnostic without a tree":
    let analyzed = analyzeFile(fixtures / "missing.nim")
    check analyzed.tree == nil
    check analyzed.diagnostics.anyIt(
      it.severity == lineinfos.Severity.Error and "cannot open file" in it.message
    )

  test "Entry points have independent configuration and retained state":
    let first = analyzeFile(fixtures / "valid.nim")
    let second = analyzeFile(fixtures / "separate.nim")
    checkpoint $second.diagnostics
    check not second.diagnostics.anyIt(it.severity == lineinfos.Severity.Error)
    check calls(second.tree).len == 1
    check calls(first.tree).len == 2
    check calls(first.tree)[0].typ.kind == tyInt
