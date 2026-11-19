type
  Account* = object
    secret: string

  AccountId* = distinct int
  SafeAccount* = object
    secret: string

  SafeId* = distinct int
  GenericBox*[T] = object
    value: T

proc `$`*(account: SafeAccount): string =
  "<redacted account>"

func `$`*(id: SafeId): string =
  "<id>"

# An overload for a generic parameter is not a custom representation of Account.
proc `$`*[T: Account](account: T): string =
  "generic account"
