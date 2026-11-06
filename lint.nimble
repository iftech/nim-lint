# Package

version = "0.1.0"
author = "Constantine Molchanov"
description = "Library for creating a linter for your Nim project."
license = "MIT"
srcDir = "src"

const testBinaries = "tests/tfile tests/tproject"

# Dependencies

requires "nim >= 2.2.0"
requires "glob >= 0.11.3"

task test, "Run the test suite":
  exec "testament --directory:tests pattern t*.nim"

task apidocs, "Generate the API docs":
  exec "nim doc --outdir:htmldocs/api --project src/lint.nim"

task bookIndex, "Generate the book index":
  exec "nim book --index:only docs"

task book, "Generate the book":
  exec "nim book docs"
  cpFile("htmldocs/intro.html", "htmldocs/index.html")

task docs, "Generate the documentation":
  rmDir "htmldocs"
  exec "nimble apidocs"
  exec "nimble bookIndex"
  exec "nimble book"
