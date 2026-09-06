#!/usr/bin/env bash
set -euo pipefail

# Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_ID="${1:-${LAB_RUN_ID:-LAB-001}}"
LAB_DEVELOPER="${LAB_DEVELOPER:-developer}"
TARGET_HOME="$(getent passwd "$LAB_DEVELOPER" | cut -d: -f6)"
TARGET_UID="$(id -u "$LAB_DEVELOPER")"
DEST="$ROOT_DIR/evidence/runs/$RUN_ID/developer"

# Collection
[[ "$(id -u)" -eq 0 ]] || { echo "run as root" >&2; exit 1; }
install -d -m 0750 "$DEST"
for source in \
  "$TARGET_HOME/.local/state/package-lab/initial-access.json" \
  "/var/lib/package-lab/cve-2024-48990-root-marker.json" \
  "/var/lib/package-lab/root-stage-observed" \
  "/var/lib/package-lab/systemd-marker.log" \
  "/var/log/apt/history.log" \
  "/var/log/dpkg.log"; do
  [[ -f "$source" ]] && cp --preserve=mode,timestamps "$source" "$DEST/"
done
if [[ -d "$TARGET_HOME/.local/state/package-lab/replay/$RUN_ID" ]]; then
  cp -a "$TARGET_HOME/.local/state/package-lab/replay/$RUN_ID" "$DEST/replay"
fi
systemctl show package-lab-marker.service > "$DEST/systemd-marker.show" 2>/dev/null || true
journalctl --utc --no-pager -u package-lab-marker.service > "$DEST/systemd-marker.journal" 2>/dev/null || true
systemctl show package-lab-root-state.path > "$DEST/root-state-path.show" 2>/dev/null || true
systemctl show package-lab-root-state.service > "$DEST/root-state-service.show" 2>/dev/null || true
journalctl --utc --no-pager -u package-lab-root-state.path -u package-lab-root-state.service > "$DEST/root-state.journal" 2>/dev/null || true
runuser -u "$LAB_DEVELOPER" -- env \
  XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus" \
  systemctl --user show package-lab-rearm.service > "$DEST/rearm-service.show" 2>/dev/null || true
journalctl --utc --no-pager _UID="$TARGET_UID" _SYSTEMD_USER_UNIT=package-lab-rearm.service > "$DEST/rearm-service.journal" 2>/dev/null || true
find "$ROOT_DIR/evidence/runs/$RUN_ID" -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > "$ROOT_DIR/evidence/runs/$RUN_ID/SHA256SUMS"
echo "evidence collected at $ROOT_DIR/evidence/runs/$RUN_ID"
