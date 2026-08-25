#!/usr/bin/env bash
set -euo pipefail

# Host state
source /etc/os-release
VERSION="$(dpkg-query -W -f='${Version}' needrestart 2>/dev/null || true)"
[[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "22.04" && -n "$VERSION" ]]
dpkg --compare-versions "$VERSION" lt "3.5-5ubuntu2.2"
! grep -RqsE '^\s*\$nrconf\{interpscan\}\s*=\s*0\s*;' \
  /etc/needrestart/needrestart.conf /etc/needrestart/conf.d 2>/dev/null
