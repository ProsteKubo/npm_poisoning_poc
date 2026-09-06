#!/usr/bin/env bash
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "run as root" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -d -m 0755 /usr/local/lib/package-lab
install -m 0755 "$SCRIPT_DIR/root-state-agent.py" /usr/local/lib/package-lab/root-state-agent.py
install -m 0644 "$SCRIPT_DIR/package-lab-root-state.service" /etc/systemd/system/package-lab-root-state.service
install -m 0644 "$SCRIPT_DIR/package-lab-root-state.path" /etc/systemd/system/package-lab-root-state.path
systemctl daemon-reload
systemctl enable --now package-lab-root-state.path
echo "visible root-state heartbeat installed; inactive until the root state exists"
