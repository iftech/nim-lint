import compiler/ast

import std/tables
import std/strformat

import pkg/toml_serialization
import pkg/chronos

import ../types

const statusAnalogs = {"parsecfg": "confutils", "asyncdispatch": "chronos"}.toTable()

proc run*(
    queue: AsyncQueue[Finding],
    filepath: string,
    ast: PNode,
    severity: Severity,
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
          msg = &"Do not use {importedModule}. Use Status's analog instead: {statusAnalogs[importedModule]}."
          finding = Finding.init(severity, "statuslibs", filepath, node.info, msg)

        await queue.put(finding)
