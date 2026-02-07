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
