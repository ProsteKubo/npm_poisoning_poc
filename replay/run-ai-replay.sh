#!/usr/bin/env bash
set -euo pipefail

# Preconditions
[[ "$(id -u)" -ne 0 ]] || { echo "run as the developer, not root" >&2; exit 1; }
command -v npx >/dev/null
command -v python3 >/dev/null

# Run
RUN_ID="${LAB_RUN_ID:-LAB-001}"
LOG_DIR="${HOME}/.local/state/package-lab/replay/${RUN_ID}"
COMMAND="npx react-codeshift --transform=react-codeshift/transforms/rename-unsafe-lifecycles.js ./src"
mkdir -p "$LOG_DIR"
STARTED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
set +e
LAB_RUN_ID="$RUN_ID" npm_config_yes=true bash -lc "$COMMAND" >"$LOG_DIR/stdout.log" 2>"$LOG_DIR/stderr.log"
STATUS=$?
set -e
FINISHED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 - "$LOG_DIR/event.json" "$RUN_ID" "$STARTED" "$FINISHED" "$STATUS" "$COMMAND" <<'PY'
import json
import os
import sys

path, run_id, started, finished, status, command = sys.argv[1:]
event = {
    "event": "ai-replay",
    "run_id": run_id,
    "started_utc": started,
    "finished_utc": finished,
    "user": os.environ.get("USER"),
    "uid": os.getuid(),
    "cwd": os.getcwd(),
    "command": command,
    "exit_code": int(status),
}
# DEBUG_ONLY_JSON_ARTIFACT: remove this replay record for competition builds.
with open(path, "w", encoding="utf-8") as handle:
    json.dump(event, handle, indent=2)
    handle.write("\n")
PY
cat "$LOG_DIR/stdout.log"
cat "$LOG_DIR/stderr.log" >&2
exit "$STATUS"
