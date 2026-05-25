#!/usr/bin/env bash

set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
  DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# shellcheck disable=SC1091
source "$DOTFILES_ROOT/scripts/utils.sh"

PACMAN_FLAGS="${PACMAN_FLAGS:---needed --noconfirm}"
PARU_FLAGS="${PARU_FLAGS:---needed --noconfirm}"
BREW_FLAGS="${BREW_FLAGS:-}"

read_package_list() {
  local file="$1"

  if [ ! -f "$file" ]; then
    die "Package list not found: $file"
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(printf "%s" "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [ -n "$line" ]; then
      printf "%s\n" "$line"
    fi
  done < "$file"
}

install_arch_packages() {
  local file="$1"
  local installer="pacman"

  require_command pacman

  if command_exists paru; then
    installer="paru"
    log_info "Using paru for AUR support"
  fi

  while IFS= read -r pkg; do
    if pacman -Qi "$pkg" >/dev/null 2>&1; then
      log_info "Skipping installed package: $pkg"
      continue
    fi

    log_info "Installing package: $pkg"
    if [ "$installer" = "paru" ]; then
      paru -S $PARU_FLAGS "$pkg"
    else
      run_as_root pacman -S $PACMAN_FLAGS "$pkg"
    fi
  done < <(read_package_list "$file")
}

_install_brew_formula() {
  local name="$1"
  if brew list --formula -1 | grep -Fx "$name" >/dev/null 2>&1; then
    log_info "Skipping installed formula: $name"
  else
    log_info "Installing formula: $name"
    brew install $BREW_FLAGS "$name"
  fi
}

_install_brew_cask() {
  local name="$1"
  if brew list --cask -1 | grep -Fx "$name" >/dev/null 2>&1; then
    log_info "Skipping installed cask: $name"
  else
    log_info "Installing cask: $name"
    brew install --cask $BREW_FLAGS "$name"
  fi
}

install_brew_packages() {
  local file="$1"

  require_command brew

  while IFS= read -r pkg; do
    case "$pkg" in
      cask:*)
        _install_brew_cask "${pkg#cask:}"
        ;;
      *)
        _install_brew_formula "$pkg"
        ;;
    esac
  done < <(read_package_list "$file")
}
