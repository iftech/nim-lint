## Ordinary checks for Lint's own coding conventions.
## `len` and call rules check spelling, not symbol resolution. Calls with trailing
## blocks are treated as DSLs; their contents are not checked for parentheses.
## Export documentation uses parser-retained `##` comments (not ordinary `#`).
## Object fields and enum members are not standalone exported declarations.

import std/strutils

import compiler/ast

import lint

type
  StyleSettings* = object ## Settings for rules without configurable exceptions.
  CallSettings* = object ## Names allowed to use command-style calls.
    exceptions*: seq[string] = @["inc", "dec"]

const routines = {
  nkProcDef, nkFuncDef, nkMethodDef, nkIteratorDef, nkConverterDef, nkTemplateDef,
  nkMacroDef,
}

proc spelling(node: PNode): string =
  case node.kind
  of nkIdent:
    node.ident.s
  of nkAccQuoted:
    var name: string
    for child in node:
      name.add(spelling(child))
    name
  of nkDotExpr, nkPostfix, nkPragmaExpr:
    spelling(node[if node.kind == nkPragmaExpr: 0 else: 1])
  else:
    ""

proc lastStatement(node: PNode): PNode =
  if node.kind in {nkStmtList, nkStmtListExpr}:
    for index in countdown(len(node) - 1, 0):
      if node[index].kind notin {nkEmpty, nkCommentStmt}:
        return lastStatement(node[index])
    nil
  else:
    node

proc runRedundantResult(
    source: string, ast: PNode, settings: StyleSettings
): seq[Finding] =
  var findings: seq[Finding]
  proc tail(node: PNode) =
    if node.isNil:
      return
    let last = lastStatement(node)
    if last.isNil:
      return
    if last.kind == nkAsgn and last[0].kind == nkIdent and last[0].ident.s == "result":
      findings.add(last[0].toFinding("return the final expression without `result =`"))
    elif last.kind in {nkIfStmt, nkIfExpr, nkCaseStmt}:
      for branch in last:
        if branch.kind in {nkElifBranch, nkElse, nkOfBranch, nkElifExpr, nkElseExpr}:
          tail(branch[^1])

  proc visit(node: PNode) =
    if node.kind in {nkProcDef, nkFuncDef, nkMethodDef, nkConverterDef}:
      tail(node[bodyPos])
    for child in node:
      visit(child)

  visit(ast)
  findings

proc runLenCalls(source: string, ast: PNode, settings: StyleSettings): seq[Finding] =
  var findings: seq[Finding]
  proc visit(node: PNode) =
    if node.kind == nkDotExpr and spelling(node[1]) == "len":
      findings.add(node.toFinding("use `len(x)` instead of dot-style `len`"))
    for child in node:
      visit(child)

  visit(ast)
  findings

proc runCallParentheses(
    source: string, ast: PNode, settings: CallSettings
): seq[Finding] =
  var findings: seq[Finding]
  proc visit(node: PNode) =
    # A trailing statement-list argument denotes block/DSL syntax, not a plain call.
    let blockCall =
      node.kind in {nkCall, nkCommand} and len(node) > 1 and node[^1].kind == nkStmtList
    if node.kind == nkCommand and not blockCall and
        spelling(node[0]) notin settings.exceptions:
      findings.add(node.toFinding(
        "use parentheses for the call to `" & spelling(node[0]) & "`"
      ))
    if node.kind in routines:
      # Parameter types can contain nkCommand nodes such as `static bool`.
      visit(node[bodyPos])
    elif not blockCall:
      for child in node:
        visit(child)

  visit(ast)
  findings

proc exported(node: PNode): bool =
  if node.kind == nkPragmaExpr:
    exported(node[0])
  else:
    node.kind == nkPostfix and spelling(node[0]) == "*"

proc documented(node: PNode): bool =
  if len(node.comment.strip()) > 0:
    return true
  case node.kind
  of nkTypeDef:
    return documented(node[2])
  of nkObjectTy, nkRefTy, nkPtrTy, nkDistinctTy, nkEnumTy:
    # Documentation may be attached to the type's opening record list.
    for child in node:
      if len(child.comment.strip()) > 0:
        return true
  of nkProcDef, nkFuncDef, nkMethodDef, nkIteratorDef, nkConverterDef, nkTemplateDef,
      nkMacroDef:
    let body = node[bodyPos]
    if body.kind in {nkStmtList, nkStmtListExpr}:
      for child in body:
        if child.kind == nkCommentStmt:
          if len(child.comment.strip()) > 0:
            return true
        elif child.kind != nkEmpty:
          break
  else:
    discard
  false

proc runExportDocs(source: string, ast: PNode, settings: StyleSettings): seq[Finding] =
  var findings: seq[Finding]
  proc declaration(node, name: PNode, leading: bool) =
    if exported(name) and not leading and not documented(node):
      findings.add(name.toFinding("exported `" & spelling(name) & "` needs a docstring"))

  proc visit(node: PNode, leading = false) =
    case node.kind
    of nkStmtList, nkStmtListExpr, nkTypeSection, nkVarSection, nkLetSection,
        nkConstSection:
      var previousDoc = leading
      for child in node:
        if child.kind == nkCommentStmt:
          previousDoc = len(child.comment.strip()) > 0
        else:
          visit(child, previousDoc)
          previousDoc = false
    of nkTypeDef:
      declaration(node, node[0], leading)
    of nkIdentDefs:
      for index in 0 ..< len(node) - 2:
        declaration(node, node[index], leading)
    of nkConstDef:
      declaration(node, node[0], leading)
    of nkProcDef, nkFuncDef, nkMethodDef, nkIteratorDef, nkConverterDef, nkTemplateDef,
        nkMacroDef:
      declaration(node, node[namePos], leading)
      visit(node[bodyPos])
    else:
      for child in node:
        visit(child)

  visit(ast)
  findings

let
  styleLinter* = Linter() ## Lint's project-local coding conventions.
  redundantResult* = styleLinter.addCheck(runRedundantResult)
    ## Prefer implicit final returns.
  lenCalls* = styleLinter.addCheck(runLenCalls) ## Prefer function-style length queries.
  callParentheses* = styleLinter.addCheck(runCallParentheses)
    ## Parenthesize ordinary calls.
  exportDocs* = styleLinter.addCheck(runExportDocs) ## Document exported declarations.
