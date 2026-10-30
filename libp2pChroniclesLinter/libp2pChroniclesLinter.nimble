# Package

version       = "0.1.0"
author        = "Constantine Molchanov"
description   = "Lint linter for Chronicle log statements, following nim-libp2p's audit_logs.py rules."
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.2.12"
requires "lint >= 0.1.0"


task test, "Build and run the linter against the fixture project":
  exec "nim c -r --hints:off tests/run.nim"
