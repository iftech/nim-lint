import lint
import namelinter

runLint:
  sources = ["./src"]
  ignoredPatterns = ["./src/skip/skipped.nim"]

  step "Check naming":
    linter = nameLinter 
    ignoredPatterns = ["./src/skip/skipped2.nim"]
    check varNames:
      severity = hint
      settings:
        minLength = 3
        maxLength = 12
    check constNames:
      severity = error
      settings:
        prefix = "k"
