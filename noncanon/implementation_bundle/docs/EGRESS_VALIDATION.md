# EGRESS_VALIDATION (NON-CANON)

Validation procedure for SLIME v0 egress.
This is **NON-CANON** implementation guidance.

## Goal

Prove that an authorized request produces an exact **32-byte** payload on the egress socket.

## Preconditions

- actuator is running and owns `/run/slime/egress.sock`
- slime-runner service is running (client-only)
- ingress endpoint is reachable locally:
  - `http://127.0.0.1:8080/health`
  - `http://127.0.0.1:8080/action`

## Validation A — socket presence + permissions

```bash
ls -la /run/slime
stat /run/slime/egress.sock
```

Expected:

- socket exists
- owner/group match the deployment plan (e.g. actuator:slime-actuator)
- mode 0660 (or stricter)

## Validation B — hexdump capture (example)

In a terminal, listen on the socket (actuator side) and dump payloads.
Example using `socat`:

```bash
sudo socat - UNIX-RECV:/run/slime/egress.sock,unlink-close,fork | hexdump -C
```

NOTE: Your real actuator will normally be the socket server.
This capture method is for **testing only**.

## Validation C — trigger an action

```bash
curl -sS -X POST http://127.0.0.1:8080/action \
  -H "Content-Type: application/json" \
  -d '{"domain":"test","magnitude":10,"payload":""}'
```

Expected:

- SLIME returns `AUTHORIZED` or `IMPOSSIBLE`
- If `AUTHORIZED`, the hexdump shows **exactly 32 bytes** emitted.

## Decode check (manual)

Confirm the 32 bytes map to:

- u64 domain_id (LE)
- u64 magnitude (LE)
- u128 actuation_token (LE)

A quick sanity check:

- magnitude bytes should reflect the posted magnitude (if your domain mapping encodes it).

## Fail-closed checks

1. Stop actuator:

```bash
sudo systemctl stop actuator.service
sudo systemctl restart slime.service
```

Expected:

- slime-runner fails to start (exit(1)) because socket missing.

2. Remove socket perms:

```bash
sudo chmod 000 /run/slime/egress.sock
```

Expected:

- authorized requests do not produce effects (writes fail -> dropped).
