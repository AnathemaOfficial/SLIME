# SLIME v0 — Implementation Bundle

**Status:** READY FOR BUILD  
**Date:** 2026-02-07  
**Target:** Production Linux deployment

---

## Bundle Contents

### Core Implementation

**main.rs** — SLIME runtime implementation
- Ingress: HTTP/1.1 strict parser, localhost:8080
- AB-S integration: Sealed FFI boundary
- Egress: Unix socket client, /run/slime/egress.sock
- Dashboard: Read-only HTML interface, localhost:8081
- Zero external dependencies (std only)

**dashboard.html** — Read-only observation interface
- Minimal, professional UI
- No controls, no configuration
- Canonical statement displayed

### Deployment Artifacts

**install.sh** — Automated installation script
- Binary verification (SHA256)
- AB-S core hash verification
- User/directory creation
- Systemd service installation

**slime.service** — Production-hardened systemd unit
- RuntimeDirectory management (/run/slime)
- UMask 0007 (socket permissions 0660)
- Security hardening (MemoryDenyWriteExecute, etc.)
- Resource limits (256M RAM, 50% CPU)

### Integration Examples

**actuator_bridge_example.py** — Python actuator bridge
- Connects to /run/slime/egress.sock
- Reads AuthorizedEffect structures (32 bytes)
- Demonstrates mechanical actuation pattern

---

## Build Instructions

### Prerequisites

```bash
rustc --version  # 1.75+
cargo --version
```

### Build Static Binary

```bash
# Install musl target
rustup target add x86_64-unknown-linux-musl

# Build
cargo build --release --target x86_64-unknown-linux-musl

# Verify static linking
ldd target/x86_64-unknown-linux-musl/release/slime
# Expected: "not a dynamic executable"

# Strip binary
strip target/x86_64-unknown-linux-musl/release/slime

# Check size
ls -lh target/x86_64-unknown-linux-musl/release/slime
# Expected: ~2-5MB
```

### Package Structure

```
slime-v0-linux-x86_64/
├── bin/
│   └── slime                  # Static binary
├── web/
│   └── dashboard.html
├── systemd/
│   └── slime.service
├── docs/
│   ├── QUICKSTART.md
│   ├── OPERATIONS.md
│   └── INTEGRATION.md
├── examples/
│   └── actuator_bridge_example.py
├── verification/
│   ├── CANON_HASH.txt         # 07e501b0...
│   └── SHA256SUMS
├── install.sh
└── README.txt
```

---

## Cargo.toml

```toml
[package]
name = "slime-runner"
version = "0.1.0"
edition = "2021"

[dependencies]
# Zero external dependencies - std only

[[bin]]
name = "slime"
path = "src/main.rs"

[profile.release]
opt-level = "z"        # Optimize for size
lto = true             # Link-time optimization
codegen-units = 1      # Single codegen unit for better optimization
panic = "abort"        # Smaller binary
strip = true           # Strip symbols
```

---

## Key Implementation Details

### Request Size Limit

Total HTTP request size: **16384 bytes** (16KB)
- Headers: ~512 bytes budget
- Body: ~15872 bytes maximum
- Enforced at ingress buffer level

### Base64 Handling

- RFC 4648 strict compliance
- Payload field required (may be empty string `""`)
- Empty string decodes to zero bytes (valid)
- Maximum decoded size: 65536 bytes (64KB)

### Schema Parsing

Exact JSON schema enforced:
```json
{"domain":"<string>","magnitude":<u64>,"payload":"<base64>"}
```

- No whitespace tolerance
- No field reordering
- No optional fields
- Separator validation (commas, quotes, braces)

### ABI Stability

`AB_S_Verdict` structure:
```rust
#[repr(C)]
pub struct AB_S_Verdict {
    pub is_ok: u8,       // 0 = false, 1 = true
    pub pad: [u8; 7],    // Explicit padding for alignment
    pub payload: [u8; 32],
}
```

### Socket Permissions

Egress socket created with:
- Path: `/run/slime/egress.sock`
- Owner: `slime` user
- Group: `slime` group
- Mode: `0660` (via UMask=0007)

Actuator bridge must:
- Run as user in `slime` group, OR
- Run as `slime` user

---

## Testing

### Smoke Test

```bash
# Start SLIME
./slime &

# Test health check
curl http://localhost:8081/health
# Expected: {"status":"ok"}

# Test action submission
curl -X POST http://localhost:8080/action \
  -H "Content-Type: application/json" \
  -d '{"domain":"test","magnitude":10,"payload":""}'
# Expected: {"status":"AUTHORIZED"} or {"status":"IMPOSSIBLE"}

# Test dashboard
curl http://localhost:8081/
# Expected: HTML response
```

### Invalid Request Tests

```bash
# Missing field
curl -X POST http://localhost:8080/action \
  -H "Content-Type: application/json" \
  -d '{"domain":"test","magnitude":10}'
# Expected: 400 Bad Request

# Invalid base64
curl -X POST http://localhost:8080/action \
  -H "Content-Type: application/json" \
  -d '{"domain":"test","magnitude":10,"payload":"not-base64!!!"}'
# Expected: 400 Bad Request

# Payload too large (>64KB decoded)
# Create 100KB base64 payload and test
# Expected: 413 Payload Too Large
```

---

## Deployment Checklist

- [ ] Build static binary
- [ ] Verify binary size (<10MB)
- [ ] Generate SHA256 checksum
- [ ] Create CANON_HASH.txt with AB-S commit
- [ ] Package all artifacts
- [ ] Test installation script
- [ ] Verify systemd service starts
- [ ] Test socket creation (/run/slime/egress.sock)
- [ ] Verify socket permissions (0660)
- [ ] Test actuator bridge connection
- [ ] Smoke test all endpoints
- [ ] Document any deviations from spec

---

## Canon Compliance

This implementation adheres to:
- CANON.md (sealed, audited 2026-02-07)
- ARCHITECTURE.md (sealed, audited 2026-02-07)
- INGRESS_API_SPEC.md (localhost binding, schema-locked)
- EGRESS_SOCKET_SPEC.md (fixed path, 0660 permissions)

**No configuration parameters.**  
**No runtime tunables.**  
**No feedback channels.**  
**Fail-closed on all failures.**

---

## Next Steps

1. Build binary
2. Run integration tests
3. Package distribution
4. Submit to KIMI for SEALABLE verification
5. After KIMI PASS: Tag `slime-v0-genesis`

---

**END — SLIME v0 IMPLEMENTATION BUNDLE**
