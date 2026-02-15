---

# SLIME v0 — Deployment Package Specification

**Status:** IMPLEMENTATION FRAME  
**Role:** Physical delivery of sealed canon  
**Scope:** Enterprise deployment artifact ("valise de transport")

---

## 1. Package Objectives

The SLIME v0 deployment package must enable an enterprise to:

1. **Install SLIME** in under 10 minutes
2. **Redirect existing systems** through SLIME without code changes
3. **Observe enforcement** via read-only dashboard
4. **Never access AB-S** directly or indirectly

The package is **hermetic, sealed, and non-configurable**.

---

## 2. Delivery Formats

SLIME v0 is distributed in **three equivalent formats**:

### 2.1 Docker Container (Primary)

```
slime-v0:latest
```

**Properties:**
- Single container image
- AB-S compiled and sealed inside
- No environment variables
- No volume mounts for configuration
- Exposed ports: 8080 (ingress), 8081 (dashboard)

**Distribution:**
- Docker Hub: `syfcorp/slime-v0:latest`
- SHA256 manifest pinned
- Signature verification required

---

### 2.2 Binary (Linux x86_64)

```
slime-v0-linux-x86_64
```

**Properties:**
- Static binary (no dynamic linking)
- AB-S embedded
- No config files read
- Runs as single process

**Distribution:**
- GitHub Releases
- SHA256 checksum provided
- GPG signature verification

---

### 2.3 Virtual Appliance (OVA)

```
slime-v0-appliance.ova
```

**Properties:**
- Minimal Linux VM (Alpine-based)
- SLIME binary pre-installed
- Auto-starts on boot
- Network bridge for ingress/egress
- Read-only filesystem for SLIME

**Distribution:**
- Direct download
- SHA256 verification
- VMware/VirtualBox compatible

---

## 3. Package Contents (Internal Structure)

Regardless of format, the package contains:

```
slime-v0/
├── bin/
│   └── slime-runtime          # Single executable
├── lib/
│   └── libabs-sealed.a        # AB-S Phase 7.0 (statically linked)
├── web/
│   └── dashboard.html         # Read-only dashboard UI
├── docs/
│   ├── INSTALL.md             # Installation instructions
│   ├── INTEGRATION.md         # System integration guide
│   └── OPERATIONS.md          # Operational runbook
└── verification/
    ├── MANIFEST.sha256        # Package integrity
    └── CANON_HASH.txt         # AB-S Phase 7.0 commit hash
```

**Critical:** No `config/` directory. No `.env` files. No tunables.

---

## 4. Installation Procedure

### 4.1 Docker Installation

```bash
# Pull verified image
docker pull syfcorp/slime-v0:latest

# Verify signature
docker trust inspect syfcorp/slime-v0:latest

# Run (no configuration)
docker run -d \
  --name slime-v0 \
  -p 8080:8080 \
  -p 8081:8081 \
  -v /run/slime:/run/slime \
  --restart unless-stopped \
  syfcorp/slime-v0:latest

# Verify running
curl http://localhost:8081/health
```

**Expected output:**
```json
{
  "status": "STABLE",
  "ab_core": "SEALED",
  "version": "v0.1.0"
}
```

**Note:** The volume mount `/run/slime` exposes the egress socket to the host for actuator connection.

---

### 4.2 Binary Installation

```bash
# Download and verify
curl -LO https://releases.syfcorp.io/slime-v0-linux-x86_64
curl -LO https://releases.syfcorp.io/slime-v0-linux-x86_64.sha256
sha256sum -c slime-v0-linux-x86_64.sha256

# Make executable
chmod +x slime-v0-linux-x86_64

# Run as service (systemd example)
sudo cp slime-v0-linux-x86_64 /usr/local/bin/slime
sudo systemctl enable slime.service
sudo systemctl start slime.service
```

---

### 4.3 Virtual Appliance Installation

```bash
# Import OVA
vboxmanage import slime-v0-appliance.ova

# Start VM
vboxmanage startvm "SLIME-v0" --type headless

# Access via network bridge
# Ingress: http://VM_IP:8080
# Dashboard: http://VM_IP:8081
```

---

## 5. System Integration

### 5.1 Integration Pattern

```
┌─────────────────────┐
│  Existing System    │
│  (AI, Agent, Code)  │
└──────────┬──────────┘
           │
           │ HTTP POST /action
           ▼
┌─────────────────────┐
│     SLIME v0        │
│  ┌───────────────┐  │
│  │  AB-S Sealed  │  │
│  └───────────────┘  │
└──────────┬──────────┘
           │
           │ Authorized actuation only
           ▼
┌─────────────────────┐
│       World         │
│  (APIs, Hardware)   │
└─────────────────────┘
```

---

### 5.2 Action Request Format

**Endpoint:** `POST http://localhost:8080/action`

**Request Body:**
```json
{
  "domain": "string",
  "magnitude": number,
  "payload": "opaque_base64"
}
```

