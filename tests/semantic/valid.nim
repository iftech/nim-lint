import helper

when not defined(lintParentConfig):
  {.error: "parent configuration was not loaded".}
when not defined(lintFileConfig):
  {.error: "file configuration was not loaded".}

when compiles(1 + "not an integer"):
  {.error: "invalid expression unexpectedly compiled".}

let before* = importedValue(123)
let after* = 456.importedValue
