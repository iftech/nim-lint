import lint
import dispatchchecks

runLint:
  sources = ["valid.nim", "separate.nim", "no_analysis.nim"]
  ignoredPatterns = ["separate.nim"]

  step "Ordinary":
    check ordinaryRule:
      settings:
        message = "ordinary first"

  step "Mixed":
    ignoredPatterns = ["no_analysis.nim"]
    semCheck semanticRule:
      severity = error
    check ordinaryRule:
      settings:
        message = "ordinary middle"
    semCheck semanticRule:
      settings:
        message = "typed last"
