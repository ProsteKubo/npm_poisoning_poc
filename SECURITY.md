# Isolated-lab security boundary

This repository contains a working, marker-only reproduction of CVE-2024-48990 integrated into a simulated poisoned npm package.

- Keep the repository private except for the shortest bootstrap window needed to clone it onto isolated lab machines.
- Never commit credentials, tokens, registry `htpasswd`, generated evidence, or offline package archives.
- Never publish the package to the public npm registry.
- Use only isolated, resettable lab machines.
- The privileged payload may create only `/var/lib/package-lab/cve-2024-48990-root-marker.json`.
- Do not add shells, credential collection, external callbacks, or destructive actions.
- Restore the developer VM snapshot and patch `needrestart` after testing.
