#!/usr/bin/env bash
set -euo pipefail

# Verify
[[ "$(id -u)" -eq 0 ]] || { echo "run as root" >&2; exit 1; }
systemctl is-enabled package-lab-marker.service
systemctl is-active package-lab-marker.service
systemctl cat package-lab-marker.service
stat -c 'owner=%U group=%G mode=%a path=%n' /var/lib/package-lab/systemd-marker.log
tail -n 5 /var/lib/package-lab/systemd-marker.log
