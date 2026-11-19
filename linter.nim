import lint
import tools/stylelinter

runLint:
  sources = ["src/", "tools/", "linter.nim"]
  ignoredPatterns = ["nimbledeps/**/*"]

  step "Code style":
    check redundantResult:
      severity = hint
    check lenCalls:
      severity = hint
    check exportDocs:
      severity = hint
    check callParentheses:
      severity = hint
      settings:
        exceptions = ["inc", "dec", "close", "echo"]
