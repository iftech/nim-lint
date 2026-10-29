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
