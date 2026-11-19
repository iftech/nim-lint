import helper

let before* = importedValue(123) #nolint
let invalid*: int = "not an integer" #nolint
let after* = importedValue(456) #nolint
