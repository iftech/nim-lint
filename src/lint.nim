# lint
# Copyright 2025-2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

## Lint: a library for building linters for Nim projects.
##
## A project imports `lint`, imports the linters it wants, and calls `runLint`
## with a config block. Compiling that file produces the project's lint
## executable.

import ./lint/private/types
import ./lint/private/config

# What a linter author needs: the types and helpers for declaring checks.
export types.Linter, types.Check, types.Finding
export types.addCheck, types.toFinding

# What a config file needs: `runLint`.
export config
