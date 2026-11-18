import std/macros
import helper

let before* = importedValue(123)
macro fail(): untyped = error("intentional semantic test error")
fail()
let after* = importedValue(456)
