# SLIME v0 — Binary Package and Systemd Deployment

**Target:** Production Linux systems without Docker  
**Format:** Static binary + systemd service unit

---

## 1. Binary Build Specification

### 1.1 Build Requirements

```bash
# Build environment
OS: Linux x86_64
Rust: 1.75+
Target: x86_64-unknown-linux-musl (static)
Dependencies: None (fully static)
```

### 1.2 Build Command

```bash
# Install musl target
rustup target add x86_64-unknown-linux-musl

# Build static binary
cargo build \
  --release \
  --target x86_64-unknown-linux-musl \
  --features embedded-abs

# Verify static linking
ldd target/x86_64-unknown-linux-musl/release/slime-runtime
# Expected: "not a dynamic executable"

# Strip binary
strip target/x86_64-unknown-linux-musl/release/slime-runtime

# Verify size
ls -lh target/x86_64-unknown-linux-musl/release/slime-runtime
# Expected: ~15-20MB
```

---

## 2. Binary Package Structure

```
slime-v0-linux-x86_64/
├── bin/
│   └── slime                  # Static executable
├── web/
│   └── dashboard.html         # Dashboard UI
├── docs/
│   ├── QUICKSTART.md
│   ├── OPERATIONS.md
│   └── INTEGRATION.md
├── verification/
│   ├── CANON_HASH.txt
│   └── SHA256SUMS
├── systemd/
│   └── slime.service          # Service unit file
└── README.txt
```

---

## 3. Systemd Service Unit

### 3.1 Service File: `/etc/systemd/system/slime.service`

```ini
[Unit]
Description=SLIME v0 - Sealed Execution Environment
Documentation=https://docs.syfcorp.io/slime-v0
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=slime
Group=slime

# Binary location
ExecStart=/usr/local/bin/slime

# Working directory
WorkingDirectory=/opt/slime

# Runtime directory and socket permissions
RuntimeDirectory=slime
RuntimeDirectoryMode=0755
UMask=0007

# Restart policy
Restart=always
RestartSec=5s

# Resource limits
MemoryLimit=256M
TasksMax=50
CPUQuota=50%

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=/
ReadWritePaths=/opt/slime/logs
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictAddressFamilies=AF_INET AF_INET6

# Standard output/error
StandardOutput=journal
StandardError=journal
SyslogIdentifier=slime

[Install]
WantedBy=multi-user.target
```

### 3.2 User and Directory Setup

```bash
# Create dedicated user (no login)
sudo useradd --system --no-create-home --shell /usr/sbin/nologin slime

# Create directories
sudo mkdir -p /opt/slime/{web,logs,verification}
sudo mkdir -p /usr/local/bin

# Set ownership
sudo chown -R slime:slime /opt/slime
sudo chmod 755 /opt/slime
sudo chmod 755 /opt/slime/logs
```

---

## 4. Installation Script

### 4.1 Install Script: `install.sh`

```bash
#!/bin/bash
# SLIME v0 Installation Script
# Usage: sudo ./install.sh

set -e

# Check root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo "=== SLIME v0 Installation ==="

# Verify binary
echo "Verifying binary integrity..."
sha256sum -c verification/SHA256SUMS || {
    echo "ERROR: Binary verification failed"
    exit 1
}

# Verify AB-S commit hash
EXPECTED_HASH="07e501b05b87d1fed647e156f8b7929ab073ce7e"
ACTUAL_HASH=$(cat verification/CANON_HASH.txt)

if [[ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]]; then
    echo "ERROR: AB-S core hash mismatch"
    exit 1
fi

# Create user
echo "Creating slime user..."
id -u slime &>/dev/null || \
    useradd --system --no-create-home --shell /usr/sbin/nologin slime

# Install binary
echo "Installing binary to /usr/local/bin/slime..."
cp bin/slime /usr/local/bin/slime
chmod 755 /usr/local/bin/slime

# Create directories
echo "Creating application directories..."
mkdir -p /opt/slime/{web,logs,verification,docs}

# Copy web assets
cp web/dashboard.html /opt/slime/web/
cp verification/* /opt/slime/verification/
cp docs/* /opt/slime/docs/

# Set ownership
chown -R slime:slime /opt/slime
chmod 755 /opt/slime
chmod 755 /opt/slime/logs

# Install systemd service
echo "Installing systemd service..."
cp systemd/slime.service /etc/systemd/system/slime.service
chmod 644 /etc/systemd/system/slime.service

# Reload systemd
systemctl daemon-reload

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "1. Enable and start service:"
echo "   sudo systemctl enable slime"
echo "   sudo systemctl start slime"
echo ""
echo "2. Verify:"
echo "   systemctl status slime"
echo "   curl http://localhost:8081/health"
echo ""
echo "3. Connect actuator bridge to /run/slime/egress.sock"
echo ""
```

