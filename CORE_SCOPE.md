# SLIME — Core Scope

**Status:** Normative
**Purpose:** Define the canonical boundary of the SLIME law-layer core.

---

## Canonical Core

The following components constitute the **sealed law-layer**.
They are the sole authority for SLIME behavior.

| Path | Role |
|---|---|
| `specs/` | Law definition (Ingress ABI, Egress ABI, V1 Invariants) |
| `CANON.md` | Canonical statement — what SLIME is |
| `SLIME_FORMAL_CORE.md` | Formal model (A → E ∪ ∅) |
| `READING_RULES.md` | Normative interpretation constraints |

Everything outside this boundary is **noncanon**.

---

## Noncanon Components

All executable, deployable, and integration artifacts reside under `noncanon/`.
They demonstrate the **form** of SLIME but do not define the **law**.

| Path | Role |
|---|---|
| `noncanon/implementation_bundle/` | Reference runner (stub AB-S), actuator dummy, systemd units |
| `noncanon/enterprise/` | Production guidance, actuator implementations, dashboard, AVP suite |
| `noncanon/deploy/` | Deployment tooling, boot proof scripts |

Noncanon code may evolve independently. It provides **zero structural guarantees** without a sealed AB-S core.

See `CONFORMANCE.md` for the full divergence matrix.

---

## Supporting Documents (Non-Normative)

These documents explain the core but do not define it.

| Path | Role |
|---|---|
| `ARCHITECTURE.md` | Module structure and execution flow |
| `ARCHITECTURE_SECURITY_MODEL.md` | Structural security model |
| `CONFORMANCE.md` | Canon vs noncanon divergence matrix |
| `FULL_STACK_CONFORMANCE.md` | Cross-layer integration contract (Gate/Shield/AB/SLIME) |
| `INTEGRATION_PRIMER.md` | Correct integration model |
| `INTERPRETATION_GUIDE.md` | Common misinterpretations addressed |

---

## Boundary Principle

```
CANONICAL CORE          NONCANON
specs/                  noncanon/implementation_bundle/
CANON.md                noncanon/enterprise/
SLIME_FORMAL_CORE.md    noncanon/deploy/
READING_RULES.md        notes/
```

The core defines **what is structurally possible**.
Noncanon components decide **how authorized effects are used**.

This separation is **logical, not structural**: the repository remains unified.
The canonical security perimeter remains explicitly defined.

---

## Invariant

> If it is not listed under Canonical Core, it is not the law.
> If it contradicts `specs/`, it is wrong — not the spec.

---

**END — SLIME CORE SCOPE**
