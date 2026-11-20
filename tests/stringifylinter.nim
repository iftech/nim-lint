## Require an intentional string representation for module-level object and
## distinct types. A generic `$` fallback does not satisfy this rule.
## This small example checks non-generic types and non-generic proc/func overloads
## declared in the same module: one parameter of the exact type, returning string.

import compiler/[ast, types]

import lint

type StringifySettings* = object

proc runCustomDollar(
    source: string, ast, typed: PNode, settings: StringifySettings
): seq[Finding] =
  var
    declarations: seq[PNode]
    overloads: seq[PType]

  proc collect(node: PNode) =
    if node.isNil:
      return
    case node.kind
    of nkStmtList:
      for child in node:
        collect(child)
    of nkTypeSection:
      for definition in node:
        if definition.kind == nkTypeDef and definition[1].kind == nkEmpty:
          let name =
            if definition[0].kind == nkPostfix:
              definition[0][1]
            else:
              definition[0]
          if name.kind == nkSym:
            let typ = name.sym.typ
            if not typ.isNil and typ.kind in {tyObject, tyDistinct} and
                typ.sym == name.sym:
              declarations.add name
    of nkProcDef, nkFuncDef:
      let name = node[namePos]
      if name.kind == nkSym and name.sym.name.s == "$" and
          node[genericParamsPos].kind == nkEmpty:
        let signature = name.sym.typ
        if not signature.isNil and signature.len == 2 and not signature[0].isNil and
            signature[0].kind == tyString:
          overloads.add signature[1]
    else:
      discard

  collect(typed)
  for declaration in declarations:
    var hasCustomDollar = false
    for parameter in overloads:
      if not parameter.isNil and sameType(declaration.sym.typ, parameter):
        hasCustomDollar = true
        break
    if not hasCustomDollar:
      result.add declaration.toFinding(
        "type `" & declaration.sym.name.s & "` has no custom `$` overload"
      )

let
  stringifyLinter* = Linter()
  customDollar* = stringifyLinter.addCheck(runCustomDollar)
