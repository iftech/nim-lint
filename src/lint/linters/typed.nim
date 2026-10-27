## Stock linter: checks that need resolved types.
##
## These run only when the project can be semantically checked, because a
## parse-only tree has no types to inspect. The runner reports them as skipped
## when that is not the case.

import std/[sets, strutils]

import compiler/ast

import ../types

type
  TypePrefixSettings* = object
    prefix*: string ## Required prefix for every checked type.
    suffixes*: seq[string] ## Only check type names ending with these.

proc typeName(t: PType): string =
  ## A stable, human-readable name for a type. Falls back to the type kind when
  ## the type has no symbol (anonymous objects, tuples).
  if t == nil:
    return ""
  if t.sym != nil:
    return t.sym.name.s
  $t.kind

const builtinTypeNames = [
  "int", "int8", "int16", "int32", "int64", "uint", "uint8", "uint16",
  "uint32", "uint64", "float", "float32", "float64", "bool", "char", "string",
  "cstring", "pointer", "seq", "array", "set", "openArray", "varargs",
]

proc runTypePrefix(ast: PNode, s: TypePrefixSettings): seq[Finding] =
  ## Flag named types whose resolved name does not start with `prefix`.
  ##
  ## Requires a typed tree: names come from type symbols, which only exist after
  ## sem.
  if s.prefix.len == 0:
    return

  var
    seen = initHashSet[string]()
    findings: seq[Finding]

  proc visit(n: PNode) =
    if n == nil:
      return
    if n.kind == nkSym and n.sym.kind == skType and n.sym.typ != nil and
        n.sym.typ.sym != nil:
      let name = typeName(n.sym.typ)
      if name.len > 0 and name notin builtinTypeNames and not seen.contains(name):
        seen.incl name
        var relevant = s.suffixes.len == 0
        for suffix in s.suffixes:
          if name.endsWith(suffix):
            relevant = true
        if relevant and not name.startsWith(s.prefix):
          findings.add finding(
            n, "type `" & name & "` should start with `" & s.prefix & "`"
          )
    if n.kind in {nkNone .. nkNilLit}:
      return
    for child in n.sons:
      visit(child)

  visit(ast)
  result = findings

let typedChecks* = newLinter("typed")

let typePrefix* = typedChecks.check(
  "typePrefix",
  runTypePrefix,
  TypePrefixSettings(prefix: ""),
  requiresTyped = true,
)
