---
name: writing-lint-checks
description: Design and implement Nim checks and linters using the Lint library. Use when translating a code-quality policy into a check, choosing ordinary versus semantic analysis, or extending a Lint config. Prefer ordinary checks unless resolved types or symbols are essential.
---

# Writing Lint checks

Turn the user's policy into a small, verified rule. Choose the cheapest inputs
that establish the policy, not the most powerful analysis available.

## 1. Establish the contract

Write down what produces a finding and at least one similar case that does not.
Clarify only ambiguities that change the rule; otherwise state a narrow default.
In particular, distinguish:

- Source spelling from resolved meaning.
- A declaration existing from an expression being callable.
- A custom implementation from a generic fallback. A callable generic formatter
  does not prove that a type has an intentional, secret-safe representation.
- File-local declarations from imported, visible, or whole-project declarations.
  These are different scopes, not interchangeable ways of implementing a rule.

Do not promise overload resolution, cross-file visibility, or security properties
based only on procedure names or the existence of a declaration.

## 2. Inspect the target project

Locate its Nim version, Lint dependency/version, compiler configuration, existing
linters, lint config, and test commands. Preserve their layout and conventions.
The installed Lint API and matching compiler sources outrank these examples:
compiler node shapes and APIs vary with Nim versions.

Use the project's existing dependency workflow. Do not install or upgrade tools,
rewrite build configuration, or add a framework just to generate one check.
Observe the agent's tool permissions and project instructions. Compilation can
execute configuration scripts and macros; semantic analysis executes compile-time
code too. Neither is a sandbox for untrusted input.

## 3. Choose ordinary or semantic

| Evidence the rule needs | Choice |
| --- | --- |
| Comments, whitespace, line endings, exact spelling | Ordinary `check`, using source text |
| Declarations, syntactic structure, parentheses, call spelling | Ordinary `check`, using parsed AST, optionally source |
| Resolved types, symbol identity, type-specific overload declarations | `semCheck`, using typed AST plus either ordinary input |

Default to an ordinary check. Before choosing `semCheck`, state one sentence
explaining what required fact the parsed AST and source cannot establish.
A rule mixing formatting and syntax still does not need semantic analysis.
Conversely, do not replace symbol/type identity with string matching merely to
avoid semantic cost. If the current check API cannot establish the contract,
explain the gap rather than silently weakening the rule.

Load only the relevant implementation reference:

- [Ordinary checks](references/ordinary-check.md): source/AST example and setup.
- [Semantic checks](references/semantic-check.md): type-aware example and limits.

Ordinary checks still require a parseable file; they are not a raw-text mode
that runs despite syntax errors. Both callbacks receive source and parsed AST.
A semantic callback additionally
receives a separate typed AST. Register either with `linter.addCheck`; select
`check` or `semCheck` in the config to match. Do not generate the deprecated
AST-only callback or invent `addSemCheck`/`addSynCheck` registration helpers.

## 4. Implement the smallest coherent change

Name the module and check after the policy, not its analysis tier. Reuse settings
and registration patterns already present. Use an empty settings object if the
rule needs no configuration; do not parameterize every constant speculatively.

Read inputs without modifying them. Return `seq[Finding]`; do not print findings,
choose severity in the callback, or read the source file again. The config owns
severity. Findings use a 1-based line and 0-based byte column in the checked file;
use `node.toFinding(message)` or construct `Finding` for text locations. Preserve
source positions rather than calculating columns from stripped text.

Comments are not reliably recoverable from an AST. Conversely, searching for `#`
or TODO text is not a Nim lexer: strings can contain apparent comments. Implement
the contract's actual lexical scope or explicitly document a restricted example.

## 5. Build and try the linter

Compile the project's lint config and run it on the project's existing sources
as a smoke check. Treat Lint as a working dependency: do not add test suites,
test configs, fixtures, or framework-validation checks by default. Tests for the
project's own rule logic are optional and are added only when the user asks.

Use the project's Nim installation for both build and run:

```shell
nim --version
nim c -d:release linter.nim
./linter
# Only when the config includes semantic checks:
./linter --semantic
```

Adapt executable invocation for the platform. Inspect the output for obvious
integration problems. Error findings normally exit 1; that is an expected lint
result, not a build failure. Do not rewrite existing project code just to make
the lint run clean unless asked. Suppression and range filtering belong to Lint,
not each rule, and need no additional tests in the consuming project.

Finish with a short explanation of the rule, why its tier is necessary, files
changed, commands and observed results, and any deliberately unsupported cases.
Distinguish a successful smoke run from exhaustive validation of the rule.
