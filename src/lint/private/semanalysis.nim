# lint
# Copyright 2025-2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

## Per-file semantic analysis. Each result owns an independent compiler context.

import std/os

import
  compiler/[
    ast, commands, condsyms, extccomp, idents, lineinfos, modulegraphs, msgs, nimconf,
    options, pipelines,
  ]

type
  SemDiagnostic* = object
    ## A compiler warning or error from configuration loading or semantic analysis,
    ## or a backend error such as an unreadable input file. Not a lint finding:
    ## severity is the compiler's classification, independent of check settings.
    ## The location refers to the compiler-reported file, which may be a dependency;
    ## file is empty when no location is available.
    file*: string
    line*, col*: int
    message*: string
    severity*: lineinfos.Severity

  SemResult* = ref object ## Retained compiler context and best-effort typed tree.
    ## The outcome of analyzing one entry file and its import dependencies.
    ## Retains compiler state so the tree's symbols and types remain usable.
    ## Diagnostics do not imply the tree is absent: it may be partial after errors,
    ## or nil when analysis could not produce a tree.
    tree*: PNode
    diagnostics*: seq[SemDiagnostic]
    graph: ModuleGraph # Keep symbols, types, and compiler state alive with the tree.

proc analyzeFile*(path: string): SemResult =
  ## Analyzes an entry file with Nim's configuration and recursive imports.
  ## Returns diagnostics and any retained typed tree, including partial results.

  if not fileExists(path):
    return SemResult(
      diagnostics: @[
        SemDiagnostic(
          file: absolutePath(path),
          message: "cannot open file: " & path,
          severity: lineinfos.Severity.Error,
        )
      ]
    )

  let
    conf = newConfigRef()
    cache = newIdentCache()
    graph = newModuleGraph(cache, conf)

  result = SemResult(graph: graph)

  initDefines(conf.symbols)
  conf.setCommandEarly("check")
  conf.setFromProjectName(absolutePath(path))
  conf.setErrorMaxHighMaybe()
  conf.hintProcessingDots = false
  conf.writelnHook = proc(output: string) {.gcsafe.} =
    discard

  var diagnostics: seq[SemDiagnostic]
  conf.structuredErrorHook = proc(
      config: ConfigRef, info: TLineInfo, message: string, severity: lineinfos.Severity
  ) {.gcsafe.} =
    # `compiles(...)` probes deliberately silence diagnostics while testing code.
    if config.m.errorOutputs != {} and
        severity in {lineinfos.Severity.Error, lineinfos.Severity.Warning}:
      diagnostics.add(SemDiagnostic(
        file: (
          if info.fileIndex == InvalidFileIdx: ""
          else: config.toFullPath(info.fileIndex)
        ),
        line: int(info.line),
        col: int(info.col),
        message: message,
        severity: severity,
      ))

  try:
    loadConfigs(DefaultConfig, cache, conf, graph.idgen)
    if conf.backend == backendJs:
      diagnostics.add(SemDiagnostic(
        file: absolutePath(path),
        message: "JavaScript backend is not supported for semantic analysis",
        severity: lineinfos.Severity.Error,
      ))
      result.diagnostics = diagnostics
      return

    extccomp.initVars(conf)

    if conf.backend == backendInvalid:
      conf.backend = backendC
    if conf.selectedGC == gcUnselected:
      initOrcDefines(conf)

    defineSymbol(conf.symbols, $conf.backend)
    defineSymbol(conf.symbols, "nimcheck")

    conf.searchPaths.add(conf.libpath)

    # IDE mode retains typed statements and recovers from semantic errors.
    when compiles(conf.ideActive):
      conf.setCmd(cmdCheck)
      conf.ideActive = true
    else:
      conf.setCmd(cmdIdeTools)

    setPipeLinePass(graph, SemPass)
    compilePipelineProject(graph)

  except Exception as error:
    diagnostics.add(SemDiagnostic(
      message: "compiler analysis failed: " & error.msg,
      severity: lineinfos.Severity.Error,
    ))
    result.diagnostics = diagnostics
    return

  let module = graph.getModule(conf.projectMainIdx)
  if not module.isNil:
    result.tree = module.ast
  result.diagnostics = diagnostics
