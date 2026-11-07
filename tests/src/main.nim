import asyncdispatch

const
  invalid = 42
  kValid = 123

var
  a: int
  ok: int #nolint
  b = 5 #nolint because reasons
  c = 6 #nolint   

proc strings() =
  echo "#nolint"
  echo "a #nolint b"

