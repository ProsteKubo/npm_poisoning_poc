#!/usr/bin/env bash
set -euo pipefail

# Configuration
EVIDENCE_ROOT="${EVIDENCE_ROOT:-/srv/package-lab-evidence/runs}"
EVIDENCE_USER="${EVIDENCE_USER:-evidence}"

# Setup
[[ "$(id -u)" -eq 0 ]] || { echo "run as root" >&2; exit 1; }
if ! id "$EVIDENCE_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$EVIDENCE_USER"
fi
install -d -o "$EVIDENCE_USER" -g "$EVIDENCE_USER" -m 0750 "$EVIDENCE_ROOT"
echo "evidence root ready at $EVIDENCE_ROOT"
