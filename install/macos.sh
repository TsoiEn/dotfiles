#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "$DOTFILES_ROOT/install/common.sh"

if [ -z "${LOG_FILE:-}" ]; then
	log_init
fi

PACKAGE_FILE="$DOTFILES_ROOT/install/packages/brew.txt"
log_info "Reading packages from $PACKAGE_FILE"
install_brew_packages "$PACKAGE_FILE"
