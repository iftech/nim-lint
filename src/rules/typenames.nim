import compiler/ast

import std/tables
import std/strformat

import pkg/toml_serialization
import pkg/chronos

import ../types

proc run*(
    queue: AsyncQueue[Finding],
    filepath: string,
    ast: PNode,
    severity: Severity,
    params: TomlTableRef,
) {.async.} =
  let
    minLength =
      if params.hasKey("minLength"):
        params["minLength"].intVal
      else:
        3
    maxLength =
      if params.hasKey("maxLength"):
        params["maxLength"].intVal
      else:
        20

  for node in ast.sons:
    if node.kind == nkTypeSection:
      for typeDef in node.sons:
        let typeName = typeDef.sons[0].ident.s

        if len(typeName) < minLength:
          let
            msg = &"Type names must me {minLength} or more chars long, but {typeName} is {len(typeName)} chars long."
            issue = Finding.init(severity, "typenames", filepath, node.info, msg)

          await queue.put(issue)

        if len(typeName) > maxLength:
          let
            msg = &"Type names must me {maxLength} or less chars long, but {typeName} is {len(typeName)} chars long."
            issue = Finding.init(severity, "typenames", filepath, node.info, msg)

          await queue.put(issue)
