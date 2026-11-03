## Example lint config.
##
## Build and run it with:
##
##   nim c -r examples/linter.nim

# The config may import linters that live in this repository, and those
# are compiled into the binary, so they belong in the cache key.
#
# Simple imports in the form `import a` and `import a/b/c`
# are detected by the lint GitHub Action:
# if an imported module file changes, the action forces the linter
# executable be rebuilt.
# Relative imports (`import ./a`,
# `import ../a`), bracket groups (`import a/[b, c]`), `from x import y`,
# and `include` are not handled. Write such imports as plain
# `import a/b` lines to have them picked up.
import ../src/lint
import ../src/lint/linters/[naming, imports]

runLint:
  sources = ["./tests/testproject"]
  ignoredPatterns = ["./tests/testproject/tests/**/*"]

  step "Check naming":
    linter = naming
    ignoredPatterns = ["./tests/testproject/src/skip/*"]
    check varNames:
      severity = hint
      settings:
        minLength = 3
        maxLength = 12
    check constNames:
      severity = error
      settings:
        prefix = "k"

  step "Check imports":
    linter = imports
    ignoredPatterns = ["./tests/testproject/src/skip/*"]
    check noDeniedImports:
      severity = error
      settings:
        modules = ["asyncdispatch"]
