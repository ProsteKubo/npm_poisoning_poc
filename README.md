# AI package supply-chain lab

Reusable setup for a package-hallucination security lab:

1. A publisher uploads `react-codeshift@1.1.0` to a lab-hosted Verdaccio service.
2. A deterministic developer replay runs the historical `npx react-codeshift ...` instruction.
3. The package creates an execution marker as the developer account and automatically arms the marker-only CVE-2024-48990 fixture when the host check passes.
4. A later administrator APT transaction triggers vulnerable `needrestart`, producing only a root-owned JSON marker.

The repository has no real-npm uplink, no credential collector, no reverse shell, no destructive payload, and no C2 implant. The publish helper refuses the public npm registry and non-lab hostnames.

## Layout

- `registry/` — Verdaccio 6.2.4 simulated public npm service
- `setup/` — scripts run on registry, developer, and evidence machines
- `victim-app/` — small Python backend and legacy React-shaped frontend
- `replay/` — frozen AI request/response and structured replay runner
- `tools/react-codeshift/` — integrated initial-access and privilege-transition marker package
- `tools/needrestart-cve-2024-48990/` — vulnerable-host validation and marker-only PoC
- `tools/systemd-marker/` — removable post-elevation persistence demonstration
- `evidence/` — collection and timeline helpers
- `artifacts/` — offline Node and Ubuntu package artifacts; binaries are intentionally not committed

## 1. Configure once

```bash
cp .env.example .env
set -a
source .env
set +a
```

Set `LAB_REGISTRY_HOST`, `LAB_REGISTRY_URL`, `LAB_ALLOWED_REGISTRY_HOSTS`, and `LAB_DEVELOPER` for the isolated environment. Keep those environment-specific values only in the ignored `.env` file.

Keep `.env` private. It is ignored by Git, along with registry credentials, generated evidence, npm tarballs, Node archives, and Ubuntu packages.

## 2. Registry VM

The tested attacker setup is native Verdaccio and does not require Docker:

```bash
./setup/registry-native.sh up
```

Docker Engine with the Compose plugin remains available as an alternative:

```bash
sudo ./setup/registry.sh
```

Create the Red publisher with normal registry credentials:

```bash
npm adduser --registry "$LAB_REGISTRY_URL" --auth-type=legacy
npm whoami --registry "$LAB_REGISTRY_URL"
```

Verdaccio has no upstream proxy, so it cannot fall through to the real npm registry.

## 3. Ubuntu developer VM

Recommended base: Ubuntu 22.04 LTS with the exact vulnerable `needrestart` `.deb` stored offline in `artifacts/`. Do not expose that frozen VM to the Internet.

Node.js 22.22.0/npm 10.9.4 must already exist or an official Node 22.22.0 `.tar.gz` or `.tar.xz` archive must be placed in `artifacts/`.

```bash
sudo ./setup/developer.sh
```

Add the lab hostname to DNS, or for a one-host smoke test:

```bash
echo "REGISTRY_IP registry.npm.simunet" | sudo tee -a /etc/hosts
```

## 4. Red publishes

```bash
export ALLOW_LAB_PUBLISH=I_UNDERSTAND_THIS_IS_A_PRIVATE_LAB
./tools/publish-react-codeshift.sh
```

The helper records the package tarball hash and publish output under `evidence/runs/<run-id>/red/`.

Verify the integrated package before moving to the developer VM:

```bash
npm view react-codeshift --registry "$LAB_REGISTRY_URL" \
  name version dist.tarball
```

Expected version: `1.1.0`.

## 5. White/developer replay

```bash
sudo -iu "$LAB_DEVELOPER"
cd /opt/npm-poisoning-poc/victim-app/frontend
LAB_RUN_ID=LAB-001 ./run-ai-replay.sh
```

Expected marker:

```text
~/.local/state/package-lab/initial-access.json
```

On a matching vulnerable host, `privilege_fixture.status` is `armed`, and its PID points to a developer-owned Python process whose source is `loop.py`. Set `LAB_DISABLE_LPE_FIXTURE=1` only when testing initial access without arming the privilege-transition fixture.

Pretty-print the marker and confirm the armed process:

```bash
python3 -m json.tool ~/.local/state/package-lab/initial-access.json
ps -fp "$(cat ~/.local/share/package-lab/cve-2024-48990/python.pid)"
```

## 6. Administrator trigger and verification

After the integrated npm execution reports `privilege_fixture.status` as `armed`, White performs an ordinary APT transaction:

```bash
cd tools/needrestart-cve-2024-48990
sudo ./white-apt-trigger.sh cron
sudo ./verify-root-marker.sh
```

For isolated CVE troubleshooting without the npm stage, use the standalone flow below.

## 7. Standalone CVE-2024-48990 validation

The CVE is image-specific. Canonical fixed Jammy in `3.5-5ubuntu2.2`; the checker only accepts an installed version older than that. The setup script never downloads an old package from the Internet.

```bash
cd tools/needrestart-cve-2024-48990
sudo LAB_ALLOW_VULNERABLE_IMAGE=YES LAB_NETWORK_SCOPE=isolated ./install-vulnerable-package.sh ../../artifacts/needrestart_JAMMY_VULNERABLE_all.deb
./check-host.sh
./arm-marker-poc.sh
sudo ./white-apt-trigger.sh cron
sudo ./verify-root-marker.sh
```

The PoC can only create `/var/lib/package-lab/cve-2024-48990-root-marker.json`. It does not create a shell, user, key, network connection, or persistent service.

## 8. Optional removable persistence demonstration

This step is intentionally separate from the exploit. It requires an explicit root command and installs only a service that appends timestamps and its effective UID to `/var/lib/package-lab/systemd-marker.log`.

```bash
sudo ./tools/systemd-marker/install.sh
sudo ./tools/systemd-marker/verify.sh
sudo ./tools/systemd-marker/remove.sh
```

## 9. Evidence

```bash
sudo ./evidence/collect-local.sh LAB-001
python3 ./evidence/build-timeline.py evidence/runs/LAB-001
```

Use one run ID everywhere and synchronized UTC clocks. The collector copies only scoped scenario artifacts and normal APT logs.

## Reset order

```bash
sudo ./tools/systemd-marker/remove.sh
sudo ./tools/needrestart-cve-2024-48990/cleanup.sh
sudo -iu "$LAB_DEVELOPER" bash -c 'rm -rf "$HOME/.local/state/package-lab"'
./setup/registry-native.sh down
```

Restore the developer VM snapshot after any vulnerable-image run. Removing the package hold and updating `needrestart` is not a substitute for restoring a known-good lab baseline.
