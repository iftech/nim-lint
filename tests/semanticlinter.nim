import compiler/ast

import lint

type CallSettings* = object
  name*: string = "importedValue"

proc runIntCalls(
    source: string, ast, typed: PNode, settings: CallSettings
): seq[Finding] =
  var findings: seq[Finding]
  proc inspect(node: PNode) =
    if node.isNil:
      return
    if node.kind == nkProcDef and node[0].kind == nkSym and
        node[0].sym.name.s == "killSemanticCheck":
      raise newException(AssertionDefect, "semantic check failed")
    if node.kind == nkCall and node[0].kind == nkSym and
        node[0].sym.name.s == settings.name and not node.typ.isNil and
        node.typ.kind == tyInt:
      findings.add node.toFinding("integer call to " & settings.name)
    for child in node:
      inspect(child)

  inspect(typed)
  findings

let
  semanticLinter* = Linter()
  intCalls* = semanticLinter.addCheck(runIntCalls)
