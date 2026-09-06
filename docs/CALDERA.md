# CALDERA manual attacker operation

The attacker publishes the prepared package and watches the receiver. The attacker does not log in to the victim or run the administrator's APT transaction.

## Manual steps

### 1. Check the registry

**Name:** Registry preflight

**Description:** Confirm that the isolated registry is reachable and the attacker is authenticated as the publisher.

**Commands:**

```bash
npm whoami --registry "$LAB_REGISTRY_URL"
curl -fsS "$LAB_REGISTRY_URL/-/ping"
```

### 2. Open event monitoring

**Name:** Start the attacker event console

**Description:** Follow receiver events before publishing and keep the console open throughout the attack window. Record the monitoring start time in UTC.

**Commands:**

```bash
journalctl --utc -fu package-lab-beacon.service
```

### 3. Set the receiver address

**Name:** Select the attacker callback interface

**Description:** Identify the attacker address used to reach the victim and place it in the working payload sources before publication. White must confirm that the already-installed root-state watcher uses the same address; editing the attacker copy does not change the deployed victim. Stop if they differ.

**Commands:**

```bash
ip -brief -4 address
ip route get <VICTIM_IP>

export RECEIVER_IP=<ATTACKER_IP_REACHABLE_FROM_VICTIM>
export PREVIOUS_RECEIVER_IP=192.168.88.20

sed -i "s/${PREVIOUS_RECEIVER_IP}/${RECEIVER_IP}/g" \
  tools/react-codeshift/payload/heartbeat.py \
  tools/react-codeshift/payload/root_marker.c \
  tools/needrestart-cve-2024-48990/root_marker.c \
  tools/root-state-agent/root-state-agent.py

grep -nF "$RECEIVER_IP" \
  tools/react-codeshift/payload/heartbeat.py \
  tools/react-codeshift/payload/root_marker.c \
  tools/needrestart-cve-2024-48990/root_marker.c \
  tools/root-state-agent/root-state-agent.py

cmp tools/needrestart-cve-2024-48990/root_marker.c \
  tools/react-codeshift/payload/root_marker.c
```

### 4. Publish the prepared package

**Name:** Publish react-codeshift 1.3.1

**Description:** Publish the approved fixture to the isolated registry and preserve the generated package metadata and SHA-256. If version 1.3.1 is already present, record its metadata instead of changing the version.

**Commands:**

```bash
export LAB_RUN_ID=<RUN_ID>
export ALLOW_LAB_PUBLISH=I_UNDERSTAND_THIS_IS_A_PRIVATE_LAB
./tools/publish-react-codeshift.sh

npm view react-codeshift --registry "$LAB_REGISTRY_URL"   name version dist.tarball
```

### 5. Wait for developer execution

**Name:** Observe the unprivileged foothold

**Description:** After White starts the prepared developer workflow, check existing receiver records or follow them live. The accepted event must come from the expected victim and contain the same non-root UID and EUID. Do not trigger the workflow from the attacker host.

**Commands:**

```bash
# Check events already recorded:
journalctl --utc -u package-lab-beacon.service --no-pager | grep -- '"event": "armed-alive"'

# If it has not arrived yet, follow live:
journalctl --utc -fu package-lab-beacon.service | grep --line-buffered -- '"event": "armed-alive"'

# GOOD: expected host and source_ip, with matching non-root IDs:
# "event": "armed-alive" ... "host": "<EXPECTED_VICTIM>" ... "uid": "1001" ... "euid": "1001"

# BAD: unexpected host/source, uid/euid do not match, either ID is 0,
#      or no matching event appears during the agreed developer window.
```

### 6. Wait for the administrator action

**Name:** Observe needrestart root execution

**Description:** After White confirms that the ordinary APT transaction ran, check for the root-execution event. It must come from the same victim observed in step 5 and contain UID/EUID 0. The attacker must not run the APT command.

**Commands:**

```bash
# Check events already recorded:
journalctl --utc -u package-lab-beacon.service --no-pager | grep -- '"event": "needrestart-root-execution"'

# If it has not arrived yet, follow live:
journalctl --utc -fu package-lab-beacon.service | grep --line-buffered -- '"event": "needrestart-root-execution"'

# GOOD: same victim as step 4, after armed-alive, with root IDs:
# "event": "needrestart-root-execution" ... "host": "<EXPECTED_VICTIM>" ... "uid": "0" ... "euid": "0"

# BAD: non-root IDs, a different host/source, an event timestamp before
#      armed-alive, or no event after White confirms APT completed.
```

### 7. Confirm retained root state

**Name:** Observe the root-state heartbeat

**Description:** Check for `root-persistence-alive` from the same victim, then leave the live view open until a later heartbeat confirms that the root-owned state remains active. Missing data is “not observed,” not proof of cleanup.

**Commands:**

```bash
# Check heartbeats already recorded:
journalctl --utc -u package-lab-beacon.service --no-pager | grep -- '"event": "root-persistence-alive"'

# Follow live until a later heartbeat arrives:
journalctl --utc -fu package-lab-beacon.service | grep --line-buffered -- '"event": "root-persistence-alive"'

# GOOD: at least two events from the expected victim at different times,
# both with "uid": "0" and "euid": "0".

# BAD: non-root IDs, a different host/source, or only one event with no
# later heartbeat. No event is inconclusive and must be recorded as not observed.
```

### 8. Close the operation

**Name:** Preserve attacker evidence

**Description:** Stop log-following after the agreed window. Export the CALDERA operation and retain the registry metadata, publish evidence, receiver JSONL or journal, victim identity, and first-seen event times. Give the run ID and UTC window to White/DFIR.

**Commands:**

```bash
find <EVIDENCE_DIRECTORY> -type f -print0   | sort -z   | xargs -0 sha256sum > <EVIDENCE_DIRECTORY>/SHA256SUMS
```

## Completion condition

The manual operation is complete when package provenance is preserved and the receiver has observed, in order, `armed-alive`, `needrestart-root-execution`, and `root-persistence-alive` from the expected victim during the same run window.
