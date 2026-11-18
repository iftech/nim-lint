import std/strutils

import compiler/ast

import lint

type Settings* = object
  message*: string = "typed call"

proc ordinary(source: string, ast: PNode, settings: Settings): seq[Finding] =
  doAssert source.startsWith("import helper") or source.startsWith("{.error:")
  doAssert not ast.isNil
  # Semantic analysis must not replace or mutate the parsed tree.
  for section in ast:
    if section.kind == nkLetSection:
      for definition in section:
        let name = definition[0]
        doAssert name.kind == nkIdent or
          (name.kind == nkPostfix and name[1].kind == nkIdent)
  @[Finding(line: 1, col: 0, msg: settings.message)]

proc semantic(source: string, ast, typed: PNode, settings: Settings): seq[Finding] =
  doAssert source.len > 0
  doAssert not ast.isNil
  var findings: seq[Finding]
  proc inspect(node: PNode) =
    if node.isNil:
      return
    if node.kind == nkCall and node[0].kind == nkSym and
        node[0].sym.name.s == "importedValue":
      doAssert node.typ.kind == tyInt
      findings.add node.toFinding(settings.message)
    for child in node:
      inspect(child)

  inspect(typed)
  findings

let
  linter = Linter()
  ordinaryRule* = linter.addCheck(ordinary)
  semanticRule* = linter.addCheck(semantic)
