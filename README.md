# Lint

## Glossary

_Lint_ is a library for building linters for Nim projects.

A project uses Lint by writing a _config file_ — a Nim source file that imports Lint and declares the linters to run and the checks to run in them. Compiling this file produces the project's lint executable, whose _CLI_ processes the command-line arguments. Lint itself ships no executable: it ships the library that the config file is compiled against. The config file is the only way to run Lint.

_Config file_ describes a _config_, which defines:

- which paths must be checked (the _sources_)
- which patterns must be ignored during the run
- which _steps_ must be run on each source file, in order
  - one linter can be invoked in many steps
- for each step, which patterns must be ignored for this step
- for each step, which _checks_ must be used when this step runs
- for each check, the _severity_ its _findings_ must be reported with: _error_ or _hint_
- for each check, the _settings_ it must be run with

Source paths, the config file, and ignored patterns are resolved relative to the current working directory (CWD). Ignored patterns declared on a step extend the top-level ones; they do not replace them.

The config file determines all the run aspects, the generated CLI does not accept any arguments or options. If you need to changes the run params, edit and recompile the config file.

_Linter_ is a sub-program that analyzes the abstract syntax tree (AST) of a single Nim file by running a set of _checks_ against its nodes.

_Check_ is a rule that a node can satisfy or not satisfy. If a node does not satisfy a check, the check returns a _finding_. A check has not side-effects: it reads the AST and its settings and returns findings. It does not know the file it is run against, the linter it belongs to, or the severity its findings are reported with.

_Settings_ are key-value pairs that a check can use during its execution to adjust its behavior. Each check defines its own settings.

_Step_ is one invocation of a linter with one set of checks and settings. Steps are declared in order in the config file and are run in that order. A linter may be used by more than one step — for example, to run the same checks strictly against the package sources and relaxed against its tests. Each step carries a _label_ that identifies it in the report. A label is for the reader, not an identifier: nothing is looked up by it, and two steps may share one. Steps are independent: each step receives the same AST and does not see other steps' results, so "step" denotes ordering, not a pipeline.

_Finding_ contains:

- the line at which the checked node is in the source file
- the column at which the checked node is in the source file
- a message explaining why the node does not satisfy the check

Findings produced by a check carry no severity, no linter label, and no file path. Those are attached by the runner when it collects findings.

_Severity_ is an enum that defines how findings are reported: as a _hint_ or as an _error_. Severity is declared in the config file per check, and is applied by the runner. A check cannot influence the severity of the findings it produces.

_Hints_ are purely informational; a run with only hints is still considered successful. _Errors_ indicate a failed run; a run with at least one error is considered failed.

_Step report_ is the outcome of one step run against one file: the findings that step produced for that file, stamped with severity, step label, and file path. A _file report_ collects the step reports of every step run against one file, in step order. A _run report_ collects the file reports of every checked file.

Ordering is deterministic: files are processed in ascending path order, and steps run in the order they are declared. Two runs of the same executable against the same sources produce the same run report.

## Execution Flow

1. The config file is compiled into the project's lint executable.
2. The executable starts. It takes no run parameters: everything the run needs is fixed at compile time.
3. The runner asks the source manager for the files to check.
4. The source manager walks the source paths, filters the files by extension and by the ignored patterns, and yields the matching files in ascending path order.
5. The runner parses each file into an AST exactly once. The AST is reused by every step run against that file.
6. For each file, the runner runs every step against the AST in the order the steps are declared.
7. For each step, the checks run in the order they are declared. Each check receives the AST and its settings and returns findings.
8. The runner stamps each finding with the step's label, the file path, and the severity declared for the check that produced it.
9. The runner assembles the file report and continues with the next file.
10. When all files are checked, the runner assembles the run report and presents it.

## Config File Example

The config file is a Nim program. A complete one looks like this:

```nim
import lint
import lint/linters/[naming, imports]   # or `import lint/linters` for all
import ./linters/libp2pLinter           # project-specific linters

runLint:
  sources = [".", "./src"]
  ignoredPatterns = ["./tests/**/*", "./vendor/**/*"]

  step "Check naming conventions":
    linter = naming
    ignoredPatterns = ["./src/submoduleWithUnconventionalNaming/**/*"]
    check constNames:
      severity = error
    check varNames:
      severity = hint
      settings:
        minLength = 5

  step "Check imports":
    linter = imports
    check noAsyncdispatch:
      severity = error
```

