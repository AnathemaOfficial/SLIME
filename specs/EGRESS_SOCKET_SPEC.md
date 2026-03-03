# SLIME v0 — Egress Socket Specification

**Status:** CANON (v0)  
**Scope:** Linux-first, fixed wiring, zero configuration

---

## Overview

SLIME v0 delivers authorized effects to the environment via a **fixed Unix domain socket**.

The socket is the **only egress interface**.  
No network ports, no configuration, no alternatives.

---

## Fixed Endpoint

**Socket path:** `/run/slime/egress.sock`

**Properties:**
- Type: Unix domain socket (SOCK_STREAM)
- Owner: `actuator` user
- Group: `slime-actuator` group
- Permissions: `0660` (read/write owner and group)
- Created by the actuator bridge (server/listener)
- SLIME connects as client (fail-closed if socket absent)

**The socket path is hardcoded.**  
No environment variables, flags, or runtime parameters are allowed.

---

## Message Contract

### Payload Structure

SLIME writes binary `AuthorizedEffect` structures to the socket.

**C struct representation:**
```c
typedef struct {
    uint64_t domain_id;
    uint64_t magnitude;
    __uint128_t actuation_token;
} __attribute__((packed)) AuthorizedEffect;
```

**Size:** 32 bytes  
**Alignment:** Packed (no padding)  
**Byte order:** Little-endian (x86_64 native)

**Fields:**
- `domain_id` (8 bytes): Domain identifier
- `magnitude` (8 bytes): Action magnitude
- `actuation_token` (16 bytes): Authorization metadata token

**Note:** The `AuthorizedEffect` structure contains authorization metadata only.  
Payload data (if needed for actuation) must be managed by the actuator bridge separately.  
AB-S authorizes based on domain and magnitude, not payload content.

---

## Write Semantics

### Authorized Effects

When AB-S authorizes an action:
1. SLIME constructs `AuthorizedEffect` structure
2. SLIME writes 32 bytes to socket (single write call)
3. SLIME does not wait for acknowledgment
4. SLIME continues to next action

**Ordering:** Preserved (FIFO)  
**Buffering:** Kernel socket buffer (typically 64KB)  
**Framing:** None (fixed 32-byte messages). Readers must consume exactly 32 bytes per effect; partial reads are invalid.

### Impossibilities

When AB-S blocks an action (`Err(Impossibility)`):
- **No socket write occurs**
- No error is emitted
- No signal is sent  
- No observable side effect

Impossibility is a **terminal non-event**.

---

## Failure Modes

### Socket Unavailable at Startup

If `/run/slime/egress.sock` does not exist or cannot be connected to:
- SLIME fails to start
- Error logged to stdout/stderr
- Process exits with non-zero code

This is **fail-closed by construction**.

### Socket Disconnected During Operation

If the actuator bridge disconnects:
- SLIME continues accepting actions
- Authorized effects buffer in kernel socket buffer
- When buffer fills, writes block (backpressure)
- Ingress may block or time out depending on the HTTP server implementation
- No retry mechanism exists

**Critical:** SLIME does not bypass a failed socket. SLIME never reconnects the socket automatically. Connection lifecycle is entirely owned by the environment.

### Write Failure

If `write()` system call fails:
- The effect is **lost** and the connection state is undefined
- No retry or recovery mechanism exists
- No error propagation to ingress
- No fallback mechanism
- The environment is responsible for detecting the failure and re-establishing the actuator bridge if needed
- Dashboard may log write failure (observation only)

This is **fail-closed**.

---

## Environment Responsibilities

The environment must:

