# Actuator-Min Architecture

## Purpose

`actuator-min` is the minimal, isolated execution sink for SLIME v0.

It receives authorized 32-byte effects over a Unix domain socket and logs them.
It does not send any feedback to SLIME.

---

## Trust Boundary

SLIME (runner) → Unix socket → actuator-min

- SLIME must succeed in connecting to `/run/slime/egress.sock` at boot.
- If connection fails → SLIME exits (fail-closed).
- Actuator never communicates back.

---

## Socket Model

Path: `/run/slime/egress.sock`  
Permissions: `0660`  
Directory: `/run/slime` (0750)

Ownership model (recommended):
- User: actuator
- Group: slime-actuator
- SLIME runner belongs to `slime-actuator` group.

---

## Message Format

Exactly 32 bytes, little-endian:

| Offset | Size | Field |
|--------|------|-------|
| 0      | 8    | domain_id (u64 LE) |
| 8      | 8    | magnitude (u64 LE) |
| 16     | 16   | actuation_token (u128 LE) |

No framing.
No variable length.
No negotiation.

---

## Execution Model

- Single-threaded.
- Blocking accept loop.
- Per-connection read with 2-second timeout.
- `read_exact(32)` enforced.

---

## Design Invariants

- No `unsafe`.
- No dynamic configuration.
- No feedback channel.
- No retries to SLIME.
- No partial reads.
- No non-deterministic state.

---

## Failure Model

If:
- socket read fails
- timeout occurs
- log write fails

→ Event is silently dropped.

The actuator must never escalate state or signal back.
