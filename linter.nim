## Lint config for this repository. The GitHub workflow uses it to lint the
## files a pull request changes.

import lint
import lint/linters/[naming, imports]

runLint:
  sources = ["./src", "./examples", "./tests", "./libp2pChroniclesLinter"]
  ignoredPatterns = ["./tests/testproject/**/*", "./libp2pChroniclesLinter/tests/**/*"]

  step "Check naming":
    linter = naming
    check varNames:
      severity = hint
      settings:
        minLength = 3
        maxLength = 40
    check constNames:
      severity = error
      settings:
        prefix = ""

  step "Check imports":
    linter = imports
    check noDeniedImports:
      severity = error
      settings:
        modules = ["asyncdispatch"]
