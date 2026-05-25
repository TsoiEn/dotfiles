#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT

# shellcheck disable=SC1091
source "$DOTFILES_ROOT/scripts/utils.sh"
# shellcheck disable=SC1091
source "$DOTFILES_ROOT/scripts/detect-os.sh"

LOG_DIR="${LOG_DIR:-$DOTFILES_ROOT/logs}"
BACKUP_DIR="${BACKUP_DIR:-$DOTFILES_ROOT/backups}"
export LOG_DIR BACKUP_DIR

log_init
export LOG_FILE
log_info "Starting bootstrap"

ensure_dir "$LOG_DIR"
ensure_dir "$BACKUP_DIR"

OS="$(detect_os || true)"
if [ -z "$OS" ]; then
  die "Unsupported OS. Supported: arch, macos"
fi

log_info "Detected OS: $OS"

case "$OS" in
  arch)
    bash "$DOTFILES_ROOT/install/arch.sh"
    ;;
  macos)
    bash "$DOTFILES_ROOT/install/macos.sh"
    ;;
  *)
    die "Unsupported OS: $OS"
    ;;
esac

log_info "Running setup scripts"
bash "$DOTFILES_ROOT/scripts/setup-nvim.sh"
bash "$DOTFILES_ROOT/scripts/setup-tmux.sh"
bash "$DOTFILES_ROOT/scripts/setup-ghostty.sh"
bash "$DOTFILES_ROOT/scripts/setup-symlinks.sh"

log_success "Bootstrap complete"
