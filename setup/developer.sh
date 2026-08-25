#!/usr/bin/env bash
set -euo pipefail

# Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi
LAB_DEVELOPER="${LAB_DEVELOPER:-developer}"
LAB_INSTALL_ROOT="${LAB_INSTALL_ROOT:-/opt/npm-poisoning-poc}"
LAB_REGISTRY_URL="${LAB_REGISTRY_URL:-http://registry.npm.simunet:4873}"
LAB_NETWORK_SCOPE="${LAB_NETWORK_SCOPE:-isolated}"
NODE_ARCHIVE_XZ="$ROOT_DIR/artifacts/node-v22.22.0-linux-x64.tar.xz"
NODE_ARCHIVE_GZ="$ROOT_DIR/artifacts/node-v22.22.0-linux-x64.tar.gz"

# Preconditions
[[ "$(id -u)" -eq 0 ]] || { echo "run as root" >&2; exit 1; }
[[ "$LAB_NETWORK_SCOPE" == "isolated" ]] || { echo "LAB_NETWORK_SCOPE must be isolated" >&2; exit 1; }

# Developer identity
if ! id "$LAB_DEVELOPER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$LAB_DEVELOPER"
fi

# Node pin
if ! command -v node >/dev/null || [[ "$(node --version)" != "v22.22.0" ]]; then
  if [[ -f "$NODE_ARCHIVE_GZ" ]]; then
    NODE_ARCHIVE="$NODE_ARCHIVE_GZ"
  elif [[ -f "$NODE_ARCHIVE_XZ" ]]; then
    NODE_ARCHIVE="$NODE_ARCHIVE_XZ"
  else
    echo "missing Node.js 22.22.0 archive under $ROOT_DIR/artifacts" >&2
    exit 1
  fi
  rm -rf /opt/node-v22.22.0-linux-x64
  tar -C /opt -xf "$NODE_ARCHIVE"
  ln -sfn /opt/node-v22.22.0-linux-x64/bin/node /usr/local/bin/node
  ln -sfn /opt/node-v22.22.0-linux-x64/bin/npm /usr/local/bin/npm
  ln -sfn /opt/node-v22.22.0-linux-x64/bin/npx /usr/local/bin/npx
fi
[[ "$(node --version)" == "v22.22.0" ]] || { echo "wrong Node.js version" >&2; exit 1; }
[[ "$(npm --version)" == "10.9.4" ]] || { echo "wrong npm version" >&2; exit 1; }

# Application
install -d -m 0755 "$LAB_INSTALL_ROOT/victim-app"
cp -a "$ROOT_DIR/victim-app/backend" "$LAB_INSTALL_ROOT/victim-app/"
cp -a "$ROOT_DIR/victim-app/frontend" "$LAB_INSTALL_ROOT/victim-app/"
install -m 0755 "$ROOT_DIR/replay/run-ai-replay.sh" "$LAB_INSTALL_ROOT/victim-app/frontend/run-ai-replay.sh"
install -m 0644 "$ROOT_DIR/replay/agent-request.md" "$LAB_INSTALL_ROOT/victim-app/frontend/agent-request.md"
install -m 0644 "$ROOT_DIR/replay/agent-response.md" "$LAB_INSTALL_ROOT/victim-app/frontend/agent-response.md"
cat > "$LAB_INSTALL_ROOT/victim-app/frontend/.npmrc" <<EOF
registry=${LAB_REGISTRY_URL}
audit=false
fund=false
progress=false
update-notifier=false
EOF
chown -R "$(id -u "$LAB_DEVELOPER"):$(id -g "$LAB_DEVELOPER")" "$LAB_INSTALL_ROOT/victim-app"
echo "developer setup ready at $LAB_INSTALL_ROOT/victim-app"
