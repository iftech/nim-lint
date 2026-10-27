## Typed analysis: sem a project through the compiler pipeline and collect the
## typed AST of every module.
##
## A parse-only tree has no type information: every variable is an `nkIdent`.
## Running the compiler's semantic pass replaces identifiers with `nkSym` nodes
## that carry `.sym` and `.sym.typ`, which is what checks that need to know a
## value's type operate on.
##
## The approach is the one nimsuggest uses: register the compiler's own `semPass`
## together with a pass that records the sem'd nodes of each module, then drive
## the pipeline with `compileProject`. See `compiler/passes.nim` and
## `nimsuggest/nimsuggest.nim` in the Nim distribution.
##
## This module is the only place that touches these compiler internals. They are
## exported and used by nimsuggest, but are not a stability contract, so keep the
## dependency confined here.

import std/[algorithm, os, times, monotimes]

import compiler/[ast, idents, options, modulegraphs, passes, msgs, lineinfos,
                 pathutils, condsyms]

type
  TypedUnavailable* = object of CatchableError
    ## The project could not be semantically checked, so typed checks cannot
    ## run. The runner treats this as "fall back to syntax-only analysis", not
    ## as a failed run.

  ModuleTree* = object
    ## One module's typed AST.
    path*: string ## Absolute, normalized source path.
    tree*: PNode ## The module's sem'd statement list.

  TypedProject* = object
    ## The typed AST of every module in a project.
    modules*: seq[ModuleTree]
    errorCount*: int
    modulesSemd*: int ## Modules processed, including stdlib and imports.
    duration*: Duration

  Capture = ref object of TPassContext
    modulePath: string ## Absolute source path, "" when the module has none.
    builder: PNode ## The statement list accumulated for this module.

  TypedConfig* = object
    ## Everything needed to sem a project.
    projectFile*: string ## Entry point, relative to `searchPaths` or absolute.
    searchPaths*: seq[string] ## Where the project's own modules live.
    libPath*: string ## Nim's `lib` directory. Empty means "derive from the compiler".
    defines*: seq[string] ## `-d:` defines, without the `-d:` prefix.

proc normalizePath(path: string): string =
  result = path
  if not result.isAbsolute:
    result = getCurrentDir() / result
  result = result.normalizedPath

proc findLibPath(): string =
  ## The `lib` directory of the Nim distribution running this binary.
  let nimRoot = getCurrentCompilerExe().parentDir.parentDir
  for candidate in [nimRoot / "lib", nimRoot]:
    if fileExists(candidate / "system.nim"):
      return candidate
  ""

# Result accumulators. The compiler's pass hooks are plain procs without a
# user-data slot, so a single-threaded run collects through module state.
var
  gathered: seq[ModuleTree]
  modulesSemd: int

proc openModule(graph: ModuleGraph; m: PSym; idgen: IdGenerator): PPassContext =
  var path = ""
  if m != nil and m.position >= 0:
    try:
      path = normalizePath(toFullPath(graph.config, FileIndex(m.position)))
    except CatchableError:
      path = ""
  inc modulesSemd
  result = Capture(modulePath: path, builder: newNode(nkStmtList))

proc processStmt(c: PPassContext; n: PNode): PNode =
  ## Called by the pipeline for every top-level statement, after sem.
  result = n
  let capture = Capture(c)
  if n != nil and n.kind notin {nkNone .. nkNilLit}:
    capture.builder.add n

proc closeModule(graph: ModuleGraph; c: PPassContext; n: PNode): PNode =
  result = n
  let capture = Capture(c)
  if capture.builder.len > 0 and capture.modulePath.len > 0:
    gathered.add ModuleTree(path: capture.modulePath, tree: capture.builder)

proc compileTypedProject*(config: TypedConfig): TypedProject =
  ## Sems `config.projectFile` and every module it imports, and returns their
  ## typed ASTs.
  ##
  ## Raises `TypedUnavailable` when the project cannot be sems'd at all, for
  ## example when the entry point or the standard library cannot be found.
  let libPath = if config.libPath.len > 0: config.libPath else: findLibPath()
  if libPath.len == 0:
    raise newException(TypedUnavailable, "cannot locate Nim's lib directory")
  if not fileExists(libPath / "system.nim"):
    raise newException(
      TypedUnavailable, "no system.nim in " & libPath & ", cannot sem the project"
    )
  let projectFull = normalizePath(config.projectFile)
  if not fileExists(projectFull):
    raise newException(TypedUnavailable, "no such project file: " & projectFull)

  var conf = newConfigRef()
  conf.libpath = AbsoluteDir libPath
  conf.searchPaths.add AbsoluteDir libPath
  for p in config.searchPaths:
    conf.searchPaths.add AbsoluteDir p
  conf.projectFull = AbsoluteFile projectFull
  conf.projectPath = AbsoluteDir projectFull.parentDir
  conf.command = "check"
  # Report semantic errors instead of aborting the process: a project that does
  # not sem must degrade to syntax-only analysis, not kill the run.
  conf.ideCmd = ideChk
  # Warnings are noise here: the goal is the typed tree, not diagnostics.
  conf.writelnHook = proc(line: string) = discard
  initDefines conf.symbols
  for d in config.defines:
    defineSymbol(conf.symbols, d)

  let cache = newIdentCache()
  let graph = newModuleGraph(cache, conf)

  gathered.setLen(0)
  modulesSemd = 0

  graph.registerPass semPass
  graph.registerPass makePass(openModule, processStmt, closeModule)

  let start = getMonoTime()
  try:
    graph.compileProject()
  except CatchableError as e:
    raise (ref TypedUnavailable)(
      msg: "semantic analysis failed: " & e.msg
    )
  let duration = getMonoTime() - start

  var modules = gathered
  modules.sort(proc (a, b: ModuleTree): int = cmp(a.path, b.path))
  result.modules = modules
  result.errorCount = conf.errorCounter
  result.modulesSemd = modulesSemd
  result.duration = duration
