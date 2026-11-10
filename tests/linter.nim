import lint
import namelinter

runLint:
#startGlobalConfig
  sources = ["./src"]
  ignoredPatterns = ["./src/skip/skipped.nim", "./src/skip2/**/*"]
#endGlobalConfig

#startStepConfig
  step "Check naming":
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
#endStepConfig
