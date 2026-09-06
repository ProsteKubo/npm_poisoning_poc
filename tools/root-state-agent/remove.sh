#!/usr/bin/env bash
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "run as root" >&2; exit 1; }
systemctl disable --now package-lab-root-state.path package-lab-root-state.service 2>/dev/null || true
rm -f /etc/systemd/system/package-lab-root-state.path
rm -f /etc/systemd/system/package-lab-root-state.service
rm -f /usr/local/lib/package-lab/root-state-agent.py
rm -f /var/lib/package-lab/root-stage-observed
systemctl daemon-reload
echo "root-state heartbeat removed"
