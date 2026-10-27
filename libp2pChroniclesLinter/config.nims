# Development wiring for building from this directory. When the package is
# installed, its nimble file's `requires "lint"` is what resolves `lint`.
import std/[os, strutils]

let pkgRoot = thisDir()
switch("path", pkgRoot / "src")

let nimRoot = getCurrentCompilerExe().parentDir.parentDir
for candidate in [nimRoot, nimRoot / "lib"]:
  if dirExists(candidate / "compiler"):
    switch("path", candidate)
    break

let lintRoot = pkgRoot.parentDir
if fileExists(lintRoot / "nimble.paths"):
  switch("path", lintRoot / "src")
  for line in staticRead(lintRoot / "nimble.paths").splitLines:
    let trimmed = line.strip
    if trimmed.startsWith("--path:"):
      switch("path", trimmed[8 .. ^1].strip(chars = {'"'}))
