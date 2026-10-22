import compiler/ast

import std/tables
import std/strformat

import pkg/toml_serialization
import pkg/chronos

import ../types

proc run*(
    queue: AsyncQueue[Finding],
    filePath: string,
    ast: PNode,
    severity: Severity,
    settings: TomlTableRef,
) {.async.} =
  let
    minLength =
      if settings.hasKey("minLength"):
        settings["minLength"].intVal
      else:
        3
    maxLength =
      if settings.hasKey("maxLength"):
        settings["maxLength"].intVal
      else:
        20

  for node in ast.sons:
    if node.kind == nkTypeSection:
      for typeDef in node.sons:
        let typeName = typeDef.sons[0].ident.s

        if len(typeName) < minLength:
          let
            msg = &"Type names must be {minLength} or more chars long, but {typeName} is {len(typeName)} chars long."
            issue = Finding.init(severity, "type_names", filePath, node.info, msg)

          await queue.put(issue)

        if len(typeName) > maxLength:
          let
            msg = &"Type names must be {maxLength} or less chars long, but {typeName} is {len(typeName)} chars long."
            issue = Finding.init(severity, "type_names", filePath, node.info, msg)

          await queue.put(issue)
