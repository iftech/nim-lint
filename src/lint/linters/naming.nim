## Stock linter: naming conventions.
##
## Placeholder checks: they compile, take typed settings, and produce findings,
## but the actual rules are deliberately naive.

import compiler/ast

import std/strutils

import ../types

type
  ConstNamesSettings* = object
    prefix*: string ## Expected prefix for constants. Empty by default.

  VarNamesSettings* = object
    minLength*: int ## Shortest acceptable variable name.
    maxLength*: int ## Longest acceptable variable name.

proc runConstNames(ast: PNode, settings: ConstNamesSettings): seq[Finding] =
  if settings.prefix.len == 0:
    return
  for node in ast.sons:
    if node.kind == nkConstSection:
      for def in node.sons:
        if def[0].kind != nkIdent:
          continue
        let name = def[0].ident.s
        if not name.startsWith(settings.prefix):
          result.add finding(node, "constant `" & name & "` should start with `" &
            settings.prefix & "`")

proc runVarNames(ast: PNode, settings: VarNamesSettings): seq[Finding] =
  for node in ast.sons:
    if node.kind == nkVarSection:
      for def in node.sons:
        if def[0].kind != nkIdent:
          continue
        let name = def[0].ident.s
        if settings.minLength > 0 and name.len < settings.minLength:
          result.add finding(
            node,
            "variable `" & name & "` is shorter than " & $settings.minLength &
              " characters",
          )
        if settings.maxLength > 0 and name.len > settings.maxLength:
          result.add finding(
            node,
            "variable `" & name & "` is longer than " & $settings.maxLength &
              " characters",
          )

let naming* = newLinter("naming")

let constNames* = naming.check("constNames", runConstNames)
let varNames* = naming.check("varNames", runVarNames)
