#!/usr/bin/env bash
#
# detect-os.sh — OS detection for the dotfiles bootstrap.
#
# Defines `detect_os`, which prints a single token on stdout:
#   arch | macos
# and returns 1 when the OS is unsupported (stdout stays empty, so
# bootstrap.sh's `OS="$(detect_os || true)"` sees "" and calls `die`).
#
# Diagnostics go to stderr only — never stdout, which is captured.
#
# Sourcing this file defines the function and runs nothing else.
# Executing it directly (`bash scripts/detect-os.sh`) prints the result.
#
# Test hook: OS_RELEASE_FILE overrides /etc/os-release for distro sims.

detect_os() {
  local kernel
  kernel="$(uname -s 2>/dev/null)" || return 1

  case "$kernel" in
    Darwin)
      printf 'macos\n'
      return 0
      ;;
    Linux) ;;
    *)
      printf 'detect_os: unsupported kernel: %s\n' "$kernel" >&2
      return 1
      ;;
  esac

  # --- Linux: identify the distro from os-release (parsed, not sourced) ---
  local os_release="${OS_RELEASE_FILE:-/etc/os-release}"
  local id="" id_like=""

  # `|| true` is required: ID_LIKE is often absent (plain Arch), and a
  # failed command substitution would trip the caller's `set -e`.
  if [[ -r "$os_release" ]]; then
    id="$(_os_release_value "ID" "$os_release")" || true
    id_like="$(_os_release_value "ID_LIKE" "$os_release")" || true
  fi

  # ID=arch (Arch, Arch-derived) or ID_LIKE contains "arch"
  # (Manjaro -> ID_LIKE="arch", EndeavourOS -> ID_LIKE="arch").
  if [[ "$id" == "arch" ]] || [[ " $id_like " == *" arch "* ]]; then
    printf 'arch\n'
    return 0
  fi

  # Fallback: no/empty os-release but pacman present => Arch family.
  if [[ -z "$id" ]] && command -v pacman >/dev/null 2>&1; then
    printf 'arch\n'
    return 0
  fi

  printf 'detect_os: unsupported Linux distro (ID=%s ID_LIKE=%s)\n' \
    "${id:-unknown}" "${id_like:-none}" >&2
  return 1
}

# _os_release_value <key> <file> — read one KEY=... value from os-release.
# Pure bash (no grep/sed fork), handles quoted values. Prints nothing and
# returns 1 when the key is absent.
_os_release_value() {
  local key="$1" file="$2" line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$key="* ]]; then
      line="${line#*=}"
      line="${line#\"}" && line="${line%\"}"
      line="${line#\'}" && line="${line%\'}"
      printf '%s' "$line"
      return 0
    fi
  done < "$file"
  return 1
}

# Allow `bash scripts/detect-os.sh` / `./scripts/detect-os.sh`.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  detect_os
fi
