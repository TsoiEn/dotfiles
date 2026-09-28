#!/usr/bin/env bash
#
# setup-nvim.sh — verify Neovim config wiring, report plugin state.
#
# Neovim needs nothing installed here beyond the package lists:
#   - config:  linked by setup-symlinks.sh (bootstrap runs that FIRST)
#   - plugins: lazy.nvim self-bootstraps on first launch
#              (configs/nvim/.config/nvim/lua/tsoien/lazy.lua:1-14)
#
# Default run is offline and forks no nvim process at all. Set
#   SETUP_NVIM_SYNC=1
# to additionally run `:Lazy! sync` headlessly (network, can take minutes
# — opt-in only). Its output is appended to $LOG_FILE, never the console.
#
# All problems here are warnings: a broken nvim check must not fail
# bootstrap after packages and symlinks already succeeded.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${DOTFILES_ROOT:-}" ]]; then
  DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  export DOTFILES_ROOT
fi

# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR/utils.sh"

if [[ -z "${LOG_FILE:-}" ]]; then
  log_init
  export LOG_FILE
fi

# stdpath('data') on Linux/macOS is ${XDG_DATA_HOME:-~/.local/share}/nvim,
# so lazy.nvim lives at <data>/lazy/lazy.nvim. Computing this ourselves
# (instead of asking a headless nvim) keeps the default check instant and
# guaranteed-offline.
nvim_data_dir() {
  printf '%s/nvim' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

main() {
  if [[ -z "${HOME:-}" ]]; then
    die "HOME is not set"
  fi

  if ! command_exists nvim; then
    log_warn "neovim not installed — skipping nvim setup"
    return 0
  fi

  # --- 1. config wiring (setup-symlinks.sh runs before this in bootstrap) ---
  local cfg="$HOME/.config/nvim"
  if [[ ! -e "$cfg/init.lua" ]]; then
    log_warn "nvim config missing at $cfg/init.lua — run scripts/setup-symlinks.sh first"
  elif [[ -L "$cfg" ]]; then
    log_info "nvim config linked: $cfg -> $(readlink "$cfg")"
  else
    log_info "nvim config present (not a symlink): $cfg"
  fi

  # --- 2. plugin manager state ---------------------------------------------
  local lazy_root lazy_dir
  lazy_root="$(nvim_data_dir)/lazy"
  lazy_dir="$lazy_root/lazy.nvim"

  if [[ -d "$lazy_dir" ]]; then
    local total plugins
    total="$(find "$lazy_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    plugins=$((total > 0 ? total - 1 : 0))
    log_info "lazy.nvim installed: $lazy_dir ($plugins plugin(s))"
  else
    log_info "lazy.nvim not installed yet — it bootstraps on first nvim launch"
  fi

  # --- 3. optional headless sync (opt-in) ----------------------------------
  if [[ "${SETUP_NVIM_SYNC:-0}" == "1" ]]; then
    log_info "SETUP_NVIM_SYNC=1 — running :Lazy! sync (network, may take a while)"
    if nvim --headless "+Lazy! sync" +qa >>"${LOG_FILE:-/dev/null}" 2>&1; then
      log_success "lazy.nvim plugins synced"
    else
      log_warn ":Lazy! sync reported errors — open nvim and run :Lazy sync (output in ${LOG_FILE:-the log})"
    fi
  fi

  log_success "nvim setup checks complete"
}

main "$@"
