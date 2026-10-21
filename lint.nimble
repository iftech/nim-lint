# Package

version       = "1.0.0"
author        = "Constantine Molchanov"
description   = "Linter for Nim projects."
license       = "MIT or Apache License 2.0"
srcDir        = "src"
binDir        = "bin"
bin           = @["lint"]


# Dependencies

requires "nim >= 2.2.12"
requires "chronos >= 4.4.1"
requires "chronicles >= 0.12.4"
requires "confutils >= 0.1.1"
requires "toml_serialization >= 0.2.18"
