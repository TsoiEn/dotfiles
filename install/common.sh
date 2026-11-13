#!/usr/bin/env bash

set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
  DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# shellcheck disable=SC1091
source "$DOTFILES_ROOT/scripts/utils.sh"
# shellcheck disable=SC1091
source "$DOTFILES_ROOT/install/bootstrap-pm.sh"

PACMAN_FLAGS="${PACMAN_FLAGS:---needed --noconfirm}"
PARU_FLAGS="${PARU_FLAGS:---needed --noconfirm}"
BREW_FLAGS="${BREW_FLAGS:-}"

# read_package_list <file>... — print every package name from the given
# lists, in order. Several files so callers can pass common.txt then the
# per-OS list.
read_package_list() {
  local file line

  for file in "$@"; do
    if [ ! -f "$file" ]; then
      die "Package list not found: $file"
    fi

    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%%#*}"
      line="$(printf "%s" "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      if [ -n "$line" ]; then
        printf "%s\n" "$line"
      fi
    done <"$file"
  done
}

# A failed package must not abort the run: `set -e` here would mean
# bootstrap.sh never reaches the symlink step.
_INSTALL_FAILED=()

_try_install() {
  local pkg="$1"
  shift

  if ! "$@"; then
    log_warn "Failed to install: $pkg — continuing"
    _INSTALL_FAILED+=("$pkg")
  fi
}

_report_install_failures() {
  if [ ${#_INSTALL_FAILED[@]} -gt 0 ]; then
    log_warn "${#_INSTALL_FAILED[@]} package(s) failed: ${_INSTALL_FAILED[*]}"
  fi
}

install_arch_packages() {
  local installer="pacman"

  require_command pacman

  if command_exists paru; then
    installer="paru"
    log_info "Using paru for AUR support"
  fi

  _INSTALL_FAILED=()

  while IFS= read -r pkg; do
    case "$pkg" in
      # common.txt is shared, so a cask: line can reach pacman, which would
      # take "cask:ghostty" for a package name.
      cask:*)
        log_info "Skipping macOS-only cask: ${pkg#cask:}"
        continue
        ;;
    esac

    if pacman -Qi "$pkg" >/dev/null 2>&1; then
      log_info "Skipping installed package: $pkg"
      continue
    fi

    log_info "Installing package: $pkg"
    # shellcheck disable=SC2086  # flag splitting is intentional
    if [ "$installer" = "paru" ]; then
      _try_install "$pkg" paru -S $PARU_FLAGS "$pkg"
    else
      _try_install "$pkg" run_as_root pacman -S $PACMAN_FLAGS "$pkg"
    fi
  done < <(read_package_list "$@")

  _report_install_failures
}

# Snapshots taken once per run by install_brew_packages: `brew list` is a
# slow fork and the per-package loop ran it every iteration.
_BREW_FORMULAE=""
_BREW_CASKS=""

_install_brew_formula() {
  local name="$1"
  if printf '%s\n' "$_BREW_FORMULAE" | grep -Fx "$name" >/dev/null 2>&1; then
    log_info "Skipping installed formula: $name"
  else
    log_info "Installing formula: $name"
    # shellcheck disable=SC2086  # flag splitting is intentional
    _try_install "$name" brew install $BREW_FLAGS "$name"
  fi
}

_install_brew_cask() {
  local name="$1"
  if printf '%s\n' "$_BREW_CASKS" | grep -Fx "$name" >/dev/null 2>&1; then
    log_info "Skipping installed cask: $name"
  else
    log_info "Installing cask: $name"
    # shellcheck disable=SC2086  # flag splitting is intentional
    _try_install "cask:$name" brew install --cask $BREW_FLAGS "$name"
  fi
}

install_brew_packages() {
  require_command brew

  _INSTALL_FAILED=()
  _BREW_FORMULAE="$(brew list --formula -1 || true)"
  _BREW_CASKS="$(brew list --cask -1 || true)"

  while IFS= read -r pkg; do
    case "$pkg" in
      cask:*)
        _install_brew_cask "${pkg#cask:}"
        ;;
      *)
        _install_brew_formula "$pkg"
        ;;
    esac
  done < <(read_package_list "$@")

  _report_install_failures
}
