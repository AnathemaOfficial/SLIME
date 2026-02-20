#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scripts/run_strace_boot.sh <path-to-binary> [out-log]

BIN="${1:-}"
OUT="${2:-/tmp/slime_strace_boot.log}"

if [[ -z "$BIN" ]]; then
  echo "Usage: $0 <path-to-binary> [out-log]" >&2
  exit 2
fi

# Capture file/process/network syscalls during boot sequence
# Binary may exit(1) quickly if egress is absent — that is expected
strace -ff -o "$OUT" -tt -s 256 \
  -e trace=%file,%process,%network \
  "$BIN" || true

echo "$OUT"
