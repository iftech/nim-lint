.. title:: Suppressing Findings

Sometimes a finding is correct but you do not want to act on it. Add a `#nolint` comment at the end of the line the finding points at. The test project's `src/main.nim` uses the marker on three of its variables:

.. include:: ../tests/src/main.nim
  :code:
  :start-after: #startSuppression
  :end-before: #endSuppression

Only `a` is reported. `ok` is suppressed by the marker, `b` is not suppressed because the marker is not at the end of the line, and `c` is suppressed even though the marker is followed by trailing whitespace. The comment applies to that line only, and to every finding on it, regardless of which check produced it.

Put the marker on the line that actually contains the offending name, as `ok` does above: the finding for `ok` is suppressed, while a sibling variable on its own line would still be reported.

.. important::
  The marker must be at the **end** of the line. Trailing whitespace is fine, as `c` shows; anything after the marker is not, as `b` shows.

  Because the marker has to be at the end of the line, a `#nolint` inside a string literal never suppresses anything:

  .. include:: ../tests/src/main.nim
    :code:
    :start-after: #startNoSuppressionInStrings
    :end-before: #endNoSuppressionInStrings

  Neither line is suppressed: the first is a string that happens to contain the marker, and the second has text after it.

# When not to use it

Suppression is for the occasional exception. If you find yourself adding `#nolint` to many lines, the rule is probably wrong for your project: change the check's settings, or exclude the directory in the config instead.
