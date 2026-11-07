.. title:: Suppressing Findings

Sometimes a finding is correct but you do not want to act on it. Add a `#nolint` comment at the end of the line the finding points at:

```nim
var ok = 1  #nolint
```

The comment applies to that line only, and to every finding on it, regardless of which check produced it.

# Where to put it

Findings point at the declaration, not at the enclosing section. Put the marker on the line that actually contains the offending name:

```nim
var
  ok = 1  #nolint   # suppresses the finding for `ok`
  x = 2             # still reported
```

# Rules

The marker must be at the **end** of the line. Trailing whitespace is fine; anything after the marker is not.

```nim
var ok = 1  #nolint          # suppressed
var ok = 1  #nolint because  # not suppressed
```

Because the marker has to be at the end of the line, a `#nolint` inside a string literal never suppresses anything:

```nim
echo "#nolint"   # reported as usual
```

# When not to use it

Suppression is for the occasional exception. If you find yourself adding `#nolint` to many lines, the rule is probably wrong for your project: change the check's settings, or exclude the directory in the config instead.