**Response (Authorized):**
```json
{
  "status": "AUTHORIZED",
  "effect_id": "uuid"
}
```

**Response (Blocked):**
```json
{
  "status": "IMPOSSIBLE"
}
```

**Critical:**
- No error codes
- No retry headers
- No explanation fields
- HTTP 200 for both cases

---

### 5.3 Egress Interface

SLIME delivers authorized effects via a **fixed Unix domain socket**.

**Socket path (hardcoded):** `/run/slime/egress.sock`

**Properties:**
- Type: Unix domain socket (stream)
- Permissions: owner `slime`, group `slime`, mode `0660`
- No configuration, no alternatives
- Created by SLIME on startup
- Environment must connect and listen

**Egress payload (binary):**
- `AuthorizedEffect` structure (opaque binary blob)
- Single write per effect
- Ordering preserved
- No framing, no protocol wrapper

**Critical:**
- SLIME writes authorized effects exactly once
- No retries on write failure
- If socket unavailable, effect is dropped (fail-closed)
- `Impossibility` produces no write (terminal non-event)

---

### 5.4 Actuator Bridge Implementation

The environment must implement an **actuator bridge** that connects to SLIME's egress socket.

**Example (Python):**
```python
import socket
import struct

# Connect to SLIME egress socket
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect('/run/slime/egress.sock')

while True:
    # Read AuthorizedEffect (24 bytes: domain_id + magnitude + actuation_token)
    data = sock.recv(24)
    if not data:
        break
    
    domain_id, magnitude, token = struct.unpack('<QQQ', data)
    
    # Perform mechanical actuation
    perform_actuation(domain_id, magnitude, token)

sock.close()
```

**Example (C):**
```c
#include <sys/socket.h>
#include <sys/un.h>
#include <stdint.h>

typedef struct {
    uint64_t domain_id;
    uint64_t magnitude;
    __uint128_t actuation_token;
} AuthorizedEffect;

int main() {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    
    struct sockaddr_un addr = {
        .sun_family = AF_UNIX,
        .sun_path = "/run/slime/egress.sock"
    };
    
    connect(fd, (struct sockaddr*)&addr, sizeof(addr));
    
    AuthorizedEffect effect;
    while (read(fd, &effect, sizeof(effect)) == sizeof(effect)) {
        // Perform actuation
        actuate(effect.domain_id, effect.magnitude);
    }
    
    close(fd);
    return 0;
}
```

**Critical:**
- Actuator bridge runs **outside SLIME**
- Bridge receives binary `AuthorizedEffect` structures
- Bridge implements **mechanical actuation only**
- No feedback to SLIME (one-way flow)
- If bridge fails, effects are dropped (fail-closed)

---

## 6. Dashboard Access

**URL:** `http://localhost:8081`

**Display:**
```
┌─────────────────────────────────────┐
│  SLIME v0 — Observation Dashboard   │
├─────────────────────────────────────┤
│  Status: STABLE                     │
│  AB-S Core: SEALED                  │
│                                     │
│  Read-only observation interface    │
│  No controls, no configuration      │
└─────────────────────────────────────┘
```

**Features:**
- Auto-refresh display
- No buttons
- No sliders
- No configuration panel
- Read-only log stream (append-only)

**Critical:** Dashboard is for observation only. It provides no controls and cannot influence execution.

---

## 7. Operational Runbook

### 7.1 Normal Operation

**What operators see:**
- Dashboard shows STABLE
- Actions pass through
- Some actions blocked (normal)

**Operator actions:**
- **None required**
- Observe only
- Do not intervene

---

### 7.2 SATURATED State

**Indicator:**
```
State: [██████████] SATURATED
```

**Meaning:**
- AB-S capacity approaching limit
- More actions being blocked
- System approaching thermodynamic ceiling

**Operator actions:**
- **Observe**
- Do not attempt to "fix"
- This is structural limit enforcement working correctly
- Upstream system must reduce action rate

**What NOT to do:**
- Do not restart SLIME
- Do not modify configuration (there is none)
- Do not bypass SLIME

---

### 7.3 SEALED State

**Indicator:**
```
State: [XXXXXXXXXX] SEALED
```

**Meaning:**
- AB-S has entered terminal saturation
- No further actions will be authorized
- System has reached absolute thermodynamic limit

**Operator actions:**
- **SLIME must be replaced**
- Shutdown current instance
- Deploy fresh SLIME instance
- Do not attempt repair
- Do not attempt reset

**Critical:** There is no "unseal" operation. SEALED is terminal.

---

### 7.4 Failure Modes

**SLIME does not fail.**

If the process crashes:
- No actions are authorized (fail-closed)
- Restart from package
- State does not persist across restarts
- Each instance starts fresh

**Network failure:**
- Ingress unavailable → no actions accepted
- Egress unavailable → authorized effects dropped
- Dashboard unavailable → no observation (but execution continues)

All failures are **fail-closed**.

---

## 8. Health Check

SLIME provides a minimal health check endpoint on the dashboard port.

