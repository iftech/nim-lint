import std/strutils

import compiler/ast

import lint

type TodoSettings* = object
  marker*: string = "TODO"

proc runTodoComments(source: string, ast: PNode, s: TodoSettings): seq[Finding] =
  let lines = source.splitLines()
  for index, line in lines:
    if line.strip().startsWith("#"):
      let column = line.find(s.marker)
      if column >= 0:
        result.add Finding(
          line: index + 1, col: column, msg: "unfinished comment: " & s.marker
        )

let
  commentLinter* = Linter()
  todoComments* = commentLinter.addCheck(runTodoComments)
