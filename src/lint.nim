import compiler/[ast, parser, idents, options]

import std/tables
import std/strutils
import std/strformat
import std/os

import pkg/confutils
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
    filePath: string, lintConfig: TomlTableRef, ast: PNode
): Future[seq[Finding]] {.async.} =
  let
    rules = {"typenames": typenames.run, "statuslibs": statuslibs.run}.toTable()
    queue = newAsyncQueue[Finding]()

  var ruleFutures = newSeq[Future[void]]()

  for rulename in lintConfig["rules"].arrayVal:
    let
      ruleRunner = rules[rulename.stringVal]
      ruleConfig = lintConfig[rulename.stringVal].tableVal
      severity = parseEnum[Severity](ruleConfig["severity"].stringVal)
      settings =
        if ruleConfig.hasKey("settings"):
          ruleConfig["settings"].tableVal
        else:
          TableRef[string, TomlValueRef]()

    ruleFutures.add(ruleRunner(queue, filePath, ast, severity, settings))

  await allFutures(ruleFutures)

  for finding in queue:
    result.add(finding)

proc checkLintVersion(lintConfig: TomlTableRef) =
  let requiredLintVersion = lintConfig["lint_version"].stringVal

  if requiredLintVersion != version:
    echo &"Warning! Lint version mismatch: current version is {version}, the required version is {requiredLintVersion}. Your rules may not behave the way you expect them to."

proc checkFile(filepath: string, lintConfig: TomlTableRef): Report =
  let
    src = readFile(filepath)
    identCache = newIdentCache()
    configRef = newPartialConfigRef()
    ast = parseString(src, identCache, configRef, filepath)
    findings = waitFor runRules(filepath, lintConfig, ast)

  Report.init(filepath, findings)

proc collectNimFiles(dir = "."): seq[string] =
  for file in walkDirRec(dir):
    if splitFile(file).ext == ".nim":
      result.add(file)

proc hasErrors(reports: openArray[Report]): bool =
  for report in reports:
    if report.hasErrors:
      return true

when isMainModule:
  let cli = Cli.load(version = version)

  let
    lintConfig = Toml.loadFile($cli.config, TomlValueRef).tableVal
    filepaths =
      if cli.file.isSome:
        @[$cli.file.value]
      else:
        collectNimFiles($cli.dir)

  checkLintVersion(lintConfig)

  var reports: seq[Report]

  for filepath in filepaths:
    reports.add(checkFile(filepath, lintConfig))

  for report in reports:
    echo report

  quit(int(reports.hasErrors))
