#!/usr/bin/env bash

set -euo pipefail

detect_os() {
  local kernel
  kernel="$(uname -s)"

  case "$kernel" in
    Darwin)
      printf "%s\n" "macos"
      return 0
      ;;
    Linux)
      if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [ "${ID:-}" = "arch" ]; then
          printf "%s\n" "arch"
          return 0
        fi
        if printf "%s" "${ID_LIKE:-}" | grep -qi "arch"; then
          printf "%s\n" "arch"
          return 0
        fi
      fi
      ;;
  esac

  return 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  detect_os
fi
