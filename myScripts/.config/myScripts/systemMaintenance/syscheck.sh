#!/usr/bin/env bash

# syscheck.sh - Daily/weekly system health inspection script
# Designed for Arch/Hyprland systems using systemd

echo "=============================="
echo "🔧 System Maintenance Check 🔧"
echo "=============================="

# 1. Failed systemd services
echo -e "\n[1] 🔥 Checking failed systemd services:"
systemctl --failed || echo "  ⚠️ systemctl failed to run."

# 2. Journal errors since last boot
echo -e "\n[2] 🧾 Recent journalctl errors (boot scope):"
journalctl -p err -b --no-pager | tee /tmp/syscheck-journal-errors.txt
if [[ ! -s /tmp/syscheck-journal-errors.txt ]]; then
  echo "  ✅ No critical errors since last boot."
fi

# 3. XDG desktop portals (commonly broken in Wayland setups)
echo -e "\n[3] 📦 xdg-desktop-portal status:"
systemctl --user status xdg-desktop-portal.service --no-pager | grep -E "Loaded|Active|failed" || echo "  ⚠️ Portal not installed or running?"

# 4. User DBus check
echo -e "\n[4] 🧪 DBus session check:"
if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
  echo "  ⚠️ DBUS_SESSION_BUS_ADDRESS is not set."
else
  echo "  ✅ DBUS_SESSION_BUS_ADDRESS is set."
fi
ls /run/user/$UID/bus &>/dev/null && echo "  ✅ Session bus socket exists." || echo "  ❌ /run/user/$UID/bus missing!"

# 5. Kernel and hardware warnings
echo -e "\n[5] ⚙️ Kernel boot errors (filtered):"
dmesg --level=err,warn | grep -v "ACPI BIOS Error" | tail -n 20 || echo "  (No relevant kernel warnings.)"

# 6. Optional: Check updates available (Arch-based)
if command -v checkupdates &>/dev/null; then
  echo -e "\n[6] 📦 Pending updates (pacman):"
  checkupdates || echo "  ✅ Fully up to date."
fi
