## This file must NOT compile: it checks that config mistakes are compile errors.
## It is excluded from the test suite and built by CI to assert failure.

import ../src/lint
import ../src/lint/linters/[naming]

runLint:
  sources = ["./tests/testproject"]

  step "Typo in settings":
    linter = naming
    check varNames:
      severity = error
      settings:
        minLegth = 3
