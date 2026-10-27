## Fixtures: every violation the easy checks must catch, plus a few valid
## statements that must produce nothing.

proc goodLogs(peerId: string, count: int, err: ref CatchableError) =
  trace "plain message", peerCount = count
  debug "named fields", peerId = peerId, peerCount = count
  info "error context", err = "failed"
  warn "elevated without payload", peerCount = count
  # `id` and `ip` are accepted short names by default.
  trace "allowed short names", id = 1'i64, ip = peerId

proc messageViolations(peerId: string) =
  # messageEndsWithPeriod
  trace "message with a full stop.", peerId = peerId
  # messageOneSentence
  trace "First sentence. Second sentence", peerId = peerId

proc fieldViolations(peerId: string, data: string) =
  # fieldNameLength: bare selector with a two-letter name
  trace "short bare field", ab
  # fieldNameLength: named field with a one-letter name
  trace "short named field", c = peerId
  # fieldNameLength: three characters is the boundary and is accepted
  trace "boundary field", abc = peerId

proc exceptionViolations() =
  # errForException
  debug "wrong exception field", msg = getCurrentExceptionMsg()

proc payloadViolations(data: string) =
  # noPayloadWhenElevated
  warn "elevated with payload", data = data
  error "elevated with encoded", encoded = data
  # trace/debug may carry payloads
  trace "trace with payload", data = data
