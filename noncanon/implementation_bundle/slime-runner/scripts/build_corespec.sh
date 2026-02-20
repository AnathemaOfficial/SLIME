#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scripts/build_corespec.sh enterprise
#   scripts/build_corespec.sh agent

PROFILE="${1:-}"
if [[ "$PROFILE" != "enterprise" && "$PROFILE" != "agent" ]]; then
  echo "Usage: $0 {enterprise|agent}" >&2
  exit 2
fi

export CARGO_TERM_COLOR=never
export RUST_BACKTRACE=0
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-1700000000}"

# Clear env except minimal allowlist required to run cargo/rustc
KEEP_VARS=("PATH" "HOME" "USER" "SHELL" "PWD" "RUSTUP_HOME" "CARGO_HOME" "SOURCE_DATE_EPOCH")
declare -A KEEP
for v in "${KEEP_VARS[@]}"; do KEEP["$v"]=1; done

while IFS='=' read -r k _; do
  if [[ -z "${KEEP[$k]+x}" ]]; then unset "$k" || true; fi
done < <(env)

# Determinism flags
export RUSTFLAGS="${RUSTFLAGS:-} -C debuginfo=0 -C strip=symbols"

# CoreSpec feature selection
if [[ "$PROFILE" == "enterprise" ]]; then
  FEATURES="--features corespec_enterprise"
else
  FEATURES="--features corespec_agent"
fi

cargo build --release $FEATURES
