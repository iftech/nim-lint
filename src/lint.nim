## Lint: a library for building linters for Nim projects.
##
## A project imports `lint`, imports the linters it wants, and calls `runLint`
## with a config block. Compiling that file produces the project's lint
## executable.

import ./lint/private/types
import ./lint/private/config

# What a linter author needs: the types and helpers for declaring checks.
export types.Linter, types.Check, types.Finding
export types.newLinter, types.check, types.finding

# What a config file needs: `runLint`.
export config
