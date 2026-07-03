#!/usr/bin/env bash
# One-time host setup so Tank's HDMI display boots into the dashboard kiosk.
# Installs a minimal GNOME session and Firefox, enables autologin, and
# disables idle blanking. Run on Tank:
#
#   sudo bash ~/nobs/scripts/setup-kiosk-host.sh
#
# After it finishes, reboot. GNOME autologin starts the kiosk via
# ~/.config/autostart/nobs-dashboard-kiosk.desktop.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

KIOSK_USER="${SUDO_USER:-alex}"

echo "==> Installing minimal desktop and Firefox (this can take several minutes)"
apt-get update
apt-get install -y --no-install-recommends ubuntu-desktop-minimal
snap install firefox

echo "==> Enabling GDM autologin for ${KIOSK_USER}"
conf=/etc/gdm3/custom.conf
touch "$conf"
if grep -q '^AutomaticLoginEnable' "$conf"; then
  sed -i "s/^AutomaticLoginEnable.*/AutomaticLoginEnable=true/" "$conf"
  sed -i "s/^AutomaticLogin[[:space:]]*=.*/AutomaticLogin=${KIOSK_USER}/" "$conf"
elif grep -q '^\[daemon\]' "$conf"; then
  sed -i "/^\[daemon\]/a AutomaticLoginEnable=true\nAutomaticLogin=${KIOSK_USER}" "$conf"
else
  printf '[daemon]\nAutomaticLoginEnable=true\nAutomaticLogin=%s\n' "${KIOSK_USER}" >>"$conf"
fi

echo "==> Disabling idle screen blanking for the always-on display"
mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
printf 'user-db:user\nsystem-db:local\n' >/etc/dconf/profile/user
printf '[org/gnome/desktop/session]\nidle-delay=uint32 0\n' >/etc/dconf/db/local.d/00-nobs-kiosk
dconf update

systemctl set-default graphical.target

echo
echo "Done. Reboot to start the kiosk display: sudo reboot"
