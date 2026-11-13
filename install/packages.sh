#!/usr/bin/env bash
#
# packages.sh <arch|macos> — the package layer.
#
# One script for both OSes: they differ only in which package manager is
# made to exist first and which list is read second.
#
# Unlike scripts/setup-*.sh, a failure here is fatal — but an individual
# package that won't install is only a warning (see install/common.sh).
#
# Standalone use: bash install/packages.sh macos

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "$DOTFILES_ROOT/install/common.sh"

if [ -z "${LOG_FILE:-}" ]; then
  log_init
fi

OS="${1:-}"
PACKAGE_DIR="$DOTFILES_ROOT/install/packages"
COMMON_LIST="$PACKAGE_DIR/common.txt"

case "$OS" in
  arch)
    ensure_pacman_sync
    ensure_paru
    log_info "Reading packages from $COMMON_LIST and $PACKAGE_DIR/arch.txt"
    install_arch_packages "$COMMON_LIST" "$PACKAGE_DIR/arch.txt"
    ;;
  macos)
    ensure_brew
    log_info "Reading packages from $COMMON_LIST and $PACKAGE_DIR/brew.txt"
    install_brew_packages "$COMMON_LIST" "$PACKAGE_DIR/brew.txt"
    ;;
  *)
    die "usage: packages.sh <arch|macos>"
    ;;
esac
