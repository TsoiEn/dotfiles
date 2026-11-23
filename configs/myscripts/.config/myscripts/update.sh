#!/usr/bin/env bash
#
# update.sh — one clean Arch update, in the order that keeps it clean.
#
# The problem it solves: "update" on Arch is never one command. A full
# -Syu is only the middle of it: the news comes first (a manual
# intervention found afterwards is found too late), and the leftovers come
# after — orphans no package depends on any more, old versions filling
# /var/cache/pacman, .pacnew files holding config the new version expects,
# a kernel that was replaced under the running one.
#
# So every step here is a step people skip and then pay for, and nothing
# else is in it. Each step prints the command before it runs it, skips
# itself when the tool is not on the machine, and asks before removing
# anything — the prompts are pacman's own, not a layer over them.
#
# Deliberately NOT done:
#   - `pacman -Sy <anything>`, including archlinux-keyring: a sync without
#     a full upgrade is the partial upgrade that breaks the system. If the
#     keyring is too old to verify signatures, -Syu says so and that is
#     the moment to fix it, on purpose.
#   - -Syyu / --overwrite / forcing anything past an error.
#   - pacdiff's merge: which .pacnew to take is a decision, so this prints
#     the list and the command, and leaves it.
#
# Usage:
#   update                 # news, upgrade, orphans, cache, pacnew, report
#   update -n              # print every command, run none of them
#   update -h
#
# Needs: pacman. Uses, when present: paru/yay (AUR), flatpak, paccache and
# pacdiff (pacman-contrib), informant (Arch news), checkupdates.
#
# Env overrides: NO_COLOR
#
# Arch-only, so bash 5 and mapfile are fair game (unlike pkg.sh, which
# also runs on macOS's bash 3.2).

set -uo pipefail

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'
else
  C_RESET='' C_DIM='' C_BOLD='' C_GREEN='' C_YELLOW=''
fi

have() { command -v "$1" >/dev/null 2>&1; }

DRY=""

# The header block above, whatever length it grows to.
usage() {
  awk 'NR > 2 && /^#/ { sub(/^# ?/, ""); print; next } NR > 2 { exit }' "$0"
}

step() { printf '\n%s==> %s%s\n' "$C_BOLD" "$1" "$C_RESET"; }
skip() { printf '%s    skipped: %s%s\n' "$C_DIM" "$1" "$C_RESET"; }

# run <command...> — print it, then run it unless this is a dry run. Every
# command that changes the machine goes through here, so -n is honest.
run() {
  printf '%s+ %s%s\n' "$C_DIM" "$*" "$C_RESET"
  [[ -n "$DRY" ]] && return 0
  "$@"
}

AUR_HELPER="$(command -v paru 2>/dev/null || command -v yay 2>/dev/null || true)"

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  -n | --dry-run) DRY=1 ;;
  '') ;;
  *)
    printf '%s: unknown option: %s\n' "${0##*/}" "$1" >&2
    exit 1
    ;;
esac

have pacman || {
  printf '%s: pacman not found — this is the Arch updater\n' "${0##*/}" >&2
  exit 1
}

# ---------------------------------------------------------------------------
step "Arch news"
# ---------------------------------------------------------------------------
# informant exits non-zero while there is unread news, and that is the
# whole point of reading it before the upgrade, not after.
if have informant; then
  if ! run sudo informant check; then
    printf '%sunread Arch news above — read it, then run update again%s\n' \
      "$C_YELLOW" "$C_RESET"
    printf '%s  sudo informant read%s\n' "$C_DIM" "$C_RESET"
    exit 1
  fi
else
  skip "informant not installed (https://archlinux.org/news/ is the manual read)"
fi

# ---------------------------------------------------------------------------
step "Upgrade"
# ---------------------------------------------------------------------------
# An AUR helper's -Syu is the repo upgrade plus the AUR rebuilds, so it
# replaces pacman's rather than running after it.
if [[ -n "$AUR_HELPER" ]]; then
  run "$AUR_HELPER" -Syu
else
  run sudo pacman -Syu
fi || {
  printf '%s: upgrade failed — stopping before the cleanup\n' "${0##*/}" >&2
  exit 1
}

if have flatpak; then
  step "Flatpak"
  run flatpak update
fi

# ---------------------------------------------------------------------------
step "Orphans"
# ---------------------------------------------------------------------------
# -Qtdq is every package installed as a dependency that nothing requires
# any more. pacman does the asking: -Rns without --noconfirm prompts with
# the full list, which is the confirmation worth having.
orphans=()
mapfile -t orphans < <(pacman -Qtdq 2>/dev/null)
if ((${#orphans[@]})); then
  printf '%s\n' "${orphans[@]}" | sed 's/^/    /'
  run sudo pacman -Rns "${orphans[@]}"
else
  skip "none"
fi

# ---------------------------------------------------------------------------
step "Package cache"
# ---------------------------------------------------------------------------
# Two past versions of what is installed stay, for the downgrade that a bad
# update needs; everything uninstalled goes, since there is nothing to go
# back to. Dropping the cache entirely is what makes a rollback impossible.
if have paccache; then
  run sudo paccache -rk2
  run sudo paccache -ruk0
else
  skip "paccache not installed (pacman -S pacman-contrib)"
fi

# ---------------------------------------------------------------------------
step ".pacnew files"
# ---------------------------------------------------------------------------
# A .pacnew is the new default sitting beside your edited config: until it
# is merged, the package is running on options it did not ship.
if have pacdiff; then
  pacnew="$(pacdiff -o 2>/dev/null)"
  if [[ -n "$pacnew" ]]; then
    printf '%s\n' "$pacnew" | sed 's/^/    /'
    printf '%smerge them when you have a minute:%s\n' "$C_YELLOW" "$C_RESET"
    printf '%s  sudo -E DIFFPROG="nvim -d" pacdiff%s\n' "$C_DIM" "$C_RESET"
  else
    skip "none"
  fi
else
  skip "pacdiff not installed (pacman -S pacman-contrib)"
fi

# ---------------------------------------------------------------------------
step "After the update"
# ---------------------------------------------------------------------------
# The modules of the running kernel are deleted the moment it is replaced,
# so a missing directory for `uname -r` is the reboot notice.
if [[ ! -d "/usr/lib/modules/$(uname -r)" ]]; then
  printf '%sthe running kernel %s was replaced — reboot%s\n' \
    "$C_YELLOW" "$(uname -r)" "$C_RESET"
fi

# An upgrade restarts nothing: a unit that died during it stays dead.
failed="$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{ print $1 }')"
if [[ -n "$failed" ]]; then
  printf '%sfailed units:%s\n' "$C_YELLOW" "$C_RESET"
  printf '%s\n' "$failed" | sed 's/^/    /'
fi

printf '%sup to date%s\n' "$C_GREEN" "$C_RESET"
