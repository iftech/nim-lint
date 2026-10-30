## Example lint config.
##
## Build and run it with:
##
##   nim c -r examples/linter.nim

import ../src/lint
import ../src/lint/linters/[naming, imports]

runLint:
  sources = ["./tests/testproject"]
  ignoredPatterns = ["./tests/testproject/tests/**/*"]

  step "Check naming":
    linter = naming
    ignoredPatterns = ["./tests/testproject/src/skip/*"]
    check varNames:
      severity = hint
      settings:
        minLength = 3
        maxLength = 12
    check constNames:
      severity = error
      settings:
        prefix = "k"

  step "Check imports":
    linter = imports
    ignoredPatterns = ["./tests/testproject/src/skip/*"]
    check noDeniedImports:
      severity = error
      settings:
        modules = ["asyncdispatch"]