1. **Create actuator bridge** that listens on and owns `/run/slime/egress.sock` (SLIME connects as client)
2. **Read 32-byte `AuthorizedEffect` messages** from socket
3. **Map effect to actuation** based on domain_id and magnitude
4. **Perform mechanical actuation** in the world
5. **Handle disconnection** (reconnect logic is environment's responsibility)

**Payload handling:**
- `AuthorizedEffect` contains only authorization metadata (domain, magnitude, token)
- If actuation requires payload data, the actuator bridge must:
  - Maintain correlation between ingress actions and egress effects (e.g., via domain_id)
  - Store payload separately if needed
  - Or reconstruct actuation from domain_id + magnitude alone

SLIME guarantees:
- SLIME connects to the socket as a client at startup (fail-closed if absent)
- Every write is exactly 32 bytes
- Effects are written in order of authorization
- No writes occur for impossibilities
- Authorization token is present and populated by AB-S

---

## Implementation Examples

### Python Actuator Bridge

```python
import socket
import struct

SOCKET_PATH = '/run/slime/egress.sock'
EFFECT_SIZE = 32  # u64 + u64 + u128 = 32 bytes

def recv_exact(sock, n):
    """Read exactly n bytes from socket (loop until complete or EOF)."""
    buf = bytearray()
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            return None  # EOF — actuator disconnected
        buf.extend(chunk)
    return bytes(buf)

def actuator_bridge():
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(SOCKET_PATH)

    try:
        while True:
            # Read exactly 32 bytes (u64 + u64 + u128, little-endian packed)
            data = recv_exact(sock, EFFECT_SIZE)
            if data is None:
                break

            # Unpack AuthorizedEffect: domain_id (u64), magnitude (u64), actuation_token (u128)
            # u128 is serialized as two little-endian u64 values (low word first, high word second)
            domain_id, magnitude, token_lo, token_hi = struct.unpack('<QQQQ', data)
            actuation_token = token_lo | (token_hi << 64)

            # Perform actuation
            actuate(domain_id, magnitude, actuation_token)
    finally:
        sock.close()

def actuate(domain_id, magnitude, actuation_token):
    # Mechanical actuation logic
    print(f"Actuating domain {domain_id} with magnitude {magnitude}")

if __name__ == '__main__':
    actuator_bridge()
```

### C Actuator Bridge

```c
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define SOCKET_PATH "/run/slime/egress.sock"

typedef struct __attribute__((packed)) {
    uint64_t domain_id;
    uint64_t magnitude;
    __uint128_t actuation_token;
} AuthorizedEffect;

void actuate(AuthorizedEffect *effect) {
    printf("Actuating domain %lu with magnitude %lu\n",
           effect->domain_id, effect->magnitude);
    // Mechanical actuation implementation
}

int main() {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        perror("socket");
        return 1;
    }
    
    struct sockaddr_un addr = {
        .sun_family = AF_UNIX,
        .sun_path = SOCKET_PATH
    };
    
    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("connect");
        close(fd);
        return 1;
    }
    
    AuthorizedEffect effect;
    ssize_t n;
    
    while ((n = read(fd, &effect, sizeof(effect))) == sizeof(effect)) {
        actuate(&effect);
    }
    
    if (n < 0) {
        perror("read");
    }
    
    close(fd);
    return 0;
}
```

### Rust Actuator Bridge

```rust
use std::os::unix::net::UnixStream;
use std::io::Read;

const SOCKET_PATH: &str = "/run/slime/egress.sock";
const EFFECT_SIZE: usize = 32; // u64 + u64 + u128 = 32 bytes

#[repr(C, packed)]
struct AuthorizedEffect {
    domain_id: u64,
    magnitude: u64,
    actuation_token: u128,
}

fn actuate(effect: &AuthorizedEffect) {
    println!("Actuating domain {} with magnitude {}",
             effect.domain_id, effect.magnitude);
    // Mechanical actuation implementation
}

fn main() -> std::io::Result<()> {
    let mut stream = UnixStream::connect(SOCKET_PATH)?;
    let mut buffer = [0u8; EFFECT_SIZE];

    loop {
        // Read exactly 32 bytes (fail-closed on partial read / EOF)
        match stream.read_exact(&mut buffer) {
            Ok(_) => {
                let effect = unsafe {
                    std::ptr::read(buffer.as_ptr() as *const AuthorizedEffect)
                };
                actuate(&effect);
            }
            Err(_) => break,
        }
    }

    Ok(())
}
```

---

## Systemd Integration

SLIME and actuator bridge can run as separate systemd services:

**SLIME service:** `/etc/systemd/system/slime.service`
```ini
[Unit]
Description=SLIME v0
After=network.target

[Service]
Type=simple
User=slime
ExecStart=/usr/local/bin/slime
RuntimeDirectory=slime
RuntimeDirectoryMode=0755
UMask=0007
Restart=always

[Install]
WantedBy=multi-user.target
```

**Actuator bridge service:** `/etc/systemd/system/actuator-bridge.service`
```ini
[Unit]
Description=Actuator Bridge for SLIME
After=slime.service
Requires=slime.service

[Service]
Type=simple
User=actuator
Group=slime-actuator
ExecStart=/usr/local/bin/actuator-bridge
Restart=always

[Install]
WantedBy=multi-user.target
```

**Note:** 
- `RuntimeDirectory=slime` in SLIME service ensures `/run/slime` is created automatically
- `User=actuator` with `Group=slime-actuator` allows socket access via group membership
- Process isolation: actuator bridge runs as different user than SLIME

---

## Security Considerations

### Permissions

The socket has `0660` permissions (owner and group read/write).

**Access control:**
- User `actuator` (owner) can read/write
- Members of group `slime-actuator` can read/write
- All others have no access

**Recommended deployment:**

Run SLIME as separate user, add to `slime-actuator` group for socket access:
```bash
# Create users
sudo useradd --system --no-create-home actuator
sudo useradd --system --no-create-home slime

# Create shared group
sudo groupadd --system slime-actuator

# Add both users to group
sudo usermod -a -G slime-actuator actuator
sudo usermod -a -G slime-actuator slime

# Actuator creates and owns socket; SLIME connects via group membership
```

This provides **process isolation** while allowing socket access via group membership.

### No Authentication

The socket itself provides **no authentication** beyond Unix permissions.

The `actuation_token` carries authorization metadata. Verification of the token is implementation-specific to the actuator bridge.

**Critical:** In adversarial environments, the actuator bridge must verify the authenticity of effects using the `actuation_token`. The token scheme and verification mechanism are outside the scope of this specification.

### Socket Exhaustion

If no actuator connects, the kernel socket buffer (typically 64KB) fills up.

Once full, SLIME's writes block, creating backpressure to ingress.

This is **fail-closed** behavior - no effects are dropped silently.

---

## Monitoring

### Socket Status

Check if socket exists:
```bash
ls -l /run/slime/egress.sock
```

Expected output:
```
srw-rw---- 1 actuator slime-actuator 0 Feb  7 10:30 /run/slime/egress.sock
```

### Connection Status

Check if actuator is connected:
```bash
lsof /run/slime/egress.sock
```

Should show actuator bridge (listening) and SLIME (connected).

### Write Failures

SLIME may log write failures to stdout/stderr (observation only):
```json
{"ts":"2026-02-07T10:23:45Z","level":"WARN","event":"egress_write_failed","errno":32}
```

**Note:** Logging is for observation, not operational control.

---

## Prohibitions (Non-Negotiable)

The following are **structurally impossible** in SLIME v0:

- No alternative socket paths
- No dynamic endpoint configuration
- No network egress (TCP/UDP)
- No HTTP webhook fallback
- No acknowledgment protocol
- No backpressure signals from actuator to SLIME
- No retry logic
- No error channels
- No configuration files

Any request to add these features **violates canon**.

---

## Canonical Statement

> **Egress is fixed.**  
> **Authorization produces a write.**  
> **Impossibility produces silence.**

---

**END — SLIME v0 EGRESS SOCKET SPECIFICATION**

This specification is **non-negotiable** and forms part of the SLIME v0 canonical interface.
