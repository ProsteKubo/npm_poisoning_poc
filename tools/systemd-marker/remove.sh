#!/usr/bin/env bash
set -euo pipefail

# Remove
[[ "$(id -u)" -eq 0 ]] || { echo "run as root" >&2; exit 1; }
systemctl disable --now package-lab-marker.service 2>/dev/null || true
rm -f /etc/systemd/system/package-lab-marker.service
rm -f /usr/local/lib/package-lab/package-lab-marker.sh
rm -f /var/lib/package-lab/systemd-marker.log
systemctl daemon-reload
