import compiler/[ast, parser, idents, options]

import std/tables
import std/strformat
import std/os

import pkg/confutils
import pkg/chronicles
import pkg/chronos
import pkg/toml_serialization

import ./rules/[typenames, statuslibs]
import ./types

const
  version = "1.0.0"
  defaultConfigFile = "lint.toml"

type Cli = object
  config {.abbr: "c", defaultValue: defaultConfigFile.}: InputFile
  file {.argument.}: Opt[InputFile]
  dir {.abbr: "d", defaultValue: ".".}: InputDir

proc runRules(
    filepath: string, lintCfg: string, ast: PNode, rulenames: seq[string]
) {.async: (raises: [Exception]).} =
  let
    rules = {"typenames": typenames.run, "statuslibs": statuslibs.run}.toTable()
    queue = newAsyncQueue[Issue]()

  var ruleFutures = newSeq[Future[void]]()

  for rulename in rulenames:
    let
      level = Toml.loadFile(lintCfg, LogLevel, rulename & ".level")
      params =
        try:
          Toml.loadFile(lintCfg, TomlValueRef, rulename & ".params")
        except TomlError:
          TomlValueRef(kind: TomlKind.Table, tableVal: newTable[string, TomlValueRef]())

    ruleFutures.add(rules[rulename](queue, filepath, ast, level, params.tableVal))

  await allFutures(ruleFutures)

  for issue in queue:
    echo &"\t{issue}"

proc checkLintVersion(lintCfg: string) =
  let requiredLintVersion = Toml.loadFile(lintCfg, string, "lint_version")

  if requiredLintVersion != version:
    echo &"Warning! Lint version mismatch: current version is {version}, the required version is {requiredLintVersion}. Your rules may not behave the way you expect them to."

proc checkFile(filepath: string, lintCfg: string) =
  let
    rulenames = Toml.loadFile(lintCfg, seq[string], "rules")
    src = readFile(filepath)
    identCache = newIdentCache()
    configRef = newPartialConfigRef()
    ast = parseString(src, identCache, configRef, filepath)

  echo &"Checking file {filepath}"
  waitFor runRules(filepath, lintCfg, ast, rulenames)
  echo &"Done checking {filepath}."

proc collectNimFiles(dir = "."): seq[string] =
  for file in walkDirRec(dir):
    if splitFile(file).ext == ".nim":
      result.add(file)

when isMainModule:
  let cli = Cli.load(version = version)

  let
    lintCfg = $cli.config
    filepaths =
      if cli.file.isSome:
        @[$cli.file.value]
      else:
        collectNimFiles($cli.dir)

  checkLintVersion(lintCfg)

  for filepath in filepaths:
    checkFile(filepath, lintCfg)
