# SLIME — Egress (Definition v0)

## Purpose

The egress is the mechanical bridge between an AUTHORIZED verdict and a real effect.

## v0 Rules

- Client-only (SLIME never listens)
- Fail-closed (missing socket → SLIME must exit)
- Exactly 32 bytes of AuthorizedEffect
- No retry, no fallback, no internal queue

## Semantics

- AUTHORIZED → 32-byte payload written to socket
- IMPOSSIBLE → no signal (terminal non-event)
