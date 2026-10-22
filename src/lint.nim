import compiler/[ast, parser, idents, options]

import std/tables
import std/strutils
import std/strformat
import std/os

import pkg/confutils
import pkg/toml_serialization

import ./types
import ./rules/typeNames
import ./rules/statusLibs

const
  version = "1.0.0"
  defaultConfigFile = "lint.toml"
  rules = {"typeNames": typeNames.analyze, "statusLibs": statusLibs.analyze}.toTable()

type Cli = object
  config {.abbr: "c", defaultValue: defaultConfigFile.}: InputFile
  file {.argument.}: Opt[InputFile]
  dir {.abbr: "d", defaultValue: ".".}: InputDir

proc runRules(filePath: string, lintConfig: TomlTableRef, ast: PNode): seq[Finding] =
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

    result &= ruleRunner(ast, filePath, severity, settings)

proc checkLintVersion(lintConfig: TomlTableRef) =
  let requiredLintVersion = lintConfig["lintVersion"].stringVal

  if requiredLintVersion != version:
    echo &"Warning! Lint version mismatch: current version is {version}, the required version is {requiredLintVersion}. Your rules may not behave the way you expect them to."

proc checkFile(filePath: string, lintConfig: TomlTableRef): Report =
  let
    src = readFile(filePath)
    identCache = newIdentCache()
    configRef = newPartialConfigRef()
    ast = parseString(src, identCache, configRef, filePath)
    findings = runRules(filePath, lintConfig, ast)

  Report.init(filePath, findings)

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
