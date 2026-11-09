.. title:: Suppressing Findings

Sometimes a finding is correct but you do not want to act on it. Add a `#nolint` comment at the end of the line the finding points at. The test project's `src/main.nim` uses the marker on three of its variables:

.. include:: ../tests/src/main.nim
  :code:
  :start-after: #startSuppression
  :end-before: #endSuppression

Only `a` is reported. `ok` is suppressed by the marker, `b` is not suppressed because the marker is not at the end of the line, and `c` is suppressed even though the marker is followed by trailing whitespace. The comment applies to that line only, and to every finding on it, regardless of which check produced it.

.. note::
  Suppression is for the occasional exception. If you find yourself adding `#nolint` to many lines, the rule is probably wrong for your project: change the check's settings, or exclude the directory in the config instead.
