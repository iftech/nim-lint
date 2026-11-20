import lint

import namelinter
import commentlinter
import stringifylinter

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
  step "Check comments":
    check todoComments:
      severity = hint

  step "Check string representations":
    semCheck customDollar:
      severity = error
