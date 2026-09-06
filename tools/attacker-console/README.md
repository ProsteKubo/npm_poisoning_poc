# Package Lab Attacker Console

This bundle turns a clean Ubuntu desktop VM into the presentation-side console
for the package lab. It hosts the private npm registry and the write-only event
receiver; the host only runs libvirt and stores the VM disks.

Network contract:

- attacker VM: `192.168.88.20/24`
- target VM: `192.168.88.10/24`
- Verdaccio: `http://192.168.88.20:4873`
- event receiver: `http://192.168.88.20:8088/apt-event`

Copy this directory to the attacker VM and run `sudo ./install.sh`. If a
`registry-seed/` directory is present beside the installer, its Verdaccio
storage and htpasswd file are installed as the initial private registry.

The tested local definition is named `Package Lab Attacker`, uses 2 vCPU and
3 GiB RAM, and has two NICs: QEMU user-mode NAT for setup downloads and a
libvirt multicast interface (`230.0.0.1:5558`, MAC
`52:54:00:88:00:20`) for the rootless VM-to-VM link. The target uses the same
multicast endpoint with MAC `52:54:00:88:00:10`. Netplan assigns `.20` and
`.10` respectively. This keeps the host out of the registry/receiver path.

After installation, reboot once and verify:

```bash
systemctl is-active package-lab-registry package-lab-beacon nftables gdm3
curl http://192.168.88.20:4873/-/ping
```

The tracked `*-mcast.xml` and `*-netplan.yaml` files reproduce the private
link. `host-start.sh`, `host-stop.sh`, and `host-view.sh` provide simple host
controls once both libvirt domains exist.

The installer creates the local presentation account `attacker` with the lab
password `attacker`. Change it if this VM is ever attached to a shared network.
The desktop contains launchers for the live event console and registry UI.

The event endpoint accepts only the target IP and only fixed GET reports. It
does not return commands or provide a shell.
