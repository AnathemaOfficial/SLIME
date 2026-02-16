# FAILURE_MODES (NON-CANON)

Failure behavior reference for SLIME v0 + external actuator.
This is **NON-CANON** implementation documentation.

## SLIME v0 (runner) — fail-closed invariants

### F1 — missing egress socket on boot

Condition:
- `/run/slime/egress.sock` does not exist

Behavior:
- slime-runner **must exit(1)** (service fails hard)

Rationale:
- never run in a state where authorized effects cannot be emitted deterministically.

### F2 — egress write failure at runtime

Condition:
- socket disappears, permission revoked, write fails

Behavior:
- drop silently (non-event)
- no retries
- no alternate outputs

Rationale:
- avoid feedback channels and keep the law-layer non-interactive.

### F3 — malformed ingress JSON

Behavior:
- strict parse failure -> request rejected (IMPOSSIBLE / error per spec)

Rationale:
- schema-locked parsing; no permissive behavior.

### F4 — dashboard availability

Dashboard is read-only.
If unavailable:
- no effect on decision/egress.

Rationale:
- dashboard must not be an operational dependency.

## Actuator — recommended failure posture (NON-CANON)

### A1 — payload not 32 bytes

Behavior:
- drop
- optional non-semantic log

### A2 — unknown domain_id

Behavior:
- drop (non-event)

### A3 — action handler fails

Behavior:
- actuator may log locally
- MUST NOT feed any signal back into SLIME

### A4 — restart / socket recreation

Behavior:
- actuator recreates `/run/slime/egress.sock` on startup
- ensure permissions + group are restored

## Cross-service ordering

- actuator should start before slime
- if actuator crashes after slime is running:
  - SLIME remains fail-closed at point of effect (writes drop)
  - external effects cease
