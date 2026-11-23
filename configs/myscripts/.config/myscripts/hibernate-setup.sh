#!/usr/bin/env bash
#
# hibernate-setup.sh — make lid-close / idle sleep stop draining the battery.
#
# This laptop has no S3 (only s2idle), so plain suspend drains ~1-3 %/hr.
# Fix: suspend first, then hibernate after 30 min (zero draw).
# Run once as root:  sudo bash hibernate-setup.sh
# Idempotent. Needs a reboot to take effect (kernel cmdline + initramfs).
# Trade-off: the disk is not encrypted, so the hibernation image holds RAM in the clear.

set -euo pipefail
[ "$EUID" -eq 0 ] || { echo "run as root: sudo bash $0" >&2; exit 1; }

SWAP_DIR=/swap
SWAP=$SWAP_DIR/swapfile
SIZE=16G # >= RAM (15 GiB); shortcut: resize if RAM is upgraded

# 1. btrfs swapfile in its own nested subvolume (snapshots of @ skip it).
[ -e "$SWAP_DIR" ] || btrfs subvolume create "$SWAP_DIR"
[ -e "$SWAP" ] || btrfs filesystem mkswapfile --size "$SIZE" "$SWAP"
grep -q "^$SWAP " /etc/fstab || echo "$SWAP none swap defaults,pri=0 0 0" >>/etc/fstab
swapon --show=NAME | grep -qx "$SWAP" || swapon -p 0 "$SWAP"

# 2. Tell the kernel where the image lives. zram keeps pri 100 for normal use.
UUID=$(findmnt -no UUID /)
OFFSET=$(btrfs inspect-internal map-swapfile -r "$SWAP")
CMD=$(sed -E 's/ ?resume(_offset)?=[^ ]+//g' /etc/kernel/cmdline)
echo "$CMD resume=UUID=$UUID resume_offset=$OFFSET" >/etc/kernel/cmdline

# 3. resume hook must sit after udev and before filesystems.
mkdir -p /etc/mkinitcpio.conf.d
cat >/etc/mkinitcpio.conf.d/10-resume.conf <<'EOF'
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block resume filesystems fsck)
EOF

# 4. Lid close => suspend, then hibernate. On AC just suspend.
mkdir -p /etc/systemd/logind.conf.d /etc/systemd/sleep.conf.d
cat >/etc/systemd/logind.conf.d/10-lid.conf <<'EOF'
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
EOF
cat >/etc/systemd/sleep.conf.d/10-hibernate.conf <<'EOF'
[Sleep]
HibernateDelaySec=30min
HibernateMode=shutdown
EOF

# 5. Rebuild the initramfs / UKIs.
mkinitcpio -P

echo "Done. Reboot, then test: systemctl hibernate"
