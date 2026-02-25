# T01 — Boot without actuator (fail-closed)

## Purpose
Prove that SLIME cannot operate if the actuator socket owner is absent.

## Setup
Enterprise Appliance v0.1 installed on target.

## Steps

1) Stop both services
```bash
sudo systemctl stop slime.service actuator.service
sudo systemctl reset-failed slime.service actuator.service
```

2) Disable actuator (simulate missing owner at boot)
```bash
sudo systemctl disable actuator.service
sudo systemctl daemon-reload
```

3) Reboot
```bash
sudo reboot
```

4) After reboot, check service states
```bash
systemctl is-active actuator.service || true
systemctl is-active slime.service || true
systemctl status slime.service --no-pager -l || true
ls -l /run/slime/egress.sock || true
```

## Expected
- `actuator.service` is not running (disabled)
- `slime.service` is **failed / inactive** (must not run)
- `/run/slime/egress.sock` absent
- This is a correct fail-closed outcome.

## Proof artifacts
Capture:
- output of `systemctl status slime.service`
- output of `ls -l /run/slime/egress.sock`
