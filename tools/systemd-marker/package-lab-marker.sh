#!/usr/bin/env bash
set -euo pipefail
install -d -m 0700 /var/lib/package-lab
printf '%s uid=%s euid=%s host=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(id -u)" "$(id -u)" "$(hostname)" >> /var/lib/package-lab/systemd-marker.log
chmod 0600 /var/lib/package-lab/systemd-marker.log
