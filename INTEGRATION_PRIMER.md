# INTEGRATION_PRIMER — Correct Integration Model

SLIME v0 is not integrated like a security tool.

You do not configure it.
You do not tune it.
You do not extend it internally.

You route your system’s point of effect through it.

---

## The Only Valid Architecture

System → SLIME Ingress → Binary Verdict → Unix Socket Egress → External Actuator → World

SLIME does not integrate with business logic.
It integrates with actuation.

---

## Step 1 — Identify the Point of Effect

Route only real-world effects, such as:

- payment execution
- deployment action
- actuator command
- database mutation
- external API trigger

Do not route your entire system.

---

## Step 2 — Emit a Declarative ActionRequest

No branching.
No adaptive logic.
No retry.
No explanation.

If SLIME returns IMPOSSIBLE:

Stop.

There is no fallback.

SLIME does not prevent upstream retry logic. It only governs effect.

---

## Step 3 — Respect the Binary Verdict

SLIME outputs:

- AUTHORIZED
- IMPOSSIBLE (non-event)

Do not expose refusal details.
Do not generate reason codes.
Do not optimize based on refusal.

---

## Step 4 — External Actuator

The actuator:

- owns the Unix socket server
- receives the fixed-size binary payload
- maps it to a real-world effect

SLIME is client-only on egress.
If egress fails, SLIME fail-closes.


---

## Interface Constraints

Ingress and Egress are schema-locked and fail-closed.

- ActionRequests must conform to a strict schema.
- Any malformed or undefined request is rejected.
- Egress produces no partial effects.
- If actuation fails, nothing occurs.

---

## Frequently Misunderstood

### “I have an AI agent. How do I plug it in?”

You do not plug the agent into SLIME.
You route the agent’s actuation call through SLIME.

### “How do I protect my payment system?”

You do not protect it with rules.
You define which effects can structurally exist.

Everything else becomes a non-event.

### “Can I deploy this as a cloud microservice?”

No.

SLIME v0 is local-only and machine-contained.