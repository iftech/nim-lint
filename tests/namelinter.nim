import std/strutils

import compiler/ast

import lint

#ANCHOR: settings
type
  VarNamesSettings* = object
    minLength*: int = 3
    maxLength*: int = 12

  ConstNamesSettings* = object
    prefix*: string = "k"
#ANCHOR_END: settings

proc runVarNames(ast: PNode, s: VarNamesSettings): seq[Finding] =
  for node in ast.sons:
    if node.kind == nkVarSection:
      for def in node.sons:
        if def[0].kind != nkIdent:
          continue
        let name = def[0].ident.s

        if name == "killTheLinter":
          raise newException(ValueError, "There is a bug in this check")

        if name.len < s.minLength:
          result.add def[0].toFinding(
            "variable `" & name & "` is shorter than " & $s.minLength & " characters"
          )
        elif name.len > s.maxLength:
          result.add def[0].toFinding(
            "variable `" & name & "` is longer than " & $s.maxLength & " characters"
          )

#ANCHOR: runConstNames
proc runConstNames(ast: PNode, s: ConstNamesSettings): seq[Finding] =
  if s.prefix.len == 0:
    return
  for node in ast.sons:
    if node.kind == nkConstSection:
      for def in node.sons:
        if def[0].kind != nkIdent:
          continue
        let name = def[0].ident.s
        if not name.startsWith(s.prefix):
          result.add def[0].toFinding(
            "constant `" & name & "` should start with `" & s.prefix & "`"
          )
#ANCHOR_END: runConstNames

let
  nameLinter* = Linter()
  varNames* = nameLinter.addCheck(runVarNames)
  constNames* = nameLinter.addCheck(runConstNames)

