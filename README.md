# Lint

**Lint** checks Nim source code against a set of rules and reports what it finds.

You configure it with a Nim file: you describe the rules you want, compile that file, and run the resulting executable. The config is Nim, so a misspelled rule name or a wrong setting type is a compile error rather than a silent no-op, and your editor completes and validates it as you type.

```nim
import lint
import namelinter

runLint:
  sources = ["./src"]
  ignoredPatterns = ["./src/skip/skipped.nim"]

  step "Check naming":
    linter = nameLinter
    ignoredPatterns = ["./src/skip/skipped2.nim"]
    check varNames:
      severity = hint
      settings:
        minLength = 3
        maxLength = 12
    check constNames:
      severity = error
      settings:
        prefix = "k"
```

```shell
nimble install lint
nim r linter.nim
```

Read the docs at <https://iftech.github.io/nim-lint/>.

## License

Licensed and distributed under either of

- MIT license: [LICENSE-MIT](./LICENSE-MIT) or <http://opensource.org/licenses/MIT>

or

- Apache License, Version 2.0, ([LICENSE-APACHEv2](./LICENSE-APACHEv2) or <http://www.apache.org/licenses/LICENSE-2.0>)

at your option. This file may not be copied, modified, or distributed except according to those terms.
