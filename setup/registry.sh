#!/usr/bin/env bash
set -euo pipefail

# Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi
LAB_REGISTRY_PORT="${LAB_REGISTRY_PORT:-4873}"

# Preconditions
command -v docker >/dev/null
docker compose version >/dev/null

# Lifecycle
case "${1:-up}" in
  up)
    docker compose --env-file "${ROOT_DIR}/.env" -f "$ROOT_DIR/registry/docker-compose.yml" up -d
    for _ in {1..30}; do
      if curl -fsS "http://127.0.0.1:${LAB_REGISTRY_PORT}/-/ping" >/dev/null; then
        echo "registry ready on :${LAB_REGISTRY_PORT}"
        exit 0
      fi
      sleep 1
    done
    echo "registry did not become ready" >&2
    exit 1
    ;;
  down)
    docker compose --env-file "${ROOT_DIR}/.env" -f "$ROOT_DIR/registry/docker-compose.yml" down
    ;;
  logs)
    docker compose --env-file "${ROOT_DIR}/.env" -f "$ROOT_DIR/registry/docker-compose.yml" logs --no-color
    ;;
  *)
    echo "usage: $0 [up|down|logs]" >&2
    exit 2
    ;;
esac

