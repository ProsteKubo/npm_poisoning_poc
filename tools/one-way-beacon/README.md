# One-way local beacon

The lab components send fixed HTTP GETs to the attacker VM at `192.168.88.20:8088/apt-event`.
They send only the event name, guest hostname, UID/EUID, timestamp, and fixture ID.
It never reads or acts on the HTTP response, accepts no commands, and gives up after
at most 500 ms if the listener is unavailable.

Run the receiver on the attacker VM's private target link:

```bash
python3 ./tools/one-way-beacon/beacon-listener.py \
  --listen 192.168.88.20 \
  --port 8088 \
  --log ./beacons.jsonl
```

Requests to `/apt-event` are accepted regardless of routed or NAT-translated source address. The observed source address is retained in each record. Accepted events are printed to stdout. The JSONL file is tagged in source as a
`DEBUG_ONLY_JSON_ARTIFACT`; remove that write in production builds if persistent
structured evidence would make the exercise too easy.

Expected live events are:

- `armed-alive` every 30 seconds from the persistent developer fixture
- `needrestart-root-execution` during each genuine EUID 0 transition
- `root-persistence-alive` every 30 seconds while the root-owned state remains
