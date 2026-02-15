# systemd — the concierge

Concept:
systemd manages process lifecycle and isolation.

## v0 Decisions

- Dedicated service (User=slime)
- No Restart=always by default
- Socket owned by actuator (server)
- SLIME remains client-only

## Goal

The OS manages lifecycle.
SLIME does not implement internal resilience hacks.
