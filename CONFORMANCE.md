# SLIME v0 — Conformance Matrix

**Status:** Reference (non-canon)
**Purpose:** Clarify intentional divergences between canon specifications, the slime-runner harness, and the enterprise deployment.

---

## Authority Rule

> **Canon = specs/ exclusively.**
> Noncanon code is a harness or deployment tool.
> If runner or deploy diverges from specs/, the runner/deploy is wrong — not the spec.

---

## Conformance Table

| Aspect | Canon (specs/) | slime-runner (noncanon) | Enterprise Deploy (noncanon) |
|---|---|---|---|
| **Ingress: format errors** | 400/413/500 with `error` + `message` fields | Always returns HTTP 200 + `IMPOSSIBLE` (flattened) | Same as runner |
| **Ingress: impossibility** | HTTP 200 + `{"status":"IMPOSSIBLE"}` | HTTP 200 + `{"status":"IMPOSSIBLE"}` | Same |
| **Ingress: payload (base64)** | Required field, max 64KB decoded, passed to AB-S | Ignored (parser reads `domain` + `magnitude` only) | Same as runner |
| **AB-S Core** | Sealed, opaque, compile-time law, non-inspectable | Real AB-S engine via `resolve_action()` with compile-time CoreSpec constants (Phase 6.3) | Same as runner |
| **Egress: ABI** | 32 bytes LE: u64 + u64 + u128 | 32 bytes LE: u64 + u64 + u128 | Same |
| **Egress: socket ownership** | Actuator owns socket (server/listener); SLIME connects as client | SLIME connects as client (fail-closed if absent) | `actuator.service` creates socket; `slime.service` requires it |
| **Egress: socket path** | `/run/slime/egress.sock` (hardcoded) | `/run/slime/egress.sock` | Same |
| **Egress: socket perms** | `0660`, owner `actuator`, group `slime-actuator` | Best-effort `0660` by actuator-min | Actuator creates socket; systemd `RuntimeDirectory` ensures `/run/slime` exists; permissions enforced by actuator + unit config |
| **Domain normalization** | `hash64(domain) & 0xFFFFFFFF` (32-bit mask) | Static compile-time table: string → `Domain(u16)`. Unknown domains → IMPOSSIBLE. No hash. | Same as runner |
| **Saturation states** | SATURATED, then SEALED (terminal) | Not modeled (per-request budget prevents cross-request depletion) | Not modeled |
| **Backpressure** | Kernel buffer fills, writes block, no bypass | Same (inherited from OS) | Same |
| **Dashboard** | N/A (out of law scope) | Not implemented | Read-only on port 8081 if deployed (`noncanon/enterprise/dashboard`) |
| **Fail-closed boot** | If socket absent at startup, SLIME exits | Exits with code 1 | `ExecStartPre` polls for socket, fails after timeout |

---

## Intentional Divergences

The following divergences are **intentional** and expected in the noncanon harness:

1. **Flattened error handling** — The runner returns `IMPOSSIBLE` for both format errors and true impossibilities. Canon distinguishes these (4xx vs 200). This simplification is acceptable in a test harness but must not be treated as conformant behavior.

2. **No payload processing** — The runner ignores the `payload` field entirely. Canon requires base64 decoding and size validation before passing to AB-S.

3. **No saturation/sealed states** — The runner does not model cumulative capacity exhaustion across requests. Canon defines terminal SEALED state when the system can no longer authorize actions. The runner uses a fresh per-request Budget, so capacity accounting exists within a single request but no cross-request depletion occurs.

4. **Domain table vs hash** — Canon specifies `hash64(domain) & 0xFFFFFFFF` (32-bit mask) for domain normalization. The runner uses a static compile-time table mapping domain strings to `Domain(u16)`. This is a deliberate choice: table-based resolution is more auditable than hash-based. The mapping is sealed at compile time and unknown domains are structurally impossible.

---

## Resolved Divergences

The following divergences existed in earlier runner versions and have been resolved:

1. **Stub AB-S** — The runner previously used a trivial decision function (`domain == "test" && magnitude > 0`) that demonstrated the *form* but not the *law*. The runner now delegates authorization to the real Anathema-Breaker core via `resolve_action(Action<RZ>, &mut Budget)`. Budget is constructed fresh per request (V1 statelessness preserved). No mutable policy state persists between requests. No internal impossibility semantics are exposed externally. Resolved in commit `d958996`.

---

## Deployment Warning: Runner ≠ Full Canon

The slime-runner harness now embeds the real AB-S engine but does not yet implement the full canon specification.

**Remaining gaps:**

- Ignores payload entirely (no validation, no size check)
- Flattens all errors to IMPOSSIBLE (no distinction between format errors and true impossibilities)
- No cross-request saturation model (no SEALED terminal state)
- No FirePlank-Guard binary integrity verification

**To achieve full SLIME canon compliance:**

1. ~~Replace the stub AB-S with a sealed, compile-time law~~ **Done** (Phase 6.3, commit `d958996`)
2. Implement full ingress validation (payload base64, size limits, HTTP status codes per canon)
3. Deploy FirePlank-Guard (ACTUATOR_TCB.md) for binary integrity verification
4. Verify conformance against `specs/` — not against the runner

---

## How to Read This Document

- If you are **auditing SLIME**, use `specs/` as the sole authority.
- If you are **testing the harness**, expect the divergences listed above.
- If you are **deploying enterprise**, the systemd model in `noncanon/enterprise/` is the reference.
- If you are **evaluating security posture**, the runner with real AB-S provides structural authorization guarantees. Full conformance additionally requires payload validation and FirePlank-Guard integrity.

**No divergence listed here modifies the canon.**

---

**END — SLIME v0 CONFORMANCE MATRIX**
