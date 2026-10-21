import compiler/ast

import std/tables
import std/strformat

import pkg/toml_serialization
import pkg/chronicles
import pkg/chronos

import ../types

const statusAnalogs = {"parsecfg": "confutils", "asyncdispatch": "chronos"}.toTable()

proc run*(
    queue: AsyncQueue[Issue],
    filepath: string,
    ast: PNode,
    level: LogLevel,
    params: TomlTableRef,
) {.async.} =
  for node in ast.sons:
    if node.kind == nkImportStmt:
      let importedModule =
        if node.sons[0].kind == nkIdent:
          node.sons[0].ident.s
        elif node.sons[0].kind == nkInfix:
          node.sons[0].sons[2].ident.s
        else:
          ""

      if importedModule in statusAnalogs:
        let
          msg =
            &"Do not use {importedModule}. Use Status's analog instead: {statusAnalogs[importedModule]}."
          issue = Issue.init(level, "statuslibs", filepath, node.info, msg)

        await queue.put(issue)
