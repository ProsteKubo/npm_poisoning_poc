# AI package supply-chain lab

This repository contains an isolated, marker-only reproduction of an AI-assisted package-hallucination attack chain. It connects a historically hallucinated npm package name to controlled developer-level execution, then demonstrates how a vulnerable `needrestart` installation can turn that foothold into a root execution event.

The validated baseline uses `react-codeshift@1.3.1`, Verdaccio `6.2.4`, Ubuntu 22.04, Node.js `22.22.0`, npm `10.9.4`, Python 3, a C compiler, and `needrestart 3.5-5ubuntu2.1`. Ubuntu fixed CVE-2024-48990 for Jammy in `3.5-5ubuntu2.2`.

The lab emits bounded evidence only. It contains no reverse shell, command channel, credential collection, discovery, lateral movement, destructive action, or Internet callback. Use it only on isolated, resettable systems that you are authorized to test.

## Contents

- [Repository layout](#repository-layout)
- [Environment model](#environment-model)
- [Setup](#setup)
- [Publish the exercise package](#publish-the-exercise-package)
- [Run the scenario](#run-the-scenario)
- [CALDERA manual attacker operation](docs/CALDERA.md)
- [Reset and remediation](#reset-and-remediation)
- [Research basis](#research-basis)

## Repository layout

| Path | Purpose |
|---|---|
| `registry/` | Verdaccio configuration with no public npm uplink |
| `setup/` | One-time registry, victim, and evidence provisioning |
| `replay/` | Frozen AI request/response and deterministic replay wrapper |
| `tools/react-codeshift/` | Integrated npm fixture, version `1.3.1` |
| `tools/needrestart-cve-2024-48990/` | Host check, marker-only CVE fixture, verification, and cleanup |
| `tools/one-way-beacon/` | Write-only HTTP event receiver |
| `tools/root-state-agent/` | Visible, pre-provisioned root-state watcher and teardown |
| `docs/CALDERA.md` | Attacker operator runbook after infrastructure is ready |

## Environment model

Use three logical roles. The registry and attacker roles may share one VM.

| Role | Required software | Network requirement |
|---|---|---|
| Registry / attacker | Linux, Node/npm, Verdaccio, Python 3 | Victim can reach TCP 4873 and the event receiver on TCP 8088 |
| Victim / developer | Ubuntu 22.04, Node 22.22.0, npm 10.9.4, Python 3, `cc`, vulnerable `needrestart` | npm resolves only to the isolated registry |
| Administrator / White | Sudo access on the victim | Performs an ordinary APT transaction after the package stage |

Keep infrastructure-specific addresses, usernames, credentials, and run identifiers in `.env`; do not commit them.

## Setup

Choose the repository-assisted path for repeatable deployment. Use the independent path when developing or replacing individual components and you do not want the helper scripts to hide the underlying configuration.

<details open>
<summary><strong>Option 1 - Repository-assisted deployment</strong></summary>

### Clone and configure

Clone the repository on the machines that need it, then create the local configuration:

```bash
git clone https://github.com/ProsteKubo/npm_poisoning_poc.git
cd npm_poisoning_poc
cp .env.example .env
```

Edit `.env` for the active range:

```dotenv
LAB_REGISTRY_HOST=registry.lab.invalid
LAB_REGISTRY_PORT=4873
LAB_REGISTRY_URL=http://registry.lab.invalid:4873
LAB_ALLOWED_REGISTRY_HOSTS=registry.lab.invalid
LAB_DEVELOPER=developer
LAB_INSTALL_ROOT=/opt/npm-poisoning-poc
LAB_NETWORK_SCOPE=isolated
LAB_RUN_ID=LAB-001
```

Load it before using the helper scripts:

```bash
set -a
source .env
set +a
```

The package event destination is a fixed build-time lab value. Confirm that the checked-in `heartbeat.py` and `root_marker.c` copies point to the intended isolated receiver before publishing.

### Registry and receiver

The native registry helper is the tested path:

```bash
./setup/registry-native.sh up
curl -fsS "$LAB_REGISTRY_URL/-/ping"
npm adduser --registry "$LAB_REGISTRY_URL" --auth-type=legacy
npm whoami --registry "$LAB_REGISTRY_URL"
```

Verdaccio has no public npm uplink. Start the write-only receiver and keep its JSONL log outside the repository:

```bash
python3 tools/one-way-beacon/beacon-listener.py \
  --listen <ATTACKER_INTERFACE_IP> \
  --port 8088 \
  --log /var/tmp/package-lab-beacons.jsonl
```

For a pre-provisioned attacker VM, use the installed services:

```bash
systemctl status package-lab-registry.service package-lab-beacon.service
journalctl -fu package-lab-beacon.service
```

Restrict TCP 4873 and 8088 at the range firewall to the intended victim network.

### Victim

Place the official Node.js 22.22.0 Linux archive and the approved offline vulnerable `needrestart` package in `artifacts/`. Binaries and `.deb` files are intentionally not committed.

```bash
sudo -E ./setup/developer.sh

NEEDRESTART_DEB=./artifacts/needrestart_3.5-5ubuntu2.1_all.deb
sudo env \
  LAB_ALLOW_VULNERABLE_IMAGE=YES \
  LAB_NETWORK_SCOPE="$LAB_NETWORK_SCOPE" \
  ./tools/needrestart-cve-2024-48990/install-vulnerable-package.sh \
  "$NEEDRESTART_DEB"
```

The developer helper creates the developer identity when needed, pins Node/npm, writes the local npm configuration, enables lingering, and installs the visible root-state watcher. The vulnerable-package helper validates the supplied Jammy package, installs it, enables interpreter scanning, and applies the APT hold.

Verify the frozen baseline:

```bash
node --version
npm --version
python3 --version
cc --version | head -n 1
dpkg-query -W -f='${Version}\n' needrestart
sudo -iu "$LAB_DEVELOPER" npm ping --registry "$LAB_REGISTRY_URL"
```

Expected versions are Node `v22.22.0`, npm `10.9.4`, and `needrestart 3.5-5ubuntu2.1`.

Freeze the validated vulnerable package so an unattended upgrade cannot silently patch the exercise image:

```bash
sudo apt-mark hold needrestart
apt-mark showhold | grep -Fx needrestart
```

The verification command must print `needrestart`. Snapshot the victim after provisioning and before an exercise run.

</details>

<details>
<summary><strong>Option 2 - Independent component setup (developer path)</strong></summary>

This path does not require a complete repository checkout on the registry or victim. Keep editable component sources on a development workstation and copy only the registry configuration, package source, receiver, root-state agent, or replay files that you are changing.

Set the environment explicitly in each working shell:

```bash
export LAB_REGISTRY_HOST=registry.lab.invalid
export LAB_REGISTRY_PORT=4873
export LAB_REGISTRY_URL=http://registry.lab.invalid:4873
export LAB_DEVELOPER=developer
export LAB_RUN_ID=LAB-001
```

### Registry

Install the pinned registry into its own directory:

```bash
export REGISTRY_ROOT="$PWD/npm-lab-registry"
mkdir -p "$REGISTRY_ROOT/storage"
npm init -y --prefix "$REGISTRY_ROOT"
npm install --prefix "$REGISTRY_ROOT" --save-exact verdaccio@6.2.4
```

Create `$REGISTRY_ROOT/config.yaml`:

```yaml
storage: ./storage

auth:
  htpasswd:
    file: ./htpasswd
    max_users: 1000

uplinks: {}

packages:
  '@*/*':
    access: $all
    publish: $authenticated
    unpublish: $authenticated
  '**':
    access: $all
    publish: $authenticated
    unpublish: $authenticated

middlewares:
  audit:
    enabled: false

log:
  type: stdout
  format: pretty
  level: http

listen: 0.0.0.0:4873
```

Start and validate it:

```bash
nohup "$REGISTRY_ROOT/node_modules/.bin/verdaccio" \
  --config "$REGISTRY_ROOT/config.yaml" \
  >"$REGISTRY_ROOT/verdaccio.log" 2>&1 &
echo $! > "$REGISTRY_ROOT/verdaccio.pid"

curl -fsS "$LAB_REGISTRY_URL/-/ping"
npm adduser --registry "$LAB_REGISTRY_URL" --auth-type=legacy
npm whoami --registry "$LAB_REGISTRY_URL"
```

### Receiver and editable package

Run the copied receiver directly:

```bash
python3 <ONE_WAY_BEACON_SOURCE>/beacon-listener.py \
  --listen <ATTACKER_INTERFACE_IP> \
  --port 8088 \
  --log /var/tmp/package-lab-beacons.jsonl
```

Keep `tools/react-codeshift/` as an ordinary editable npm package. Before packing it, update and compare the fixed destination in both `payload/heartbeat.py` and `payload/root_marker.c`:

```bash
cd <REACT_CODESHIFT_SOURCE>
npm pack --dry-run
```

Publication is covered by the common [Publish the exercise package](#publish-the-exercise-package) section below.

### Victim

Install the pinned Node archive without the provisioning helper:

```bash
sudo tar -C /opt -xf node-v22.22.0-linux-x64.tar.gz
sudo ln -sfn /opt/node-v22.22.0-linux-x64/bin/node /usr/local/bin/node
sudo ln -sfn /opt/node-v22.22.0-linux-x64/bin/npm /usr/local/bin/npm
sudo ln -sfn /opt/node-v22.22.0-linux-x64/bin/npx /usr/local/bin/npx
```

Install and freeze the copied, approved vulnerable Jammy package manually:

```bash
NEEDRESTART_DEB=<APPROVED_NEEDRESTART_DEB>

source /etc/os-release
[[ "$ID" == "ubuntu" && "$VERSION_ID" == "22.04" ]]

[[ "$(dpkg-deb -f "$NEEDRESTART_DEB" Package)" == "needrestart" ]]
NEEDRESTART_VERSION="$(dpkg-deb -f "$NEEDRESTART_DEB" Version)"
dpkg --compare-versions "$NEEDRESTART_VERSION" lt "3.5-5ubuntu2.2"

sudo dpkg -i "$NEEDRESTART_DEB"

sudo install -d -m 0755 /etc/needrestart/conf.d
printf '%s\n' '$nrconf{interpscan} = 1;' \
  | sudo tee /etc/needrestart/conf.d/package-lab.conf >/dev/null

sudo apt-mark hold needrestart

dpkg-query -W -f='${Version}\n' needrestart
grep -Rns 'interpscan' \
  /etc/needrestart/needrestart.conf \
  /etc/needrestart/conf.d
apt-mark showhold | grep -Fx needrestart
```

The version command must report `3.5-5ubuntu2.1`, the effective configuration must enable `interpscan`, and the final command must print `needrestart`.

Create or reuse the unprivileged developer, configure only that account, and install the copied root-state component:

```bash
id "$LAB_DEVELOPER" >/dev/null 2>&1 || \
  sudo useradd --create-home --shell /bin/bash "$LAB_DEVELOPER"
sudo loginctl enable-linger "$LAB_DEVELOPER"
sudo <ROOT_STATE_AGENT_SOURCE>/install.sh

sudo -iu "$LAB_DEVELOPER" npm config set registry "$LAB_REGISTRY_URL" --location=user
sudo -iu "$LAB_DEVELOPER" npm config set audit false --location=user
sudo -iu "$LAB_DEVELOPER" npm config set fund false --location=user
sudo -iu "$LAB_DEVELOPER" npm config set update-notifier false --location=user
```

Verify the same frozen baseline used by the repository-assisted path:

```bash
node --version
npm --version
python3 --version
cc --version | head -n 1
dpkg-query -W -f='${Version}\n' needrestart
sudo -iu "$LAB_DEVELOPER" npm ping --registry "$LAB_REGISTRY_URL"
```

The victim must report Node `v22.22.0`, npm `10.9.4`, and `needrestart 3.5-5ubuntu2.1`.

Freeze and verify the package version before taking the clean snapshot:

```bash
sudo apt-mark hold needrestart
apt-mark showhold | grep -Fx needrestart
```

The verification command must print `needrestart`. Confirm interpreter scanning and the isolated network policy before taking the snapshot.

</details>

After either setup path, continue with package publication and the operator runbook.

## Publish the exercise package

Run this on the attacker or registry host while authenticated to Verdaccio:

```bash
export ALLOW_LAB_PUBLISH=I_UNDERSTAND_THIS_IS_A_PRIVATE_LAB
./tools/publish-react-codeshift.sh
npm view react-codeshift --registry "$LAB_REGISTRY_URL" \
  name version dist.tarball
```

The expected version is `1.3.1`. The helper refuses the public npm registry and records the tarball hash and publish output under `evidence/runs/<run-id>/red/`.

## Run the scenario

The attacker follows [docs/CALDERA.md](docs/CALDERA.md). The victim-side replay is performed by the prepared developer or White workflow:

```bash
sudo -iu "$LAB_DEVELOPER"
cd "$LAB_INSTALL_ROOT/victim-app/frontend"
LAB_RUN_ID="$LAB_RUN_ID" ./run-ai-replay.sh
```

The initial-access marker appears at:

```text
~/.local/state/package-lab/initial-access.json
```

On the matching vulnerable host, `privilege_fixture.status` should be `armed`. The attacker receiver then reports `armed-alive` with the developer UID/EUID.

After that milestone, the administrator performs an ordinary APT install or reinstall. The lab does not require the attacker to issue a command on the victim. A successful vulnerable scan produces:

- `needrestart-root-execution` with UID/EUID 0;
- `/var/lib/package-lab/cve-2024-48990-root-marker.json` on the victim;
- `root-persistence-alive` from the visible pre-provisioned root-state service.

These events prove different states. `armed-alive` proves developer execution and resident arming. `needrestart-root-execution` proves the privilege transition. `root-persistence-alive` proves the root-owned state remains active; its absence alone does not prove cleanup because the listener or network may be unavailable.

## Reset and remediation

Preserve evidence before cleanup. For a reusable exercise, restore the victim and registry snapshots. For manual teardown:

```bash
sudo ./tools/systemd-marker/remove.sh
sudo -E ./tools/needrestart-cve-2024-48990/cleanup.sh
sudo ./tools/root-state-agent/remove.sh
sudo apt-mark unhold needrestart
./setup/registry-native.sh down
```

Then remove the poisoned package from the isolated registry, clear the dedicated developer's relevant npm cache, remove any project dependency or lockfile entry, remove the `needrestart` hold, and upgrade to the vendor-fixed version. Reboot and perform a benign APT transaction to prove that no marker or event returns.

## Research basis

- [Aikido: Agent Skills Are Spreading Hallucinated npx Commands](https://www.aikido.dev/blog/agent-skills-spreading-hallucinated-npx-commands)
- [USENIX Security 2025: We Have a Package for You!](https://www.usenix.org/conference/usenixsecurity25/presentation/spracklen)
- [Ubuntu CVE-2024-48990 advisory](https://ubuntu.com/security/CVE-2024-48990)
- [Qualys needrestart technical advisory](https://www.qualys.com/2024/11/19/needrestart/needrestart.txt)
- [MITRE ATT&CK T1195.002 - Compromise Software Supply Chain](https://attack.mitre.org/techniques/T1195/002/)
- [MITRE ATT&CK T1068 - Exploitation for Privilege Escalation](https://attack.mitre.org/techniques/T1068/)
- [MITRE ATT&CK T1543.002 - Systemd Service](https://attack.mitre.org/techniques/T1543/002/)

See [SECURITY.md](SECURITY.md) for the repository's safety boundary.
