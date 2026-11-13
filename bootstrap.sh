#!/usr/bin/env bash

set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_ROOT

# shellcheck disable=SC1091
source "$DOTFILES_ROOT/scripts/utils.sh"
# shellcheck disable=SC1091
source "$DOTFILES_ROOT/scripts/detect-os.sh"

# setup-symlinks runs FIRST so setup-nvim/setup-ghostty can verify the
# links they report on.
SETUP_SCRIPTS=(
  setup-symlinks
  setup-zsh
  setup-nvim
  setup-tmux
  setup-ghostty
  setup-claude
)

usage() {
  cat <<USAGE
Usage: ./bootstrap.sh [options]

  --skip-packages   link configs and run the setup scripts only
  --only=<script>   run one setup script (implies --skip-packages),
                    one of: ${SETUP_SCRIPTS[*]}
  -h, --help        this message
USAGE
}

SKIP_PACKAGES=""
ONLY=""

# Parsed before log_init so --help/a typo neither writes a log nor
# touches $HOME.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-packages) SKIP_PACKAGES=1 ;;
    --only=*) ONLY="${1#--only=}" ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'bootstrap.sh: unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -n "$ONLY" ]]; then
  # Accept setup-nvim, setup-nvim.sh and scripts/setup-nvim.sh alike.
  ONLY="${ONLY##*/}"
  ONLY="${ONLY%.sh}"
  if [[ " ${SETUP_SCRIPTS[*]} " != *" $ONLY "* ]]; then
    printf 'bootstrap.sh: unknown setup script: %s\n\n' "$ONLY" >&2
    usage >&2
    exit 1
  fi
  SKIP_PACKAGES=1
  SETUP_SCRIPTS=("$ONLY")
fi

LOG_DIR="${LOG_DIR:-$DOTFILES_ROOT/logs}"
BACKUP_DIR="${BACKUP_DIR:-$DOTFILES_ROOT/backups}"
export LOG_DIR BACKUP_DIR

log_init
export LOG_FILE
log_info "Starting bootstrap"

ensure_dir "$LOG_DIR"
ensure_dir "$BACKUP_DIR"

if [ -n "$SKIP_PACKAGES" ]; then
  log_info "Skipping package installation"
else
  OS="$(detect_os || true)"
  if [ -z "$OS" ]; then
    die "Unsupported OS. Supported: arch, macos"
  fi

  log_info "Detected OS: $OS"
  bash "$DOTFILES_ROOT/install/packages.sh" "$OS"
fi

log_info "Running setup scripts"
for script in "${SETUP_SCRIPTS[@]}"; do
  bash "$DOTFILES_ROOT/scripts/$script.sh"
done

log_success "Bootstrap complete"
