#!/usr/bin/env bash
set -euo pipefail

exec virt-manager --connect qemu:///session --show-domain-console "${1:-Package Lab Attacker}"
