.. title:: Updating the Docs

The docs are written in [Nim-flavored Markdown](https://nim-lang.org/docs/markdown_rst.html).

To add code references, use `.. importdoc::` syntax to import the API docs and `[symbolName]` to add a reference. To disambuguate between identically named symbols, add a qualifier (e.g. `proc`) and signature. Read more in the [Nim DocGen Docs](https://nim-lang.org/docs/docgen.html#simple-documentation-links).

To include a code sample, use `.. include::` with `:code:` option, optionally using `:start-after:` and `:end-before:` for selective inclusion:

```
.. include:: /examples/example.nim
  :code:
  :start-after: #comment at the beginning of the block
  :end-before: #comment at the end of the block
```

If you need an admonition, use `.. important::`, `.. warning::`, or `.. note::`.
