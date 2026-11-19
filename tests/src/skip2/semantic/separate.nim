import helper

when defined(lintFileConfig):
  {.error: "another entry point's file configuration leaked".}

let after* = importedValue(456)
