# Lint

**Lint** is a linter and a linting rule library for Nim projects. It runs code rules against your code base and reports mismatches.

# Building from source

```shell
$ git clone git@github.com:iftech/nim-lint.git
$ cd nim-lint
$ nimble build
```

# Usage

Create [`lint.toml`](./lint.toml). This is the config that defines the rules you wan to run.

Check all .nim files in the current directory and its subdirectories (warning: because the rules are currently not ready, do not expect this to work):

```shell
$ ./bin/lint
```

Check a single file:

```shell
$ ./bin/lint ./tests/testproject/src/testproject.nim
Checking file tests/testproject/src/testproject.nim
        [typenames][error][tests/testproject/src/testproject.nim:4:2] Type names must me 10 or less chars long, but OverlyLongTypeName is 18 chars long.
        [statuslibs][hint][tests/testproject/src/testproject.nim:1:0] Do not use parsecfg. Use Status's analog instead: confutils.
Done checking tests/testproject/src/testproject.nim.
```

Check all .nim files in a given directory:

```shell
$ ./bin/lint -d:./tests/testproject/
Checking file tests/testproject/src/testproject.nim
        [typenames][error][tests/testproject/src/testproject.nim:4:2] Type names must me 10 or less chars long, but OverlyLongTypeName is 18 chars long.
        [statuslibs][hint][tests/testproject/src/testproject.nim:1:0] Do not use parsecfg. Use Status's analog instead: confutils.
Done checking tests/testproject/src/testproject.nim.
Checking file tests/testproject/src/testproject/submodule.nim
        [typenames][error][tests/testproject/src/testproject/submodule.nim:4:2] Type names must me 5 or more chars long, but Foo is 3 chars long.
        [statuslibs][hint][tests/testproject/src/testproject/submodule.nim:1:0] Do not use asyncdispatch. Use Status's analog instead: chronos.
Done checking tests/testproject/src/testproject/submodule.nim.
```

# Architecture

## Code Layout

- `lint.nim` is the entrypoint
- `types.nim` holds the shared types, e.g. `Issue`
- `rules/` is a directory with rule submodules

## Rules

Rules are the core of lint. They are functions that accept a module's AST and emit `Issue`s:

```nim
proc run*(
    queue: AsyncQueue[Issue], # put found issues here
    filepath: string, # the path to the file being checked, for reporting
    ast: PNode, # the module's AST
    severity: Severity, # the severity the findings are reported with
    settings: TomlTableRef, # param values
) {.async.} =
```

Because a rule has the entire raw AST to read, it can do all kinds of checks.

Note: Because files are checked individually, a rule cannot implement project-side logic. I.e., a rule like "If some modules use asyncdispatch and other modules use chronos, tell the user to pick one" cannot exist. However, you can have a rule like "If a module uses asyncdispatch, tell the user to use chronos instead."

Each `Issue` contains the complete information about the found problem:

```nim
type Issue* = object
  severity*: Severity
  rulename*: string # name of the rule, for reporting
  filepath*: string
  line*: int # 1-indexed
  col*: int # 0-indexed
  msg*: string # the message that the rule wants to communicate to the user
```

Since rules are part of the lint package, they must be designed to be universal, i.e. not tailored for a specific project but _tailorable_ for any project via settings:

- Bad rule: "Check that all type names start with 'Foo'." Good rule: "Check that type names have a given prefix, empty by default."
- Somewhat OK: "Check that all ref type names start with 'Ref'." Better: "Check that all ref type names start with a certain prefix, 'Ref' by default."

However, if the rule is bound to some specific values, it is OK to hardcode them:

- OK if the rule is specifically called "Enforce Status Libs": "Check that Status's libs are used instead of similarly functioning std libs: chronos instead of asyncdispatch, confutils instead of parsecfg, etc."

It is good practice to have a rule cover a specific isolated area, not too large, not too small:

- Bad rule: "Check that the variables used in chronicle logs are n+ chars long."
- Good rule: "A collection of chronicles checks: use n+ length variables, avoid certain characters in the end (default: [!, ?, .]), etc.

### Rules Execution

A single file check consists of running all enabled rules against it asynchronously and reporting the found issues.

If multiple files are to be checked, they are checked asynchronously as well (TODO).

# Version Requirement

Since lint is not only the rule runner but also the rule library, it is possible that with a new lint release existing confings will become outdated.

This is why there is the mandatory `version` key in `lint.toml`. It is the specific lint version this config is designed for. Before running any rules, lint checks that its own version is the same as the required one and print a warning if there's a mismtach.

Note: This is not a semver or any similar check that validates if the current versions _satisfies_ a certain version constraint. Lint checks that its version is _exactly_ the same as the required one. This is because rules do not progress, they just change. Version 2 is not better than 1, it's just a different version. A better term would actually be "edition," but "version" is too well established to denote package releases.

# GitHub Actions Integration (TODO)

When executed as part of CI, lint will comment on the code that contains issues. Because it knows the exact point where an issue occured, it can leave specific comments in specific code locations.

# Declined Ideas

## Decentralized Architecture

Initially, lint was to be designed as a rule runner and the rules were supposed to be independent Nim packages.

Reasons why this idea was declined:

- With distributed architecture, it's much harder to update the core package without breaking stuff. All rules have to either use the same Nim version as lint so that the lint-parsed AST could be fed to them or parse the AST on their side adding overhead.
- There is no nice way of shipping rules this way. The options are: compile the rules on the target machine, ship binaries, and ship dynlibs. All three have their own weaknesses.
- There is no nice way of running the rules this way.

## Presets aka Rulesets

There was this idea of having a ruleset registry that would hold ready-to-use configs, e.g. Status Style Guide, NEP 1, etc.

One would refer to a ruleset in their `lint.toml` and override the rules properties if necessary:

```toml
ruleset = "https://raw.githubusercontent.com/iftech/min-lint-rulesets/master/status.toml"

[typenames]
severity = "error"
[typenames.settings]
minLength = 5
```

Reasons why this idea was declined:

- Rulesets would evolve independently on the core package and would require their own edition management. Although this is doable, this significantly extends the scope of development.
- A ruleset may require a lint version that is different from the lint version that the user wants locally for their custom rules. It is not obvious how to deal with this situation:

```toml
list_version = "1.0.0"

# Ruleset has `list version = "2.0.0" in it`
ruleset = "https://raw.githubusercontent.com/iftech/min-lint-rulesets/master/status.toml"
```

- The simplest `lint.toml` would look like `ruleset = "https://raw.githubusercontent.com/iftech/min-lint-rulesets/master/status.toml"`. Which kind begs for a question: "Why not simply put `status.toml` in the project root and use it as a config with `lint -c:status.toml`? It's more clear this way, and you can easily customize the rules locally."

Shared rulesets still sounds like a nice thing to have but it's probably much easier to solve by simply shipping your config with the project.

# License

Licensed and distributed under either of

- MIT license: [LICENSE-MIT](./LICENSE-MIT) or http://opensource.org/licenses/MIT

or

- Apache License, Version 2.0, ([LICENSE-APACHEv2](./LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. This file may not be copied, modified, or distributed except according to those terms.
