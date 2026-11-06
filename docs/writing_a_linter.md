.. title:: Writing a Linter

# Writing a Linter

A linter is a Nim module that declares one or more checks and exports a linter value. It lives in your repository, next to the config that uses it.

## A minimal linter

.. include:: ../tests/namelinter.nim
   :code:

Three things make this a linter:

- a settings type, which may be empty
- a `run` proc taking the file's AST and the settings, returning findings
- a `Linter` value and one `Check` per rule, created with `check`

## The AST

Checks receive the parsed file as a `PNode` from Nim's own compiler AST module (`compiler/ast`). Lint neither converts the tree nor provides a tree type of its own: the node a check walks is exactly the node the parser produced.

Writing a check therefore means importing `compiler/ast` and matching on node kinds. A check must not modify the tree: the same AST is shared by every step that runs against the file.

## The compiler sources on the search path

`compiler/ast` ships with the Nim distribution rather than with Lint, so the compiler sources have to be on the search path. This affects **both** files you write:

- the **linter**, because it imports `compiler/ast` to walk the tree
- the **config**, because it imports `lint`, which imports `compiler/ast` in turn

Without it, neither compiles:

```
Error: cannot open file: compiler/ast
```

The fix is a one-line `.nims` file next to each of them:

```nim
--path:"$nim/"
```

| What you have | Where the file goes |
| --- | --- |
| A single-module linter `foo.nim` | `foo.nims`, next to it |
| A linter packaged as a Nimble package | `config.nims` in the package root |
| Your config `linter.nim` | `linter.nims`, next to it |

Lint's own `src/lint.nims` contains the same line, which is why the library compiles when you install it.

## Findings

A finding carries a position and a message, and nothing else:

```nim
type Finding* = object
  line*: int
  col*: int
  msg*: string
```

A check does not know the file it runs against, the linter it belongs to, or the severity its findings are reported with. The runner attaches all of that when it collects findings, which is what lets the same check run at different severities in different steps.

Use `finding(node, msg)` to build one from an AST node; it takes the position from the node.

## Settings

Settings are a plain object. Give each field a default in the type definition, and a config that omits the `settings:` block gets those defaults:

```nim
type
  NoTodoSettings* = object
    marker*: string = "TODO"
    ignoreCase*: bool = false
```

A config that does provide settings has its keys checked against this type, so a misspelled key is a compile error.

## Using the linter

Import it from the config and refer to the checks by name:

```nim
import lint
import tools/comments_linter

runLint:
  sources = ["./src"]

  step "Check comments":
    linter = comments
    check noTodo:
      severity = hint
      settings:
        marker = "FIXME"
```

The import must be a plain `import a/b` line for the GitHub Action to notice changes to the linter and rebuild the cached binary.