Reading it top to bottom: `sources` are the roots to walk, `ignoredPatterns` are the files to skip everywhere. Each `step` names a linter, may add its own ignores, and lists the checks to run. Each `check` states how its findings are reported and, if the check has settings, the values for this run.

`key = value` assigns a value; `key:` opens a block. That is why `severity =` and `settings:` differ by one character.

`settings:` values are checked against the settings type declared by the check, so a misspelled key is a compile error.

## Implementation

The config file is a Nim source file that imports Lint and declares a config. The library exposes the types and templates the config file needs:

- the `Linter` and `Check` types, and helpers for declaring them
- the templates for declaring a config: sources, ignored patterns, linter steps, checks with settings and severity
- the runner
- the CLI

The library does not expose:

- the report types beyond what a custom presenter needs
- any way to discover linters at runtime; the set of linters is fixed at compile time by what the config file imports

A check receives the parsed file as a `PNode` from Nim's own compiler AST module (`compiler/ast`). Lint neither converts the tree nor provides a tree type of its own: the node a check walks is exactly the node the parser produced. Writing a check therefore means importing `compiler/ast` and matching on node kinds, so a linter module depends on that module directly.

Compilation is the config's validation step for everything the type system can express: a misspelled linter or check name and a wrong settings type are compile errors.

## Typed Checks

By default a check reads a parse-only tree, where every variable is an identifier with no type. A check that needs to know a value's type must be declared with `requiresTyped = true`:

```nim
let typePrefix* = typedChecks.check(
  "typePrefix", runTypePrefix, TypePrefixSettings(prefix: ""), requiresTyped = true
)
```

When at least one configured check requires types, the runner semantically checks the project once — the way nimsuggest does — and hands checks the typed tree, where identifiers are `nkSym` nodes carrying `.sym` and `.sym.typ`. The project's own modules and everything they import are all available, so a typed check sees resolved types across module boundaries, not just within one file.

This costs far more than parsing. Measured on this machine with `command = "check"` (sem only, no codegen):

| Project | Parse-only | Typed | Typed peak RSS |
| --- | --- | --- | --- |
| 121 modules, 10k LOC | 4.7 ms | 195 ms | ~39 MB |
| nimbus-eth1, full binary | 0.22 s | ~2.5 min | 7.0 GB |
| nimbus-eth1, execution client only | — | 1m15s | 4.0 GB |

The fixed cost dominates small projects: roughly 130 ms plus 6 ms per 1000 LOC, almost all of it `system` and the standard library. Typed analysis is therefore opt-in per check, not a global mode, and it is only paid for when some check needs it.

If the project cannot be semantically checked, that is not a failed run. Typed checks are skipped and the run report says so:

```
skipped (needs typed analysis, project does not sem): Typed check/typePrefix
```

Syntax-only checks still run. A project with semantic errors may still produce partial typed trees, in which case typed checks run over what the compiler resolved and a warning reports the error count.

The compiler API used here (`registerPass`, `semPass`, `compileProject`) is what nimsuggest uses, but it is not a stability contract. It is confined to `src/lint/typed.nim`.

## Exit Modes

The run ends in exactly one of the following outcomes.

_Clean run_ — every file parsed, every step completed, and no finding carries the _error_ severity. The run report contains only hints, or is empty. The process exits with code 0.

_Errors found_ — every file parsed and every step completed, and at least one finding carries the _error_ severity. The process exits with a code that is non-zero and distinct from the codes below.

_Parse error_ — a source file could not be parsed, so no AST exists and no step can be run against it. The file report holds a single finding attributed to the runner (not to a step) describing the parse failure. A parse error always fails the run, regardless of configured severities, because no check was able to evaluate the file. Remaining files are still checked, so one unparseable file does not hide findings in the rest.

_Config error_ — the config file cannot be compiled, or the run parameters cannot be satisfied (an unknown source path or an unusable ignore pattern). This is reported before any file is read. The process exits with a code that is non-zero and distinct from the codes above.

_Check error_ — a check raised an exception. A check is library code, so an exception is a defect in the tool, not a property of the checked code. The run stops, the exception is reported with the step label, check name, and file path, and the process exits with a code that is non-zero and distinct from the codes above. Continuing past a raising check would report a file as checked when it was not.
