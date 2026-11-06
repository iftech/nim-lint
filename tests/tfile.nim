discard """
  exitcode: 0
  outputsub: '''
[Check naming][varNames][hint][src/skip/skipped.nim:3:4] variable `y` is shorter than 3 characters
hints: 1, errors: 0
  '''
"""

import osproc

let (output, exitCode) = execCmdEx("nim r linter.nim src/skip/skipped.nim")

echo output
quit(exitCode)
