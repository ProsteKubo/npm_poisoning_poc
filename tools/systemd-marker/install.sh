#!/usr/bin/env bash
set -euo pipefail

# Install
[[ "$(id -u)" -eq 0 ]] || { echo "run as root" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install -d -m 0755 /usr/local/lib/package-lab
install -m 0755 "$SCRIPT_DIR/package-lab-marker.sh" /usr/local/lib/package-lab/package-lab-marker.sh
install -m 0644 "$SCRIPT_DIR/package-lab-marker.service" /etc/systemd/system/package-lab-marker.service
systemctl daemon-reload
systemctl enable --now package-lab-marker.service
