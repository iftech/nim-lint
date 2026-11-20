.. title:: Architecture Overview

.. importdoc:: cli.md

This page describes the concepts Lint is built from and how a run proceeds. It is meant for anyone writing a linter or working on Lint itself; if you only want to use Lint, [Config File](./config.html) is the place to begin.

# Concepts

## Lint

*Lint* is a library for building linters for Nim projects.

A project uses Lint by writing a *config file* — a Nim source file that imports Lint and the linters it needs, and declares the checks to run. Compiling this file produces the project's lint executable. Lint itself ships no executable: it ships the library that the config file is compiled against.

## Config file

The *config file* describes a *config*, which defines:

- which paths are checked (the *sources*)
- which patterns are ignored during the run
- which *steps* run on each source file, in order
- for each step, which additional patterns are ignored
- for each step, which *checks* run
- for each check, the *severity* its *findings* are reported with: *error* or *hint*
- for each check, the *settings* it runs with

Source paths and ignored patterns are resolved relative to the current working directory (CWD). Ignored patterns declared on a step extend the top-level ones; they do not replace them.

The executable accepts optional positional arguments that override `sources` and every `ignoredPatterns`, including step-level ones, for that run. Each argument is a file path, a directory, a glob pattern, or a file path followed by line ranges. With no targets, the config's sources are used.

The config declares which checks are available. The command line determines whether semantic checks participate in this invocation; declaring a semantic check does not itself enable semantic analysis.

## Linter

A *linter* is a group of checks provided by a Nim module. A config imports the linters it needs and selects their checks. One linter's checks may be used in many steps, and a step may combine checks from different linters.

## Check

A *check* is a rule evaluated against one file. It reads the supplied representations of that file and its settings, and returns zero or more *findings*.

Checks do not modify their inputs or depend on other checks' results. They are not supplied with reporting metadata such as the step label or configured severity. File attribution and reporting are the runner's responsibility.

### Check inputs

Lint uses three representations of a file:

| Input | Purpose | Examples |
| ----- | ------- | -------- |
| Source text | Examine the file exactly as written, including comments, whitespace, and line endings | TODO comments, trailing whitespace, blank lines |
| Parsed AST | Examine syntax without resolving its meaning | Distinguish `foo(123)` from `123.foo`, or a call with parentheses from one without them |
| Typed AST | Examine the result of semantic analysis, including resolved symbols and types | Identify which procedure a call invokes, inspect argument types |

The typed AST does not replace the parsed AST. Semantic analysis resolves meaning but also expands or transforms code, losing some distinctions in how it was written. For an ordinary procedure call, `foo(123)` and `123.foo` resolve to the same call structure, although source locations may differ.

Source text is the authoritative input for comment and formatting checks. A parser may retain documentation comments or other comment metadata; neither tree is a lossless representation of source text.

The inputs are bundled into two tiers:

- An *ordinary check*, declared as `check` in the config, receives source text and the parsed AST.
- A *semantic check*, declared as `semCheck` in the config, additionally receives the typed AST.

Checks can combine the representations they receive. For example, enforcing blank lines between procedure definitions uses source text and the parsed AST. A semantic check can additionally use resolved symbols and types.

Reading source and parsing it are relatively inexpensive compared with semantic analysis of the file and its dependencies. Providing both inputs to every check keeps the common interface simple. The source is the original text, not text reconstructed from an AST, and the parsed tree remains independent of semantic transformations.

## Settings

*Settings* are key-value pairs that adjust a check's behavior. Each check defines its own settings and defaults. A config may override them for each use of that check.

## Step

A *step* is an ordered selection of checks, each with its own settings and severity. A step may combine ordinary and semantic checks. Steps are declared in order in the config and run in that order for each selected file.

Each step carries a *label* that identifies it in the report. A label is for the reader, not an identifier: nothing is looked up by it, and two steps may share one.

Steps are independent: checks receive the same applicable file representations and do not see other steps' results. A step denotes ordering, not a transformation pipeline. The same check may be used in several steps, for example with stricter settings for package sources than for tests.

## Finding

A *finding* is an observation a check reports about the source. It contains:

- a line and column in the checked source file
- a message describing the observation

A finding may refer to a syntax node, a comment, whitespace, or any other location in the source. It need not correspond to an AST node.