Make executable:
```bash
chmod +x install.sh
```

---

## 6. Service Management

### 6.1 Enable and Start

```bash
# Enable service (auto-start on boot)
sudo systemctl enable slime

# Start service
sudo systemctl start slime

# Check status
sudo systemctl status slime
```

Expected output:
```
● slime.service - SLIME v0 - Sealed Execution Environment
     Loaded: loaded (/etc/systemd/system/slime.service; enabled)
     Active: active (running) since Fri 2026-02-07 10:30:00 UTC
   Main PID: 12345 (slime)
      Tasks: 3 (limit: 50)
     Memory: 45.2M (limit: 256.0M)
     CGroup: /system.slice/slime.service
             └─12345 /usr/local/bin/slime
```

### 6.2 Stop and Restart

```bash
# Stop service
sudo systemctl stop slime

# Restart service
sudo systemctl restart slime

# Reload configuration (without restart)
sudo systemctl daemon-reload
```

### 6.3 View Logs

```bash
# Follow logs in real-time
sudo journalctl -u slime -f

# View recent logs
sudo journalctl -u slime -n 100

# View logs for specific time range
sudo journalctl -u slime --since "1 hour ago"
```

---

## 7. Health Verification

### 7.1 Post-Installation Checks

```bash
# Check service status
systemctl is-active slime

# Check health endpoint
curl http://localhost:8081/health

# Expected response:
# {"status":"STABLE","ab_core":"SEALED","version":"v0.1.0"}

# Check version
curl http://localhost:8081/version | jq

# Test action endpoint
curl -X POST http://localhost:8080/action \
  -H "Content-Type: application/json" \
  -d '{"domain":"test","magnitude":10,"payload":"dGVzdA=="}'

# Check dashboard
curl http://localhost:8081/
```

---

## 8. Localhost Binding

**SLIME v0 binds to localhost only.**

**Fixed endpoints:**
- Ingress: `http://127.0.0.1:8080`
- Dashboard: `http://127.0.0.1:8081`

**Remote access is out of scope for SLIME v0.**

If remote access is required, it must be provided by external infrastructure:
- Reverse proxy (nginx, HAProxy)
- SSH tunnel
- VPN
- API gateway

SLIME does not provide network configuration, TLS termination, or authentication.

---

## 9. Upgrade Procedure

### 9.1 Download New Version

```bash
# Download new binary
wget https://releases.syfcorp.io/slime-v0.1.1-linux-x86_64.tar.gz
wget https://releases.syfcorp.io/slime-v0.1.1-linux-x86_64.tar.gz.sha256

# Verify download
sha256sum -c slime-v0.1.1-linux-x86_64.tar.gz.sha256

# Extract
tar xzf slime-v0.1.1-linux-x86_64.tar.gz
```

### 9.2 Install New Version

```bash
# Stop service
sudo systemctl stop slime

# Backup current binary
sudo cp /usr/local/bin/slime /usr/local/bin/slime.v0.1.0.bak

# Install new binary
sudo cp slime-v0.1.1-linux-x86_64/bin/slime /usr/local/bin/slime
sudo chmod 755 /usr/local/bin/slime

# Start service
sudo systemctl start slime

# Verify
curl http://localhost:8081/version
```

**Critical:** No configuration migration needed (stateless).

---

## 10. Uninstallation

```bash
# Stop and disable service
sudo systemctl stop slime
sudo systemctl disable slime

# Remove service file
sudo rm /etc/systemd/system/slime.service
sudo systemctl daemon-reload

# Remove binary and directories
sudo rm /usr/local/bin/slime
sudo rm -rf /opt/slime

# Remove user
sudo userdel slime

echo "SLIME v0 uninstalled"
```

---

## 11. Troubleshooting

### 11.1 Service Won't Start

**Check logs:**
```bash
sudo journalctl -u slime -n 50 --no-pager
```

**Common issues:**

1. **Port already in use:**
```bash
sudo lsof -i :8080
sudo lsof -i :8081
```

2. **Permission denied:**
```bash
sudo chown slime:slime /opt/slime
```

3. **Binary not found:**
```bash
ls -l /usr/local/bin/slime
```

### 11.2 Cannot Access Dashboard

```bash
# Check if service is listening
sudo netstat -tlnp | grep slime

# Test local access
curl http://localhost:8081/health
```

---

**END — BINARY AND SYSTEMD DEPLOYMENT**

The binary package is ready for production Linux deployment.
