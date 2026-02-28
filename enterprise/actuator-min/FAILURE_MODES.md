# Failure Modes — Actuator-Min

## Read Timeout

If client connects but does not send 32 bytes within 2 seconds:

→ connection dropped
→ no log entry

---

## Partial Payload

If less than 32 bytes are received:

→ connection dropped
→ no log entry

---

## Log Write Failure

If `/var/log/slime-actuator/events.log` cannot be opened or written:

→ event silently dropped
→ actuator continues

---

## Socket Removal / Restart

If the socket is removed externally:

- SLIME will fail on next write.
- SLIME is responsible for fail-closed behavior.

Actuator does not attempt self-recovery beyond accepting new connections.
