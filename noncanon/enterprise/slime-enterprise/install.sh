#!/usr/bin/env bash
# SLIME Appliance Installer — v0.2.0 (Phase 6 + Dashboard)
# Installs: runner (AB-S real), actuator-min, FirePlank-Guard (FP-1 + FP-4), Dashboard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="/usr/local/bin"
UNIT_DIR="/etc/systemd/system"
SEAL_DIR="/usr/lib/slime"
LOG_DIR="/var/log/slime-actuator"
DASHBOARD_DIR="/opt/slime/dashboard"

echo "============================================"
echo "  SLIME Appliance v0.2.0 — Installer"
echo "  Phase 6 + Dashboard"
echo "============================================"
echo ""

# --- [1/12] Users and groups ---
echo "[1/12] Users and groups"
sudo groupadd -f slime-actuator
id -u slime    >/dev/null 2>&1 || sudo useradd -r -s /usr/sbin/nologin -g slime-actuator slime
id -u actuator >/dev/null 2>&1 || sudo useradd -r -s /usr/sbin/nologin -g slime-actuator actuator

# --- [2/12] Install binaries ---
echo "[2/12] Install binaries"
sudo install -m 0755 "$SCRIPT_DIR/bin/slime-runner"   "$BIN_DIR/slime-runner"
sudo install -m 0755 "$SCRIPT_DIR/bin/actuator-min"   "$BIN_DIR/actuator-min"

# --- [3/12] Install FirePlank-Guard scripts (FP-1) ---
echo "[3/12] Install FirePlank-Guard scripts"
sudo install -m 0755 "$SCRIPT_DIR/bin/fireplank-guard-boot.sh" "$BIN_DIR/fireplank-guard-boot.sh"
sudo install -m 0755 "$SCRIPT_DIR/bin/generate-seal.sh"        "$BIN_DIR/generate-seal.sh"

# --- [4/12] Generate seal file (FP-1) ---
echo "[4/12] Generate seal file"
sudo mkdir -p "$SEAL_DIR"
sudo "$BIN_DIR/generate-seal.sh"

# --- [5/12] Create log directory ---
echo "[5/12] Create log directory"
sudo mkdir -p "$LOG_DIR"
sudo chown actuator:slime-actuator "$LOG_DIR"
sudo chmod 750 "$LOG_DIR"

# --- [6/12] Install systemd units ---
echo "[6/12] Install systemd units"
sudo install -m 0644 "$SCRIPT_DIR/systemd/actuator.service"        "$UNIT_DIR/actuator.service"
sudo install -m 0644 "$SCRIPT_DIR/systemd/slime.service"           "$UNIT_DIR/slime.service"
sudo install -m 0644 "$SCRIPT_DIR/systemd/slime-dashboard.service" "$UNIT_DIR/slime-dashboard.service"

# --- [7/12] Install systemd hardening drop-ins (FP-4) ---
echo "[7/12] Install hardening drop-ins (FP-4)"
sudo mkdir -p "$UNIT_DIR/actuator.service.d"
sudo mkdir -p "$UNIT_DIR/slime.service.d"
sudo install -m 0644 "$SCRIPT_DIR/systemd/fp4-hardening-actuator.conf" "$UNIT_DIR/actuator.service.d/fp4-hardening.conf"
sudo install -m 0644 "$SCRIPT_DIR/systemd/fp4-hardening-slime.conf"    "$UNIT_DIR/slime.service.d/fp4-hardening.conf"

# --- [8/12] Install dashboard ---
echo "[8/12] Install dashboard"
sudo mkdir -p "$DASHBOARD_DIR"
sudo install -m 0644 "$SCRIPT_DIR/dashboard/server.py"      "$DASHBOARD_DIR/server.py"
sudo install -m 0644 "$SCRIPT_DIR/dashboard/dashboard.html" "$DASHBOARD_DIR/dashboard.html"
sudo chown -R slime:slime-actuator "$DASHBOARD_DIR"

# --- [9/12] Reload and enable ---
echo "[9/12] Reload and enable"
sudo systemctl daemon-reload
sudo systemctl enable actuator.service slime.service slime-dashboard.service

# --- [10/12] Start services ---
echo "[10/12] Start services"
sudo systemctl restart actuator.service
sleep 1
sudo systemctl restart slime.service
sleep 1
sudo systemctl restart slime-dashboard.service
sleep 1

# --- [11/12] Verify core ---
echo "[11/12] Verify core"
echo ""
sudo systemctl --no-pager status actuator.service || true
echo ""
sudo systemctl --no-pager status slime.service || true
echo ""
echo "--- Socket check ---"
ls -l /run/slime/egress.sock 2>/dev/null || echo "WARNING: egress socket not found"
echo ""
echo "--- Seal file ---"
cat "$SEAL_DIR/fireplank.seal" 2>/dev/null || echo "WARNING: seal file not found"
echo ""
echo "--- Live test ---"
RESULT=$(curl -sS -m 2 -X POST http://127.0.0.1:8080/action \
  -H "Content-Type: application/json" \
  -d '{"domain":"test","magnitude":1}' 2>/dev/null || echo "FAILED")
echo "POST domain=test magnitude=1 -> $RESULT"

# --- [12/12] Verify dashboard ---
echo ""
echo "[12/12] Verify dashboard"
sudo systemctl --no-pager status slime-dashboard.service || true
DASH=$(curl -sS -m 2 http://127.0.0.1:8081/api/status 2>/dev/null || echo "FAILED")
echo "Dashboard /api/status -> $DASH"
echo ""

if echo "$RESULT" | grep -q "AUTHORIZED"; then
    echo "============================================"
    echo "  SLIME Appliance v0.2.0 installed"
    echo ""
    echo "  AB-S engine:       REAL (Phase 6.3)"
    echo "  FirePlank-Guard:   FP-1 + FP-4 ACTIVE"
    echo "  Dashboard:         http://127.0.0.1:8081"
    echo "============================================"
else
    echo "============================================"
    echo "  WARNING: Installation completed but"
    echo "  live test did not return AUTHORIZED."
    echo "  Check service logs."
    echo "============================================"
    exit 1
fi
