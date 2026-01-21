#!/usr/bin/env bash
# syscheck-min.sh — Quick Arch/Hyprland system health check

echo "== System Health Check =="

# Failed services
systemctl --failed --no-pager || echo "No failed systemd services."

# Journal errors since boot
echo -e "\nRecent journal errors:"
journalctl -p err -b --no-pager | tail -n 10 || echo "No errors since boot."

# Kernel warnings (short)
echo -e "\nKernel warnings:"
dmesg --level=err,warn | tail -n 10 || echo "No kernel warnings."

# Pending updates
if command -v checkupdates &>/dev/null; then
  echo -e "\nPending updates:"
  checkupdates || echo "System up to date."
fi
