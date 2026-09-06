#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "run as root: sudo ./install.sh" >&2
  exit 1
fi

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LAB_ROOT=/opt/package-lab-attacker
PRESENTATION_USER=attacker

if ! id "$PRESENTATION_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash --groups sudo,systemd-journal "$PRESENTATION_USER"
fi
echo "$PRESENTATION_USER:attacker" | chpasswd
usermod -aG sudo,systemd-journal "$PRESENTATION_USER"

# Remove every target-only persistence artifact inherited by a cloned VM.
systemctl disable --now package-lab-root-state.path package-lab-root-state.service 2>/dev/null || true
rm -f /etc/systemd/system/package-lab-root-state.path
rm -f /etc/systemd/system/package-lab-root-state.service
rm -f /usr/local/lib/package-lab/root-state-agent.py
rm -rf /var/lib/package-lab
rm -f /etc/needrestart/conf.d/package-lab.conf
rm -f /home/developer/.config/systemd/user/default.target.wants/package-lab-rearm.service
rm -f /home/developer/.config/systemd/user/package-lab-rearm.service
rm -rf /home/developer/.local/share/package-lab
pkill -u developer -f package-lab-rearm 2>/dev/null || true
apt-mark unhold needrestart >/dev/null 2>&1 || true
env DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade -y needrestart
hostnamectl set-hostname package-lab-attacker
usermod --lock developer 2>/dev/null || true

install -d -o "$PRESENTATION_USER" -g "$PRESENTATION_USER" -m 0750 "$LAB_ROOT"
install -d -o "$PRESENTATION_USER" -g "$PRESENTATION_USER" -m 0750 "$LAB_ROOT/events"
install -d -o "$PRESENTATION_USER" -g "$PRESENTATION_USER" -m 0750 "$LAB_ROOT/registry/storage"
install -m 0755 "$HERE/../one-way-beacon/beacon-listener.py" "$LAB_ROOT/beacon-listener.py"
install -o "$PRESENTATION_USER" -g "$PRESENTATION_USER" -m 0640 "$HERE/registry-config.yaml" "$LAB_ROOT/registry/config.yaml"

if [[ -d "$HERE/registry-seed/storage" ]]; then
  cp -a "$HERE/registry-seed/storage/." "$LAB_ROOT/registry/storage/"
fi
if [[ -f "$HERE/registry-seed/htpasswd" ]]; then
  install -o "$PRESENTATION_USER" -g "$PRESENTATION_USER" -m 0600 "$HERE/registry-seed/htpasswd" "$LAB_ROOT/registry/htpasswd"
else
  install -o "$PRESENTATION_USER" -g "$PRESENTATION_USER" -m 0600 /dev/null "$LAB_ROOT/registry/htpasswd"
fi
chown -R "$PRESENTATION_USER:$PRESENTATION_USER" "$LAB_ROOT"

npm install --omit=dev --prefix "$LAB_ROOT/verdaccio" verdaccio@6.2.4
chown -R "$PRESENTATION_USER:$PRESENTATION_USER" "$LAB_ROOT/verdaccio"

install -m 0644 "$HERE/package-lab-registry.service" /etc/systemd/system/package-lab-registry.service
install -m 0644 "$HERE/package-lab-beacon.service" /etc/systemd/system/package-lab-beacon.service
install -m 0755 "$HERE/attacker-nftables.conf" /etc/nftables.conf
install -m 0644 "$HERE/gdm-custom.conf" /etc/gdm3/custom.conf

install -d -o "$PRESENTATION_USER" -g "$PRESENTATION_USER" -m 0755 "/home/$PRESENTATION_USER/Desktop"
install -d -o "$PRESENTATION_USER" -g "$PRESENTATION_USER" -m 0755 "/home/$PRESENTATION_USER/.config/autostart"

install -o "$PRESENTATION_USER" -g "$PRESENTATION_USER" -m 0755 /dev/stdin "/home/$PRESENTATION_USER/Desktop/Live Events.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Live Package-Lab Events
Comment=Follow armed and root-state reports from the target VM
Exec=gnome-terminal --title=Package-Lab\ Events -- bash -lc 'journalctl -fu package-lab-beacon.service'
Icon=utilities-terminal
Terminal=false
DESKTOP

install -o "$PRESENTATION_USER" -g "$PRESENTATION_USER" -m 0755 /dev/stdin "/home/$PRESENTATION_USER/Desktop/Private npm Registry.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Private npm Registry
Comment=Open the attacker-side Verdaccio UI
Exec=firefox http://192.168.88.20:4873/
Icon=web-browser
Terminal=false
DESKTOP

install -o "$PRESENTATION_USER" -g "$PRESENTATION_USER" -m 0755 /dev/stdin "/home/$PRESENTATION_USER/.config/autostart/package-lab-events.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Package-Lab Event Console
Exec=gnome-terminal --title=Package-Lab\ Events -- bash -lc 'journalctl -fu package-lab-beacon.service'
X-GNOME-Autostart-enabled=true
DESKTOP

install -o "$PRESENTATION_USER" -g "$PRESENTATION_USER" -m 0644 /dev/stdin "/home/$PRESENTATION_USER/.config/autostart/update-notifier.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Update Notifier
Hidden=true
DESKTOP

chown -R "$PRESENTATION_USER:$PRESENTATION_USER" "/home/$PRESENTATION_USER/.config" "/home/$PRESENTATION_USER/Desktop"
touch "/home/$PRESENTATION_USER/.config/gnome-initial-setup-done"
chown "$PRESENTATION_USER:$PRESENTATION_USER" "/home/$PRESENTATION_USER/.config/gnome-initial-setup-done"
sudo -u "$PRESENTATION_USER" env HOME="/home/$PRESENTATION_USER" dbus-run-session \
  gio set "/home/$PRESENTATION_USER/Desktop/Live Events.desktop" metadata::trusted true || true
sudo -u "$PRESENTATION_USER" env HOME="/home/$PRESENTATION_USER" dbus-run-session \
  gio set "/home/$PRESENTATION_USER/Desktop/Private npm Registry.desktop" metadata::trusted true || true

timedatectl set-timezone Europe/Bratislava

# Give a cloned guest its own machine and SSH identities. The current SSH
# session remains usable; reconnects will see the new host key.
NEW_MACHINE_ID=$(tr -d '-' < /proc/sys/kernel/random/uuid)
printf '%s\n' "$NEW_MACHINE_ID" > /etc/machine-id
ln -sfn /etc/machine-id /var/lib/dbus/machine-id
find /etc/ssh -maxdepth 1 -type f -name 'ssh_host_*' -delete
ssh-keygen -A

systemctl daemon-reload
systemctl enable --now nftables package-lab-registry.service package-lab-beacon.service

echo "attacker console installed at $LAB_ROOT"
echo "desktop login: attacker / attacker"
echo "reboot once to apply the new machine identity and graphical autologin"
