## Stock linter: import hygiene.
##
## Placeholder check: flags imports from a configurable deny list.

import compiler/ast

import ../types

type
  DenyListSettings* = object
    modules*: seq[string] ## Modules that must not be imported.

proc runNoDeniedImports(ast: PNode, settings: DenyListSettings): seq[Finding] =
  for node in ast.sons:
    if node.kind != nkImportStmt:
      continue
    for importNode in node.sons:
      if importNode.kind != nkIdent:
        continue
      let module = importNode.ident.s
      if module in settings.modules:
        result.add finding(node, "do not import `" & module & "`")

let imports* = newLinter("imports")

let noDeniedImports* = imports.check("noDeniedImports", runNoDeniedImports)
