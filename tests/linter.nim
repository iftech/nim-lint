import lint
import namelinter

runLint:
#ANCHOR: globalConfig
  sources = ["./src"]
  ignoredPatterns = ["./src/skip/skipped.nim", "./src/skip2/**/*"]
#ANCHOR_END: globalConfig

#ANCHOR: stepConfig
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
#ANCHOR_END: stepConfig
