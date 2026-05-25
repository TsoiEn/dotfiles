#!/usr/bin/env bash

set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
  DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# shellcheck disable=SC1091
source "$DOTFILES_ROOT/scripts/setup-symlinks.sh"

if [ -z "${LOG_FILE:-}" ]; then
  log_init
fi

link_config_dir "nvim" "$HOME/.config/nvim"
