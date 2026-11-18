import lint
import checks

when defined(ordinaryAsSemantic):
  runLint:
    step "Invalid kind":
      semCheck ordinaryRule:
        severity = hint
elif defined(semanticAsOrdinary):
  runLint:
    step "Invalid kind":
      check semanticRule:
        severity = hint
elif defined(unknownSetting):
  runLint:
    step "Invalid setting":
      semCheck semanticRule:
        settings:
          missing = 1
elif defined(wrongSettingType):
  runLint:
    step "Invalid setting type":
      semCheck semanticRule:
        settings:
          minimum = "not an integer"
else:
  runLint:
    step "Mixed checks":
      check ordinaryRule:
        severity = hint
      semCheck semanticRule:
        severity = error
      semCheck checks.semanticRule:
        settings:
          minimum = 5
          names = ["first", "second"]
