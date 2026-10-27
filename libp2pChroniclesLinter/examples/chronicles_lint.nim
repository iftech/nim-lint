## Builds and runs the linter against the fixture project.
##
## Every setting is optional. Omitting the whole `settings:` block uses the
## check's own defaults, which match what nim-libp2p's `audit_logs.py` enforces
## today. The settings are spelled out here to show the full surface; each one
## is used exactly as written, so a list you provide replaces the default
## instead of adding to it.

import lint
import linters/chronicles

runLint:
  sources = ["./tests/testproject/src"]
  ignoredPatterns = ["./tests/testproject/vendor/**/*"]

  step "Check chronicles messages":
    linter = chronicles
    check messageEndsWithPeriod:
      severity = error
    check messageOneSentence:
      severity = error

  step "Check chronicles fields":
    linter = chronicles
    check fieldNameLength:
      severity = error
      settings:
        # Field names shorter than this are reported ...
        minLength = 3
        # ... unless they are in this list. Omit the whole setting to get the
        # same list by default.
        exceptions = ["id", "ip"]
    check errForException:
      severity = error
      settings:
        field = "err"
        aliases = ["description", "error", "message", "msg"]
    check noPayloadWhenElevated:
      severity = error
      settings:
        # Levels that must stay payload-free.
        levels = ["warn", "error"]
        # Field names that carry payloads.
        fields = [
          "msg", "message", "buffer", "record", "reply", "response", "rpcMsg",
          "data", "encoded", "certificate", "ticket", "key",
        ]