Findings returned by checks carry no severity, step label, check name, or file path. The runner attaches these when collecting findings. Checks report locations in the selected file, not arbitrary locations in its dependencies.

Semantic transformations may produce nodes whose locations refer to an imported template or macro, or have no useful source location. A semantic check establishes that a location belongs to the selected file before using it in a finding.

## Severity

*Severity* determines how a check's findings are reported: as a *hint* or as an *error*. Severity is declared in the config per use of a check and applied by the runner. A check cannot choose its findings' severity.

Hints are informational; a run with only hints succeeds. A run with at least one error finding fails.

Compiler diagnostics and notices about checks that could not run are distinct from check findings. Their behavior is described under [Semantic Mode](#semantic-mode).

## Reports

A *step report* contains the findings produced by one step for one file, stamped with severity, step label, check name, and file path. A *file report* collects that file's step reports. A *run report* collects the file reports.

Files are reported in ascending path order, and steps and checks in declaration order. Findings from one check retain the order returned by that check. Checks produce deterministic results for the same inputs and settings.

Reproducibility also depends on the compiler version, configuration, dependency sources, and any environment inputs used by compiler configuration scripts or compile-time code. Identical selected files alone do not guarantee identical semantic results.

# Semantic Mode

Semantic checks are off by default. Passing `--semantic` (or `-s`) enables them in addition to ordinary checks. It does not replace the parsed AST with the typed AST or disable ordinary checks.

When the flag is absent and the config declares semantic checks, Lint warns that they were skipped, names the checks, and explains how to enable them. The warning does not itself fail the run. There is no config-level switch enabling semantic analysis implicitly.

When the flag is present, semantic analysis is needed only for files with applicable semantic checks after target selection and step-level exclusions. Import dependencies may still require analysis even if they are not themselves selected for linting.

.. warning::
  Semantic mode can be substantially more expensive than a run with only ordinary checks. It also evaluates compiler configuration scripts, macros, and compile-time code. It is not a passive or sandboxed inspection of source files.

## Compiler configuration

Lint delegates compiler configuration discovery and evaluation to the Nim compiler. It does not reproduce Nim's configuration search rules. Applicable system, user, parent-directory, project, and file-specific configuration is resolved by the compiler, including NimScript configuration that computes paths or defines dynamically.

The reference context is a direct `nim check` of the selected file using the corresponding compiler version and environment. Settings used to compile the lint executable do not automatically become settings for the files being linted.

.. important::
  Compiler configuration discovery does not reconstruct an arbitrary build command. Defines, dependency paths, backend options, or other arguments supplied only by a Nimble task or custom build script cannot be inferred from a `.nim` file alone. Semantic results match that build only when the analysis context includes those settings.

.. important::
  Compile `linter.nim` with the Nim version your project uses, and keep that same Nim installation on `PATH` when running `./linter --semantic`. Recompile the lint executable when you change the project's Nim version.

The compiler front end is built into the lint executable, but standard-library sources are read from disk during semantic analysis. Changing `PATH` cannot change the embedded compiler. For example, a lint executable built with Nim 2.4.0 does not become a Nim 2.2.12 analyzer by putting Nim 2.2.12 on `PATH`; rebuild it with Nim 2.2.12 instead. See [Semantic checks] for the build and run instructions.

Lint supports a defined set of Nim versions rather than assuming compatibility with every release, because the compiler's internal APIs can change between versions.

## Entry points and dependencies

Each selected file requiring semantic analysis is treated as an entry point, with its imports resolved recursively. Finding a package's main module or querying Nimble for an entry point is not required.

Dependencies are analyzed to establish context, but checks run only on selected files to which they apply. Ignoring a dependency for linting does not remove it from the compiler's import closure.

.. note::
  Standalone analysis may differ from a full project build. For example, `isMainModule` differs when a file is an entry point rather than an import, and file-specific compiler configuration may differ from the main project's configuration. This design does not provide whole-project checks or select a single project entry point automatically.

Each selected entry file has an independent compiler context. Dependencies are reused within that context, but overlapping import closures are analyzed again for other entry files. This keeps file-specific configuration and entry-point conditions isolated.

JavaScript semantic analysis is unsupported. When configuration selects the JS backend, Lint reports it and skips the affected semantic checks rather than analyzing the file under native assumptions.

## Errors and partial trees

Semantic analysis is best-effort. Lint requests compiler error recovery so that recoverable errors do not prevent analysis of the rest of a file or other selected files. Recovery cannot guarantee that every error will be reported or that every file will have a usable typed tree. Unexpected raised exceptions are reported as analysis failures without exposing the interrupted tree; compiler failures that terminate the process directly are outside this recovery boundary.

When the compiler reports semantic errors:

- ordinary checks still run on the source and parsed AST;
- semantic checks run on the retained typed tree when one is available, even if that tree is partial;
- compiler errors are surfaced as analysis warnings, preserving their messages and source locations where available; compiler warnings and hints are omitted;
- if no typed tree is available, Lint explicitly warns which semantic checks could not run for that file.

Compiler diagnostics may refer to dependencies or compile-time execution locations rather than the selected file. They retain that attribution and are not relabeled as check findings in the selected file. Requested line ranges and `#nolint` suppression apply to check findings, not to compiler diagnostics or incomplete-analysis warnings.

.. warning::
  A retained typed tree after errors is not a fully validated tree. Semantic checks handle missing type information, error placeholders, and incomplete subtrees without drawing conclusions that depend on information the compiler did not establish. A successful exit status does not certify that all code compiled or all semantic checks could run: review the analysis warnings as well.

Semantic diagnostics and unavailable-tree warnings do not themselves change the exit status. Check findings still use their configured severities, and a check that raises an exception is still a check error.

# Execution Flow

1. The config file is compiled into the project's lint executable, validating check references and settings types.
2. The executable reads command-line targets, output options, and the explicit semantic-mode flag.
3. The runner selects Nim files from targets or configured sources, applies the applicable exclusions, and orders files by path.
4. Without semantic mode, the runner warns about configured semantic checks that will not run.
5. For each selected file, the runner obtains its original source and parsed AST. These inputs are reused by its checks rather than prepared separately for each step. If parsing fails, the runner reports it and continues with the remaining files.
6. When semantic mode is enabled and a file has applicable semantic checks, the compiler resolves the file's configuration and analyzes its import closure. The resulting typed tree is reused by all semantic checks for that file. Diagnostics are reported without disabling the file's ordinary checks.
7. The runner runs applicable steps and checks in declaration order, supplying each check's inputs and settings. Semantic checks use the available full or partial typed tree; unavailable inputs are reported explicitly.
8. The runner attributes findings to their file, step, and check, and applies the configured severity. It filters findings by requested line ranges and `#nolint` suppression.
9. The runner assembles the reports, presents the results and any analysis warnings, and exits with the appropriate status.

The compiler may read and parse files as part of semantic analysis. Reusing the runner's parsed AST across checks does not imply that the compiler can reuse that same tree or avoid its own parsing.

# Library Surface

The library exposes the concepts needed to declare linters, checks, settings, configurations, and findings, together with the runner and CLI. The set of linters and checks is fixed by imports when the config is compiled; there is no runtime linter discovery.

Checks receive the original source text and compiler-native syntax trees. Semantic checks receive a separate compiler-native typed tree as well. Lint does not replace those trees with its own syntax model. Inputs are shared for read-only use.

Linter authors therefore depend on Nim's compiler tree definitions. Compiling the lint executable uses those compiler sources; setup details are described in [Writing a Linter](./writing_a_linter.html).

Compilation validates everything the type system can express, including misspelled check names, wrong settings types, and a check interface incompatible with its config declaration. Runtime analysis availability is reported during the run, not validated when the config is compiled.

# Exit Modes

The run ends in one of the following outcomes:

*Clean run* — all selected files parsed, checks that could run completed, and no check finding carries error severity. Analysis warnings may still be present. The process exits with code 0.

*Errors found* — no selected file failed to parse, no check raised an exception, and at least one check finding carries error severity. The process exits with code 1.

*Parse error* — a selected file could not be parsed, so checks requiring its parsed AST cannot run. The runner reports the failure and continues checking the remaining files. A parse failure takes precedence over error findings. The process exits with code 2.

*No sources* — no file matched the configured sources or command-line targets after selection. The process exits with code 3.

*Check error* — a check raised an exception. The run stops and reports the exception with the step label, check name, and file path. This is a tool failure rather than a finding about the source, and takes precedence over previously collected findings or parse failures. The process exits with code 4.

Semantic checks intentionally disabled by omitting `--semantic`, compiler diagnostics during best-effort analysis, and warnings about unavailable typed trees do not create additional exit modes.
