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
| **AB-S Core** | Sealed, opaque, compile-time law, non-inspectable | Stub: `domain == "test" && magnitude > 0` with hardcoded token | Same stub |
| **Egress: ABI** | 32 bytes LE: u64 + u64 + u128 | 32 bytes LE: u64 + u64 + u128 | Same |
| **Egress: socket ownership** | Actuator owns socket (server/listener); SLIME connects as client | SLIME connects as client (fail-closed if absent) | `actuator.service` creates socket; `slime.service` requires it |
| **Egress: socket path** | `/run/slime/egress.sock` (hardcoded) | `/run/slime/egress.sock` | Same |
| **Egress: socket perms** | `0660`, owner `actuator`, group `slime-actuator` | Best-effort `0660` by actuator-min | Actuator creates socket; systemd `RuntimeDirectory` ensures `/run/slime` exists; permissions enforced by actuator + unit config |
| **Domain normalization** | `hash64(domain) & 0xFFFFFFFF` (32-bit mask) | FNV-1a 64-bit hash; compares against `fnv1a64("test")`; does not apply 32-bit mask | Same as runner |
| **Saturation states** | SATURATED, then SEALED (terminal) | Not modeled | Not modeled |
| **Backpressure** | Kernel buffer fills, writes block, no bypass | Same (inherited from OS) | Same |
| **Dashboard** | N/A (out of law scope) | Not implemented | Read-only on port 8081 if deployed (`noncanon/enterprise/dashboard`) |
| **Fail-closed boot** | If socket absent at startup, SLIME exits | Exits with code 1 | `ExecStartPre` polls for socket, fails after timeout |

---

## Intentional Divergences

The following divergences are **intentional** and expected in the noncanon harness:

1. **Flattened error handling** — The runner returns `IMPOSSIBLE` for both format errors and true impossibilities. Canon distinguishes these (4xx vs 200). This simplification is acceptable in a test harness but must not be treated as conformant behavior.

2. **Stub AB-S** — The runner uses a trivial decision function (`domain == "test"`). This demonstrates the *form* (fail-closed + binary verdict + 32-byte egress) but not the *law* (sealed compile-time invariant).

3. **No payload processing** — The runner ignores the `payload` field entirely. Canon requires base64 decoding and size validation before passing to AB-S.

4. **No saturation/sealed states** — The runner does not model capacity exhaustion. Canon defines terminal SEALED state when the system can no longer authorize actions.

---

## Deployment Warning: Runner ≠ Canon

The slime-runner harness demonstrates the **form** of SLIME (binary verdict, 32-byte egress, fail-closed) but not the **law** (sealed compile-time invariant, full ABI compliance, payload validation).

**Deploying the runner as if it were a production SLIME instance is a governance failure, not a technical one.** The runner:

- Has no sealed AB-S core (stub function, not compile-time law)
- Ignores payload entirely (no validation, no size check)
- Flattens all errors to IMPOSSIBLE (no distinction between format errors and true impossibilities)
- Has no saturation model (no capacity limits, no SEALED terminal state)

**An organization that deploys the runner and claims SLIME compliance has zero structural guarantees.** The binary verdict form is present but the impossibility property is not enforced — the stub function can be changed at any time without detection.

**To achieve actual SLIME compliance:**

1. Replace the stub AB-S with a sealed, compile-time law (non-inspectable, non-modifiable)
2. Implement full ingress validation (payload base64, size limits, HTTP status codes per canon)
3. Deploy FirePlank-Guard (ACTUATOR_TCB.md) for binary integrity verification
4. Verify conformance against `specs/` — not against the runner

---

## How to Read This Document

- If you are **auditing SLIME**, use `specs/` as the sole authority.
- If you are **testing the harness**, expect the divergences listed above.
- If you are **deploying enterprise**, the systemd model in `noncanon/enterprise/` is the reference.
- If you are **evaluating security posture**, the runner alone provides **no security guarantee**. Only a fully conformant deployment with sealed AB-S and FirePlank-Guard integrity achieves the impossibility property.

**No divergence listed here modifies the canon.**

---

**END — SLIME v0 CONFORMANCE MATRIX**
