#!/usr/bin/env bash
set -euo pipefail

FIXTURE_DIR="${HOME}/.local/share/package-lab/cve-2024-48990"
PID_FILE="$FIXTURE_DIR/python.pid"
PYTHON_PID=""

cleanup() {
  if [[ "$PYTHON_PID" =~ ^[0-9]+$ ]]; then
    kill "$PYTHON_PID" 2>/dev/null || true
    wait "$PYTHON_PID" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
}
trap cleanup EXIT INT TERM

PYTHONPATH="$FIXTURE_DIR" /usr/bin/python3 "$FIXTURE_DIR/loop.py" &
PYTHON_PID=$!
printf '%s\n' "$PYTHON_PID" > "$PID_FILE"

while kill -0 "$PYTHON_PID" 2>/dev/null; do
  env -u PYTHONPATH /usr/bin/python3 "$FIXTURE_DIR/heartbeat.py" || true
  for _ in $(seq 1 30); do
    kill -0 "$PYTHON_PID" 2>/dev/null || exit 1
    sleep 1
  done
done

wait "$PYTHON_PID"
