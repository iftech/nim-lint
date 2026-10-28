## Command-line arguments.
##
## The executable takes optional positional arguments that override the config's
## `sources` and `ignoredPatterns` for this run. Each argument is one of:
##
##   src/foo.nim          a file
##   src/module/*         a glob pattern
##   src/foo.nim:10-12    a file, restricted to line ranges
##
## With no arguments the config's sources are used.

import std/[parseopt, strutils]

type
  Target* = object ## One thing to lint.
    path*: string ## A file or a glob pattern.
    lines*: seq[tuple[first, last: int]] ## Empty means the whole file.

  Options* = object
    ## Everything the command line can say.
    targets*: seq[Target]
    format*: string ## `text` or `github`.

proc parseRanges(s: string): seq[tuple[first, last: int]] =
  ## Parses `10-12,40` into ranges. Returns an empty seq when `s` is not a
  ## range list, which is how a Windows path like `C:\src\a.nim` stays a path.
  for part in s.split(','):
    let bounds = part.split('-')
    if bounds.len > 2:
      return
    var first, last: int
    try:
      first = parseInt(bounds[0])
      last = if bounds.len == 2: parseInt(bounds[1]) else: first
    except ValueError:
      return
    if first < 1 or last < first:
      return
    result.add (first, last)

proc parseTarget*(arg: string): Target =
  ## Splits an argument into a path and optional line ranges.
  ##
  ## The split is on the last `:`, and only when the suffix parses as ranges, so
  ## paths containing colons (Windows drive letters) are left alone.
  let colon = arg.rfind(':')
  if colon > 0:
    let ranges = parseRanges(arg[colon + 1 .. ^1])
    if ranges.len > 0:
      return Target(path: arg[0 ..< colon], lines: ranges)
  Target(path: arg)

proc parseOptions*(args: seq[string]): Options =
  ## Parses the command line. Accepts `--format=github` and `--format:github`.
  result.format = "text"
  var p = initOptParser(args)
  while true:
    p.next()
    case p.kind
    of cmdEnd:
      break
    of cmdArgument:
      result.targets.add parseTarget(p.key)
    of cmdShortOption, cmdLongOption:
      case p.key
      of "format":
        result.format = p.val
      else:
        discard

proc inRanges*(line: int, ranges: seq[tuple[first, last: int]]): bool =
  ## True when `line` falls in any of `ranges`. An empty list matches everything.
  if ranges.len == 0:
    return true
  for r in ranges:
    if line >= r.first and line <= r.last:
      return true
