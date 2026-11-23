# lint
# Copyright 2025-2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

## Per-file semantic analysis. Each result owns an independent compiler context.

import std/[json, os, osproc]

# Compile the stdlib VM callbacks used by configuration scripts and macros.
{.define: nimcore.}

import
  compiler/[
    ast, commands, condsyms, extccomp, idents, lineinfos, modulegraphs, msgs, nimconf,
    options, pathutils, pipelines,
  ]

type
  SemDiagnostic* = object
    ## A compiler error from configuration loading or semantic analysis,
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

proc analyzeFile*(
    path: string,
    onDiagnostic: proc(diagnostic: SemDiagnostic) {.closure, gcsafe.} = nil,
): SemResult =
  ## Analyzes an entry file with Nim's configuration and recursive imports.
  ## Returns diagnostics and any retained typed tree, including partial results.
  ## Calls `onDiagnostic` as errors arrive, before any direct compiler termination.

  var diagnostics: seq[SemDiagnostic]
  proc recordDiagnostic(diagnostic: SemDiagnostic) {.gcsafe.} =
    diagnostics.add(diagnostic)
    if not onDiagnostic.isNil:
      onDiagnostic(diagnostic)

  if not fileExists(path):
    recordDiagnostic(SemDiagnostic(
      file: absolutePath(path),
      message: "cannot open file: " & path,
      severity: lineinfos.Severity.Error,
    ))
    return SemResult(diagnostics: diagnostics)

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

  conf.structuredErrorHook = proc(
      config: ConfigRef, info: TLineInfo, message: string, severity: lineinfos.Severity
  ) {.gcsafe.} =
    # `compiles(...)` probes deliberately silence diagnostics while testing code.
    if config.m.errorOutputs != {} and severity == lineinfos.Severity.Error:
      let diagnostic = SemDiagnostic(
        file: (
          if info.fileIndex == InvalidFileIdx: ""
          else: config.toFullPath(info.fileIndex)
        ),
        line: int(info.line),
        col: int(info.col),
        message: message,
        severity: severity,
      )
      recordDiagnostic(diagnostic)

  try:
    # Ask Nim itself: deriving its prefix from this executable breaks `$nim`,
    # while deriving it from a PATH entry assumes an installation layout.
    let nimExecutable = findExe("nim")
    if len(nimExecutable) == 0:
      raise newException(IOError, "cannot find nim on PATH")
    let (output, exitCode) = execCmdEx(
      quoteShell(nimExecutable) & " dump --dump.format:json --hints:off" &
      " --skipCfg --skipUserCfg --skipParentCfg --skipProjCfg ."
    )
    if exitCode != 0:
      raise newException(IOError, "cannot query Nim installation: " & output)
    let installation = parseJson(output)
    conf.prefixDir = AbsoluteDir(installation["prefixdir"].getStr())
    conf.libpath = AbsoluteDir(installation["libpath"].getStr())

    loadConfigs(DefaultConfig, cache, conf, graph.idgen)
    if conf.backend == backendJs:
      recordDiagnostic(SemDiagnostic(
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
    recordDiagnostic(SemDiagnostic(
      message: "compiler analysis failed: " & error.msg,
      severity: lineinfos.Severity.Error,
    ))
    result.diagnostics = diagnostics
    return

  let module = graph.getModule(conf.projectMainIdx)
  if not module.isNil:
    result.tree = module.ast
  result.diagnostics = diagnostics
