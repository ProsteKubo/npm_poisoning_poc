#!/usr/bin/env bash
set -euo pipefail

# Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi
REGISTRY_ROOT="${LAB_REGISTRY_ROOT:-${HOME}/npm-lab-registry}"
REGISTRY_PORT="${LAB_REGISTRY_PORT:-4873}"
PID_FILE="$REGISTRY_ROOT/verdaccio.pid"

# Lifecycle
case "${1:-up}" in
  up)
    command -v npm >/dev/null
    mkdir -p "$REGISTRY_ROOT/storage"
    cp "$ROOT_DIR/registry/config-native.yaml" "$REGISTRY_ROOT/config.yaml"
    if [[ ! -x "$REGISTRY_ROOT/node_modules/.bin/verdaccio" ]]; then
      [[ -f "$REGISTRY_ROOT/package.json" ]] || npm init -y --prefix "$REGISTRY_ROOT" >/dev/null
      npm install --prefix "$REGISTRY_ROOT" --save-exact verdaccio@6.2.4 >/dev/null
    fi
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "registry already running pid=$(cat "$PID_FILE")"
      exit 0
    fi
    nohup "$REGISTRY_ROOT/node_modules/.bin/verdaccio" \
      --config "$REGISTRY_ROOT/config.yaml" \
      >"$REGISTRY_ROOT/verdaccio.log" 2>&1 &
    echo $! > "$PID_FILE"
    for _ in {1..30}; do
      if curl -fsS "http://127.0.0.1:${REGISTRY_PORT}/-/ping" >/dev/null; then
        echo "registry ready on :${REGISTRY_PORT}"
        exit 0
      fi
      sleep 1
    done
    echo "registry did not become ready" >&2
    exit 1
    ;;
  down)
    if [[ -f "$PID_FILE" ]]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
      rm -f "$PID_FILE"
    fi
    ;;
  logs)
    tail -n 100 "$REGISTRY_ROOT/verdaccio.log"
    ;;
  status)
    curl -fsS "http://127.0.0.1:${REGISTRY_PORT}/-/ping"
    ;;
  *)
    echo "usage: $0 [up|down|logs|status]" >&2
    exit 2
    ;;
esac
