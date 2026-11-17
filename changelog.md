# Changelog

- `[!]`—backward incompatible change
- `[+]`—new feature
- `[f]`—bugfix
- `[r]`—refactoring
- `[t]`—test suite improvement
- `[d]`—docs improvement

## 1.1.0 (WIP)

- `[+]` Pass original source text to checks alongside the parsed AST. AST-only `addCheck` registration remains supported but is deprecated; add `source: string` as the check proc's first parameter.
- `[f]` Catch non-`CatchableError` exceptions in checks.
- `[t]` CI: Use nimbus-coammon-workflow.

## 1.0.0 (November 9, 2026)

- 🎉 initial release.
