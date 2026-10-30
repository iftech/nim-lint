import std/strutils

import compiler/[ast, parser, idents, options]

import lint/types
import linters/chronicles

# These checks are pure functions of (AST, settings), so the tests call them
# directly. The end-to-end path is covered by `tests/run.nim`.
#
# A check uses its settings exactly as given: there are no "empty means
# default" sentinels. The defaults live in `defaultXxxSettings` and are what a
# config gets when it omits a `settings:` block.

proc parse(src: string): PNode =
  parseString(src, newIdentCache(), newPartialConfigRef(), "test.nim")

proc linesOf(findings: seq[Finding]): seq[int] =
  for f in findings:
    result.add f.line

let tree = parse("""
proc f(peerId: string, data: string) =
  trace "first", cx
  trace "second", ab
  warn "third", data = data
  error "fourth", encoded = data
  info "fifth", msg = getCurrentExceptionMsg()
  trace "sixth.", peerId = peerId
""")

# --- fieldNameLength ------------------------------------------------------

doAssert linesOf(fieldNameLength.run(tree, defaultFieldNameSettings)) ==
  @[2, 3], "defaults should flag both two-letter field names"

let withId = parse("proc f() =\n  trace `only id`, id\n")
doAssert linesOf(fieldNameLength.run(withId, defaultFieldNameSettings)) == @[],
  "`id` is accepted by the default exceptions"

# Without the defaults, `id` is flagged: settings are taken literally.
doAssert linesOf(fieldNameLength.run(withId, FieldNameSettings(minLength: 3))) ==
  @[2], "an empty exceptions list means no exceptions"

# Overriding `exceptions` replaces the defaults rather than extending them:
# `cx` is still too short, and only it is reported.
doAssert linesOf(
  fieldNameLength.run(tree, FieldNameSettings(exceptions: @["cx", "ab"]))
) == @[],
  "explicit exceptions should accept both names"

# `minLength` is configurable.
doAssert linesOf(fieldNameLength.run(tree, FieldNameSettings(minLength: 1))) == @[],
  "minLength 1 accepts every field"

# --- noPayloadWhenElevated ------------------------------------------------

doAssert linesOf(noPayloadWhenElevated.run(tree, defaultPayloadSettings)) == @[4, 5],
  "defaults check warn and error"

# The level list replaces the default: only warn/error carry payloads here, so
# restricting to trace reports nothing.
doAssert linesOf(
  noPayloadWhenElevated.run(
    tree, PayloadSettings(levels: @["trace"], fields: defaultPayloadSettings.fields)
  )
) == @[],
  "trace-only should report nothing, since the trace calls carry no payload"

# Every setting is taken literally: an omitted `levels` means "check nothing".
doAssert linesOf(
  noPayloadWhenElevated.run(tree, PayloadSettings(fields: @["encoded"]))
) == @[], "an empty level list checks nothing"

# With both set explicitly, only the named field on the named level is flagged.
doAssert linesOf(
  noPayloadWhenElevated.run(
    tree, PayloadSettings(levels: @["warn", "error"], fields: @["encoded"])
  )
) == @[5], "only the `encoded` payload on the error level is reported"

doAssert linesOf(
  noPayloadWhenElevated.run(
    tree, PayloadSettings(levels: @["warn", "error"], fields: @["nonexistent"])
  )
) == @[], "a payload list that matches nothing reports nothing"

# --- errForException ------------------------------------------------------

doAssert linesOf(errForException.run(tree, defaultExceptionSettings)) == @[6],
  "`msg = getCurrentExceptionMsg()` is flagged by the defaults"

let renamed = errForException.run(
  tree, ExceptionSettings(field: "error", aliases: @["msg"])
)
doAssert renamed.len == 1
doAssert "`error`" in renamed[0].msg, "message should name the configured field"

# An alias list that does not contain `msg` silences the check.
doAssert linesOf(
  errForException.run(tree, ExceptionSettings(field: "err", aliases: @["message"]))
) == @[], "`msg` is not an alias, so nothing is reported"

# An empty alias list checks nothing.
doAssert linesOf(
  errForException.run(tree, ExceptionSettings(field: "err"))
) == @[], "an empty alias list checks nothing"

# --- messageEndsWithPeriod ------------------------------------------------

doAssert linesOf(messageEndsWithPeriod.run(tree, MessageSettings())) == @[7],
  "trailing full stop should be flagged by default"

doAssert linesOf(
  messageEndsWithPeriod.run(tree, MessageSettings(allowTrailingPeriod: true))
) == @[], "trailing full stops are accepted when configured"

echo "settings: ok"
