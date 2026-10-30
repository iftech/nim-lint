## Intentionally has no findings: the checks must stay quiet on valid logs.

proc cleanLogs(peerId: string, count: int) =
  trace "unsubscribing pubsub peer", peerId
  trace "named field", peerCount = count
  debug "single clause with no stop", peerId