```
GET http://localhost:8081/health
```

**Healthy response:**
```json
{
  "status": "ok"
}
```

**Purpose:** Binary liveness check for process monitoring.

**Does not indicate:**
- AB-S state (STABLE/SATURATED/SEALED)
- Capacity levels
- Action metrics

**For operational observation, use the dashboard web interface at `http://localhost:8081/`**

---

## 9. Logging

**Log destination:** `stdout` (container/systemd journal)

**Log format:** JSON Lines

**Example:**
```json
{"ts":"2026-02-07T10:23:45Z","level":"INFO","event":"action_received","domain":"payments"}
{"ts":"2026-02-07T10:23:45Z","level":"INFO","event":"action_authorized","effect_id":"a1b2c3"}
{"ts":"2026-02-07T10:23:46Z","level":"INFO","event":"impossibility","domain":"payments"}
```

**Critical:**
- Logs contain no payloads
- Logs contain no semantic explanations
- Logs are append-only observation
- Logs do not influence execution

---

## 10. Security Considerations

### 10.1 Network Binding

**SLIME binds to localhost (127.0.0.1) only.**

**Fixed bind addresses:**
- Ingress: `127.0.0.1:8080`
- Dashboard: `127.0.0.1:8081`

**Not accessible from remote hosts by default.**

**If remote access is required**, use external infrastructure:
- Reverse proxy: nginx, Caddy, HAProxy with authentication
- SSH tunnel: `ssh -L 8080:localhost:8080 -L 8081:localhost:8081 server`
- VPN: Access server's localhost through VPN
- API Gateway: AWS API Gateway, Kong, etc.

**Do not:**
- Modify SLIME to bind to 0.0.0.0
- Expose ports directly to networks
- Allow unauthenticated remote access
- Run multiple SLIME instances sharing state

---

### 10.2 Cryptographic Verification

**On installation:**
```bash
# Verify package signature
gpg --verify slime-v0.sig slime-v0-linux-x86_64

# Verify AB-S commit hash
cat /opt/slime/verification/CANON_HASH.txt
# Expected: 07e501b05b87d1fed647e156f8b7929ab073ce7e
```

**Runtime verification:**
```bash
curl http://localhost:8081/version
```

**Response:**
```json
{
  "slime_version": "v0.1.0",
  "ab_core_hash": "07e501b05b87d1fed647e156f8b7929ab073ce7e",
  "canon_sealed": true
}
```

---

## 11. Upgrade Policy

**SLIME v0 is not upgradeable.**

To deploy a newer version:
1. Deploy new SLIME instance
2. Redirect traffic to new instance
3. Shutdown old instance

**Critical:**
- No in-place upgrades
- No state migration
- No configuration transfer
- Each instance is hermetic

---

## 12. Support & Troubleshooting

### 11.1 Common Questions

**Q: Can I configure the capacity threshold?**  
**A:** No. AB-S thermodynamic parameters are sealed at compile time.

**Q: Can I see why an action was blocked?**  
**A:** No. SLIME provides no explanations. Only observation: authorized or impossible.

**Q: Can I override a blocked action?**  
**A:** No. Impossibility is structural and non-negotiable.

**Q: Can I tune SLIME for my workload?**  
**A:** No. SLIME has no tunables. If your workload exceeds capacity, reduce action rate upstream.

**Q: What if I need to debug integration?**  
**A:** Observe dashboard metrics. Check action request format. Verify egress webhook. Do not attempt to inspect AB-S.

---

### 11.2 Diagnostic Checklist

**Symptom:** Actions not being authorized

**Check:**
1. Dashboard shows STABLE (not SATURATED/SEALED)
2. Action request format matches specification
3. Egress webhook is reachable
4. No network issues between components

**If all checks pass and actions still blocked:**  
This is correct behavior. The actions are structurally impossible.

---

## 13. Package Metadata

**Version:** v0.1.0  
**AB-S Core:** Phase 7.0 (commit `07e501b0`)  
**Build Date:** 2026-02-07  
**License:** SYFCORP Proprietary  
**Support:** enterprise@syfcorp.io

---

## 14. Installation Verification Checklist

After installation, verify:

- [ ] SLIME process running
- [ ] Dashboard accessible at `:8081`
- [ ] Health check returns `STABLE`
- [ ] AB-S core shows `SEALED`
- [ ] Version endpoint shows correct canon hash
- [ ] Test action request succeeds (format validation)
- [ ] Egress webhook receives authorized effects
- [ ] Dashboard metrics updating

**If all checks pass:** SLIME v0 is operational.

---

## 15. Non-Negotiable Constraints

**The following are structural and cannot be changed:**

- No configuration files
- No runtime parameters
- No tuning modes
- No debug flags
- No admin overrides
- No inspection APIs
- No state persistence
- No retry logic
- No fallback paths
- No "safe mode"

Any request to add these features **violates canon**.

---

**END — SLIME v0 DEPLOYMENT SPECIFICATION**

---
