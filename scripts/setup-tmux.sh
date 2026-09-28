#!/usr/bin/env bash
#
# setup-tmux.sh — ensure tpm (tmux plugin manager) and its plugins exist.
#
# .tmux.conf runs `run '~/.tmux/plugins/tpm/tpm'` on every config load
# (configs/tmux/.tmux.conf:59), but tpm is in no package list — this
# script is what makes that line work on a fresh machine.
#
# Everything here is BEST EFFORT: failures degrade to a warning plus a
# `<prefix> + I` hint instead of failing bootstrap (by the time this runs,
# packages and symlinks are already done).
#
# Runs `tmux` only when work is actually needed, so a fully provisioned
# machine (and any running tmux server) is left completely untouched.
#
# Env: TPM_DIR to override the plugin root; DOTFILES_ROOT/LOG_* as usual.

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

TPM_DIR="${TPM_DIR:-$HOME/.tmux/plugins/tpm}"
PLUGINS_DIR="$(dirname "$TPM_DIR")"
TPM_URL="https://github.com/tmux-plugins/tpm"

# _other_plugins_exist — success when anything besides tpm itself lives in
# the plugins dir (i.e. plugins were installed at some point).
_other_plugins_exist() {
  local d
  for d in "$PLUGINS_DIR"/*/; do
    [[ -d "$d" ]] || continue
    if [[ "$d" != "$TPM_DIR/" ]]; then
      return 0
    fi
  done
  return 1
}

# sync_plugins — ask tpm to install the plugins declared in .tmux.conf.
# Runs inside the tmux server via run-shell; outcome is judged by what
# actually appeared on disk, not by tmux's exit code (older tmux versions
# don't propagate run-shell's status).
sync_plugins() {
  log_info "Installing tmux plugins via tpm (best effort)"

  if ! tmux start-server \; run-shell \
    "GIT_TERMINAL_PROMPT=0 '$TPM_DIR/bin/install_plugins'"; then
    log_warn "tmux reported an error while running tpm"
  fi

  if _other_plugins_exist; then
    log_success "tmux plugins ready: $PLUGINS_DIR"
  else
    log_warn "no plugins installed yet — open tmux and press <prefix> + I (needs network)"
  fi
}

main() {
  if [[ -z "${HOME:-}" ]]; then
    die "HOME is not set"
  fi

  if ! command_exists tmux; then
    log_warn "tmux not installed — skipping plugin setup"
    return 0
  fi

  local fresh=false

  if [[ -d "$TPM_DIR/.git" ]]; then
    log_info "tpm already installed: $TPM_DIR"
  elif [[ -e "$TPM_DIR" ]]; then
    log_warn "tpm directory exists but is not a git repo — leaving it untouched: $TPM_DIR"
  else
    require_command git
    ensure_dir "$PLUGINS_DIR"
    log_info "Installing tpm from $TPM_URL"
    if GIT_TERMINAL_PROMPT=0 git clone --depth 1 "$TPM_URL" "$TPM_DIR"; then
      log_success "tpm installed: $TPM_DIR"
      fresh=true
    else
      log_warn "tpm clone failed (offline?) — tmux will work without plugins; re-run bootstrap when online"
      return 0
    fi
  fi

  # Sync only when something is genuinely missing: a brand-new tpm, or an
  # existing tpm that has never had plugins installed. Otherwise do not
  # talk to the tmux server at all.
  if [[ "$fresh" == false ]] && _other_plugins_exist; then
    log_info "tmux plugins already present — nothing to do"
    return 0
  fi

  sync_plugins
}

main "$@"
