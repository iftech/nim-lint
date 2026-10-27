## Typed-mode fixture: `typePrefix` needs resolved type names, so it only runs
## when the project sems.

import ../src/lint
import ../src/lint/linters/typed

runLint:
  sources = ["./tests/typedproject/src"]
  step "Typed type names":
    linter = typedChecks
    check typePrefix:
      severity = error
      settings:
        prefix = "Good"
        suffixes = ["Widget"]
