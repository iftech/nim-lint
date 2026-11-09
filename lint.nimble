# Package

version = "1.0.0"
author = "Constantine Molchanov"
description = "Linting toolkit for Nim projects."
license = "MIT or Apache License 2.0"
srcDir = "src"

# Dependencies

requires "nim >= 2.2.0"
requires "glob >= 0.11.3"

task apidocs, "Generate the API docs":
  exec "nim doc --outdir:htmldocs/api --project src/lint.nim"

task bookIndex, "Generate the book index":
  exec "nim book --index:only docs"

task book, "Generate the book":
  exec "nim book docs"
  cpFile("htmldocs/intro.html", "htmldocs/index.html")
  cpFile("LICENSE-APACHEv2", "htmldocs/LICENSE-APACHEv2")
  cpFile("LICENSE-MIT", "htmldocs/LICENSE-MIT")

task docs, "Generate the documentation":
  rmDir "htmldocs"
  exec "nimble apidocs"
  exec "nimble bookIndex"
  exec "nimble book"
