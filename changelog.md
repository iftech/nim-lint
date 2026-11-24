# Changelog

- `[!]`—backward incompatible change
- `[+]`—new feature
- `[f]`—bugfix
- `[r]`—refactoring
- `[t]`—test suite improvement
- `[d]`—docs improvement

## 1.1.1 (WIP)

- `[+]` Add `--verbose` / `-v` for real-time per-file analysis and checking progress. Semantic progress is now opt-in; warnings and errors remain visible by default.

## 1.1.0 (November 23, 2026)

- `[f]` Resolve `$nim` and installation configuration from Nim on `PATH` during semantic analysis, rather than from the linter executable's location.
- `[f]` Flush semantic analysis errors as they arrive and identify each analysis target, preserving diagnostic context when the compiler terminates directly.
- `[f]` Select GitHub Action PR targets from the PR head instead of the synthetic merge, excluding unrelated newer base-branch changes.
- `[+]` Set up project dependencies in the GitHub Action when semantic checks are enabled. Override the `setup` command or set it to empty to skip.
- `[t]` Use Lint to lint Lint.
- `[d]` Add an LLM skill to generate linters.
- `[f]` Enable compiler stdlib VM callbacks for semantic analysis without requiring users to define `nimcore`. Report compiler errors while omitting compiler warnings and hints.
- `[+]` Ship a portable `writing-lint-checks` agent skill with ordinary/semantic selection guidance and verified examples.
- `[+]` Add semantic checks registered with `addCheck` and declared with `semCheck`. Pass `--semantic` or `-s` to analyze resolved symbols and types alongside the original source and parsed AST.
- `[+]` Report compiler diagnostics as warnings and run semantic checks on available partial trees. Each file uses its own compiler configuration and import closure; JavaScript analysis is unsupported.
- `[+]` Pass original source text to checks alongside the parsed AST. AST-only `addCheck` registration remains supported but is deprecated; add `source: string` as the check proc's first parameter.
- `[f]` Catch non-`CatchableError` exceptions in checks.
- `[t]` CI: Use nimbus-common-workflow.

## 1.0.0 (November 9, 2026)

- 🎉 initial release.
