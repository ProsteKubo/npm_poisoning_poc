#!/usr/bin/env bash
set -euo pipefail

# Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi
LAB_REGISTRY_URL="${LAB_REGISTRY_URL:-http://registry.npm.simunet:4873}"
LAB_RUN_ID="${LAB_RUN_ID:-LAB-001}"
PACKAGE_DIR="$ROOT_DIR/tools/react-codeshift"
EVIDENCE_DIR="$ROOT_DIR/evidence/runs/$LAB_RUN_ID/red"

# Safety gate
[[ "${ALLOW_LAB_PUBLISH:-}" == "I_UNDERSTAND_THIS_IS_A_PRIVATE_LAB" ]] || {
  echo "set ALLOW_LAB_PUBLISH=I_UNDERSTAND_THIS_IS_A_PRIVATE_LAB" >&2
  exit 1
}
python3 - "$LAB_REGISTRY_URL" "${LAB_ALLOWED_REGISTRY_HOSTS:-}" <<'PY'
import ipaddress
import sys
from urllib.parse import urlparse

url = urlparse(sys.argv[1])
host = (url.hostname or "").lower()
allowlist = {item.strip().lower() for item in sys.argv[2].split(",") if item.strip()}
allowed_name = host == "localhost" or host.endswith((".simunet", ".test", ".invalid"))
try:
    allowed_ip = ipaddress.ip_address(host).is_private or ipaddress.ip_address(host).is_loopback
except ValueError:
    allowed_ip = False
if host in {"registry.npmjs.org", "npmjs.org"}:
    raise SystemExit("refusing public npm")
if url.scheme not in {"http", "https"} or not (allowed_name or allowed_ip or host in allowlist):
    raise SystemExit(f"refusing non-lab registry: {sys.argv[1]}")
PY

# Publish
mkdir -p "$EVIDENCE_DIR"
pushd "$PACKAGE_DIR" >/dev/null
# DEBUG_ONLY_JSON_ARTIFACT: remove this npm pack report for competition builds.
npm pack --json > "$EVIDENCE_DIR/pack.json"
TARBALL="$(python3 - "$EVIDENCE_DIR/pack.json" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))[0]["filename"])
PY
)"
sha256sum "$TARBALL" > "$EVIDENCE_DIR/package.sha256"
npm publish --registry "$LAB_REGISTRY_URL" 2>&1 | tee "$EVIDENCE_DIR/publish.log"
mv "$TARBALL" "$EVIDENCE_DIR/"
popd >/dev/null
PACKAGE_VERSION=$(node -p "require('$PACKAGE_DIR/package.json').version")
echo "published react-codeshift@$PACKAGE_VERSION to $LAB_REGISTRY_URL"
