---

# SLIME v0 — Architecture

**Status:** CANON / IMPLEMENTATION FRAME  
**Scope:** v0 only (minimal, deployable, non-negotiable)

---

## Overview

SLIME v0 is a sealed execution environment that encloses a sealed enforcement engine (AB-S).
SLIME is the only surface visible to users and operators.

```

Existing System
↓
SLIME v0
↓
World
↓
(AB-S sealed internally)

```

---

## Fixed Modules (v0)

SLIME v0 is composed of four fixed modules. Nothing may be inserted inside v0.

### 1) Ingress
**Purpose:** Accept declarative actions from upstream systems.

**Properties:**
- Declarative input only (ActionRequest)
- Strict, bounded format
- No logic, no heuristics, no branching
- No semantic interpretation of intent

**Output:** `ActionRequest` (normalized, bounded)

---

### 2) AB-S Core (Embedded)
**Purpose:** Enforce structural impossibility at the point of effect.

**Properties:**
- Sealed engine (Phase 7.0)
- Opaque (no inspection)
- No configuration, no repair, no interface
- Produces only final verdicts

**Output:**
- `OK(AuthorizedEffect)`
- `Err(Impossibility)`

---

### 3) Egress
**Purpose:** Map authorized effects to mechanical actuation.

**Properties:**
- Fail-closed by construction
- No retries, no fallback paths
- No simulated success
- If actuation cannot occur, nothing occurs

**Output:** physical actuation or non-event

---

### 4) Dashboard (Read-Only)
**Purpose:** Observation-only surface for operators.

**Properties:**
- Read-only
- Displays passed vs blocked
- No controls, no tuning
- Must not influence execution

**Output:** observation only (no feedback into SLIME)

---

## Execution Rule

SLIME applies AB-S verdicts without negotiation:

- `OK(AuthorizedEffect)` → allow actuation
- `Err(Impossibility)` → non-event (terminal)

`Impossibility` is not an error and must never be treated as recoverable.

---

## Non-Goals (v0)

SLIME v0 must not include:
- policy engines or governance logic
- configuration modes
- adaptive thresholds or calibration
- retries / fallbacks / simulated success
- semantic logging or explainability surfaces
- any external signal influencing actuation

---

## Extension Rule

Future systems may wrap SLIME, deploy SLIME, or observe SLIME.

**Nothing may be inserted inside SLIME v0.**
```

