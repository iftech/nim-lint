## Demonstrates the one audit_logs.py rule this linter does not implement:
## "potentially unbounded log field must use shortLog". Catching it needs the
## field's *type*, which a parse-only AST does not carry.

type Payload* = object
  body*: string

proc logPayload(data: string, payload: Payload) =
  # audit_logs.py flags both of these; this linter cannot.
  trace "unbounded string field", data = data
  trace "unbounded object field", record = payload
