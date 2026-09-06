#!/usr/bin/env bash
set -euo pipefail

URI=qemu:///session
for DOMAIN in "Package Lab Attacker" "Ubuntu Package Lab"; do
  STATE=$(virsh --connect "$URI" domstate "$DOMAIN")
  if [[ "$STATE" == "running" ]]; then
    echo "$DOMAIN is already running"
  else
    virsh --connect "$URI" start "$DOMAIN"
  fi
done

echo "attacker=192.168.88.20 target=192.168.88.10 management=192.168.77.10"
