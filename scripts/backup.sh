#!/usr/bin/env bash

set -euo pipefail

if [ -z "${DOTFILES_ROOT:-}" ]; then
  DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# shellcheck disable=SC1091
source "$DOTFILES_ROOT/scripts/utils.sh"

backup_path() {
  local target="$1"

  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    return 0
  fi

  ensure_dir "$BACKUP_DIR"

  local base ts dest index
  base="$(basename "$target")"
  ts="$(date "+%Y%m%d_%H%M%S")"
  dest="$BACKUP_DIR/${base}-${ts}"
  index=0

  while [ -e "$dest" ] || [ -L "$dest" ]; do
    index=$((index + 1))
    dest="$BACKUP_DIR/${base}-${ts}-$index"
  done

  mv "$target" "$dest"
  log_info "Backed up $target -> $dest"
}
