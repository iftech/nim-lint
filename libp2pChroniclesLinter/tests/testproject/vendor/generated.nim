## This file must be skipped: it lives under vendor/, which is ignored.
## The unbounded-payload rule (see README, "Not implemented") would flag it.

proc vendored(data: string) =
  trace "vendored message.", data = data
