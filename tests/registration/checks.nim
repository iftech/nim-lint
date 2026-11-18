import compiler/ast
import lint

type Settings* = object
  minimum*: int
  names*: seq[string]

proc ordinary(source: string, ast: PNode, settings: Settings): seq[Finding] =
  discard

proc semantic(source: string, ast, typed: PNode, settings: Settings): seq[Finding] =
  discard

let
  linter = Linter()
  ordinaryRule* = linter.addCheck(ordinary)
  semanticRule* = linter.addCheck(semantic, Settings(minimum: 3, names: @["default"]))
