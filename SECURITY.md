# Isolated-lab security boundary

This repository contains a working reproduction of CVE-2024-48990 integrated into a simulated poisoned npm package. Its only network behavior is a fixed, one-way event GET inside the local lab.

- Keep the repository private except for the shortest bootstrap window needed to clone it onto isolated lab machines.
- Never commit credentials, tokens, registry `htpasswd`, generated evidence, or offline package archives.
- Never publish the package to the public npm registry.
- Use only isolated, resettable lab machines.
- The privileged payload may create only `/var/lib/package-lab/cve-2024-48990-root-marker.json`, `/var/lib/package-lab/root-stage-observed`, and the fixed event GET to `192.168.88.20:8088/apt-event` on the isolated attacker VM.
- The callback must remain one-way: do not parse its response or add remote commands.
- Persistence must remain visible under the documented `package-lab-*` unit and process names. Do not add shells, credential collection, Internet callbacks, covert persistence, or destructive actions.
- The root-state service must remain pre-provisioned, commandless, fixed-destination, capability-bounded, and systemd-sandboxed; the privileged constructor may activate it only through the scoped root-owned state file.
- Restore the developer VM snapshot and patch `needrestart` after testing.
