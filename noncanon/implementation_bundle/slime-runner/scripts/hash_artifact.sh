#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scripts/hash_artifact.sh <path-to-binary>

BIN="${1:-}"
if [[ -z "$BIN" ]]; then
  echo "Usage: $0 <path-to-binary>" >&2
  exit 2
fi
if [[ ! -f "$BIN" ]]; then
  echo "Binary not found: $BIN" >&2
  exit 2
fi

# blake3 if available, sha256 fallback
if command -v b3sum >/dev/null 2>&1; then
  b3sum "$BIN" | awk '{print $1}'
else
  sha256sum "$BIN" | awk '{print $1}'
fi
