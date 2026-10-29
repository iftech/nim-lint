proc foo*( #nolint
    veryLongArgumentName: string, #nolint
    anotherLongArgumentName: string,
    andAnotherLongOne: string,
): string {.gcsafe.} =
  discard

var
  ok = 1 #nolint
  x = 2
  y = 3

proc strings() =
  echo "#nolint"
  echo "a #nolint b"
