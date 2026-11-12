# lint
# Copyright 2025-2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

## Per-line suppression.
##
## A finding is suppressed when the line it points at ends with a `#nolint`
## comment:
##
##   var ok = 1  #nolint
##
## The comment is looked for in the source text, because comments are not part
## of the AST. Requiring it at the end of the line keeps the check trivial and
## means a marker inside a string literal (`echo "#nolint"`) never matches.

import std/strutils

const suppressionMarker* = "#nolint"

proc isSuppressed*(line: string): bool =
  ## True when `line` ends with a `#nolint` comment.
  line.strip(leading = false).endsWith(suppressionMarker)

proc isSuppressed*(lines: seq[string]; line: int): bool =
  ## True when the 1-based `line` ends with a `#nolint` comment. Out-of-range
  ## lines are never suppressed.
  if line < 1 or line > lines.len:
    return false
  isSuppressed(lines[line - 1])
