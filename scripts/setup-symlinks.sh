#!/usr/bin/env bash

set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
  DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# shellcheck disable=SC1091
source "$DOTFILES_ROOT/scripts/utils.sh"
# shellcheck disable=SC1091
source "$DOTFILES_ROOT/scripts/backup.sh"

CONFIGS_DIR="$DOTFILES_ROOT/configs"

link_item() {
  local src="$1"
  local dest="$2"
  local src_abs

  if [ ! -e "$src" ]; then
    log_warn "Missing source path: $src"
    return 0
  fi

  src_abs="$(abs_path "$src")"

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src_abs" ]; then
    log_info "Already linked: $dest"
    return 0
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup_path "$dest"
  fi

  ensure_dir "$(dirname "$dest")"
  ln -s "$src_abs" "$dest"
  log_info "Linked $dest -> $src_abs"
}

link_config_dir() {
  local rel="$1"
  local dest="$2"
  local src="$CONFIGS_DIR/$rel"
  link_item "$src" "$dest"
}

link_config_file() {
  local rel="$1"
  local dest="$2"
  local src="$CONFIGS_DIR/$rel"
  link_item "$src" "$dest"
}

setup_all_symlinks() {
  link_config_dir "nvim" "$HOME/.config/nvim"
  link_config_dir "tmux" "$HOME/.config/tmux"
  link_config_dir "ghostty" "$HOME/.config/ghostty"

  link_config_file "zsh/.zshrc" "$HOME/.zshrc"
  link_config_file "git/.gitconfig" "$HOME/.gitconfig"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  if [ -z "${LOG_FILE:-}" ]; then
    log_init
  fi
  setup_all_symlinks
fi
