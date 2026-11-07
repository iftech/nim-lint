import std/strutils

import compiler/ast

import lint

type
  VarNamesSettings* = object
    minLength*: int = 3
    maxLength*: int = 12

  ConstNamesSettings* = object
    prefix*: string = "k"

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
          result.add finding(
            def[0],
            "variable `" & name & "` is shorter than " & $s.minLength & " characters",
          )
        elif name.len > s.maxLength:
          result.add finding(
            def[0],
            "variable `" & name & "` is longer than " & $s.maxLength & " characters",
          )

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
          result.add finding(
            def[0], "constant `" & name & "` should start with `" & s.prefix & "`"
          )

let
  nameLinter* = newLinter("nameLinter")
  varNames* = nameLinter.check("varNames", runVarNames)
  constNames* = nameLinter.check("constNames", runConstNames)

