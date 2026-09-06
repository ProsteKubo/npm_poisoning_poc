# Visible persistent root-state heartbeat

This is an intentionally visible competition artifact, provisioned once with the
lab image. It is not installed by the vulnerable constructor.

The enabled `.path` unit waits for the root-only state file
`/var/lib/package-lab/root-stage-observed`. A genuine EUID 0 constructor execution
creates that file, which starts the root service. The service survives reboot and
sends `root-persistence-alive` every 30 seconds to the fixed local listener.

The service accepts no input, reads no HTTP response, has no command channel, and
runs with an empty capability bounding set plus restrictive systemd sandboxing.
Its unit name, process, source, status, and journal are deliberately inspectable.

Provision or fully remove it with:

```bash
sudo ./tools/root-state-agent/install.sh
sudo ./tools/root-state-agent/remove.sh
```

Removing only the state file stops the active root heartbeat while leaving the
competition watcher ready for the next round.
