import lint
import namelinter

runLint:
#startSources
  sources = ["./src"]
#endSources
#startIgnoredPatterns
  ignoredPatterns = ["./src/skip/skipped.nim", "./src/skip2/**/*"]
#endIgnoredPatterns

#startStep
  step "Check naming":
    linter = nameLinter
#startStepIgnoredPatterns
    ignoredPatterns = ["./src/skip/skipped2.nim"]
#endStepIgnoredPatterns
#startCheck
    check varNames:
      severity = hint
#startSettings
      settings:
        minLength = 3
        maxLength = 12
#endSettings
#endCheck
    check constNames:
      severity = error
      settings:
        prefix = "k"
