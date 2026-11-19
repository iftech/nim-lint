type BeforeError* = object
  secret: string

let invalidValue: int = "not an integer" #nolint

type AfterError* = distinct int
type IgnoredType* = object #nolint
  secret: string
