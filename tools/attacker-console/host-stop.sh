#!/usr/bin/env bash
set -euo pipefail

URI=qemu:///session
for DOMAIN in "Ubuntu Package Lab" "Package Lab Attacker"; do
  STATE=$(virsh --connect "$URI" domstate "$DOMAIN")
  if [[ "$STATE" == "shut off" ]]; then
    echo "$DOMAIN is already stopped"
  else
    virsh --connect "$URI" shutdown "$DOMAIN"
  fi
done

echo "graceful shutdown requested for both package-lab VMs"
