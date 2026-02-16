# EGRESS — SLIME v0 (CANON)

## 1. Purpose

EGRESS is the **sole actuation boundary** of SLIME.

SLIME does not execute actions.
SLIME emits **authorized effects**.
All real-world actuation happens **outside** SLIME.

This boundary is designed as a **law-layer**, not a protocol.
If the boundary cannot be crossed, **nothing happens**.

---

## 2. Scope

This document defines:
- the egress transport
- the payload format
- the failure semantics
- the isolation guarantees

This document explicitly does **not** define:
- actuator behavior or logic
- retries, acknowledgements, or feedback
- orchestration, scheduling, or monitoring

---

## 3. Transport Topology

- Transport: **Unix domain socket**
- Scope: **local machine only**
- Network exposure: **none**

### Role split (canonical)

- **Actuator**
  - Unix socket **server**
  - Owns and creates the socket
  - Listens for incoming payloads

- **SLIME**
  - Unix socket **client-only**
  - Connects to the socket
  - Writes payloads
  - Never listens
  - Never accepts connections

SLIME never exposes a socket.
SLIME never accepts inbound actuation requests.

---

## 4. Socket Path

Canonical path (non-configurable):

```
/run/slime/egress.sock
```

Properties:
- Hardcoded
- No environment variables
- No flags
- No fallback paths
- No `/tmp` variant in canonical spec

If the path does not exist or is not connectable, SLIME **must not run**.

---

## 5. Permissions & Isolation

- Socket permissions: `0660`
- Ownership:
  - User: `actuator`
  - Group: `slime-actuator`
- SLIME runs as user `slime`, member of `slime-actuator`

Properties:
- No network surface
- Local-only attack domain
- Actuator is replaceable without modifying SLIME

---

## 6. Payload Format (ABI)

Each authorized effect is encoded as **exactly 32 bytes**.

### Layout (little-endian)

| Offset | Size | Type | Field |
|------:|-----:|------|-------|
| 0     | 8    | u64  | domain_id |
| 8     | 8    | u64  | magnitude |
| 16    | 16   | u128 | actuation_token |

Constraints:
- Fixed size
- No headers
- No metadata
- No versioning
- No padding beyond 32 bytes

The payload is **opaque** to SLIME after emission.

---

## 7. Emission Rules

### Authorized decision

If the verdict is `AUTHORIZED`:
- SLIME attempts a single `write()` of the 32-byte payload.
- No acknowledgement is expected.
- No blocking on response.
- No retries.

### Impossible decision

If the verdict is `IMPOSSIBLE`:
- **No write occurs.**
- No signal is emitted.
- This is a non-event.

---

## 8. Failure Semantics (Fail-Closed)

### Boot-time (hard fail-closed)

At startup:
- If `/run/slime/egress.sock` is missing
- OR cannot be connected

→ **SLIME terminates immediately (`exit(1)`)**

SLIME must never run in a state where actuation is impossible.

---

### Runtime (best-effort)

After successful startup:
- If a `write()` fails (socket closed, reset, etc.)
  - The effect is silently dropped
  - No retry
  - No log explaining the failure
  - No state change

This preserves:
- no feedback
- no adaptation
- no escalation

---

## 9. Feedback Prohibition

SLIME must never receive:
- acknowledgements
- execution status
- error codes
- metrics
- timing signals

Any feedback channel would constitute learning.
Learning enables circumvention.
Circumvention violates the law-layer.

---

## 10. Non-Goals

EGRESS is **not**:
- a messaging system
- a reliability layer
- a workflow engine
- a control loop
- a monitoring interface

EGRESS exists solely to emit **authorized effects** into the world.

---

## 11. Canonical Principle

> **If SLIME cannot act, nothing acts.**

This is not an error condition.
This is the law.

---

**Document Status:** Canonical v0
**Immutability:** This specification is sealed. Changes require a new version.
