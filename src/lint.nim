## Lint: a library for building linters for Nim projects.
##
## A project imports `lint`, imports the linters it wants, and calls `runLint`
## with a config block. Compiling that file produces the project's lint
## executable.

import ./lint/[types, cli, config, runner]

export types, cli, config, runner
