discard """
  exitcode: 1
  outputsub: '''
[Check naming][varNames][hint][src/main.nim:8:2] variable `a` is shorter than 3 characters
[Check naming][varNames][hint][src/main.nim:10:2] variable `b` is shorter than 3 characters
[Check naming][constNames][error][src/main.nim:4:2] constant `invalid` should start with `k`
hints: 2, errors: 1
  '''
"""

import osproc

let (output, exitCode) = execCmdEx("nim r linter.nim")

echo output
quit(exitCode)
