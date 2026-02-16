# ACTUATOR_ARCHITECTURE (NON-CANON)

This document describes a reference actuator design for SLIME v0.
It is **NON-CANON** and exists as an implementation bundle only.

## Roles (hard separation)

- **slime-runner**: Unix socket **client-only**.
  - Sends exactly 32 bytes per authorized action.
  - If socket missing on boot -> **exit(1)** (fail-closed).
  - If write fails -> **drop silently** (fail-closed).

- **actuator**: Unix socket **server/owner**.
  - Owns and binds the socket path: `/run/slime/egress.sock`
  - Receives exactly 32 bytes per message.
  - Decodes the payload and triggers *external effects* (outside SLIME).

This separation enforces: **identity != capacity to act** (law-layer).
SLIME never executes effects. It only emits an authorized payload.

## Socket contract

Path:
- Canonical: `/run/slime/egress.sock`

Permissions (example):
- Owner: `actuator`
- Group: `slime-actuator`
- Mode: `0660`

The actuator must create the directory:
- `/run/slime` (tmpfs runtime dir)

## Payload ABI (fixed)

`AuthorizedEffect` is exactly **32 bytes** little-endian:

- `domain_id`        : u64 (bytes 0..7)
- `magnitude`        : u64 (bytes 8..15)
- `actuation_token`  : u128 (bytes 16..31)

No variable-length data. No framing. No headers.

## Operational expectations

- The actuator must be started **before** slime-runner.
- The actuator must recreate the socket on boot.
- The actuator must treat malformed or unexpected payloads as non-events:
  - drop
  - log (optional, non-semantic)

## Minimal actuator loop (concept)

1. bind `/run/slime/egress.sock`
2. accept datagrams/stream writes (depending on implementation)
3. read exactly 32 bytes
4. decode fields
5. route `(domain_id, magnitude)` to a local effect handler
6. consume/verify `actuation_token` according to local policy (NON-CANON)

## Non-goals

- SLIME does not provide retries, ACKs, metrics, or effect IDs.
- SLIME does not expose domain/action internals through logs.
- The actuator is not part of the canonical artifact.
