#!/usr/bin/env bash
#
# setup-symlinks.sh — link the repo's configs/ tree into $HOME.
#
# Entry point: bootstrap.sh runs this FIRST (before the per-app setup
# scripts), so setup-nvim.sh can verify ~/.config/nvim afterwards.
#
# Strategy: directory-level links — six top-level targets, whole
# directories linked at once. New files added under configs/ inside those
# directories require no changes here.
#
# Per target:
#   1. validate ALL sources first (never touch $HOME on a broken repo)
#   2. already a symlink into this repo  -> skip (idempotent re-run)
#   3. something else exists there       -> backup_path, then link
#   4. nothing exists                    -> mkdir -p parent, link
#
# Standalone use:  bash scripts/setup-symlinks.sh
# Env overrides:   DOTFILES_ROOT, LOG_DIR, LOG_FILE, BACKUP_DIR, HOME

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${DOTFILES_ROOT:-}" ]]; then
  DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  export DOTFILES_ROOT
fi

# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR/utils.sh"
# shellcheck source=scripts/backup.sh
source "$SCRIPT_DIR/backup.sh"

# Same default as bootstrap.sh:14 so standalone runs work too.
BACKUP_DIR="${BACKUP_DIR:-$DOTFILES_ROOT/backups}"
export BACKUP_DIR

if [[ -z "${LOG_FILE:-}" ]]; then
  log_init
  export LOG_FILE
fi

# ---------------------------------------------------------------------------
# Link map — repo-relative source | $HOME-relative destination
# (dest stored relative so the list stays readable and host-agnostic)
# ---------------------------------------------------------------------------
LINK_MAP=(
  "configs/zsh/.zshrc|.zshrc"
  "configs/zsh/.config/zshrc|.config/zshrc"
  "configs/nvim/.config/nvim|.config/nvim"
  "configs/tmux/.tmux.conf|.tmux.conf"
  "configs/tmux/.config/tmuxScript|.config/tmuxScript"
  "configs/ghostty/.config/ghostty|.config/ghostty"
)

LINKED=0
SKIPPED=0
BACKED_UP=0

# ---------------------------------------------------------------------------
# Path helpers (pure bash — realpath is not on older macOS)
# ---------------------------------------------------------------------------

# _phys_path <path> — physical (symlink-resolved) path of an existing file
# or directory. Used so links point at one canonical location.
# NOTE: `-d` (not `-d && ! -L`) on purpose — a repo reached through a
# symlinked root must resolve THROUGH the link via `cd && pwd -P`.
_phys_path() {
  local p="$1" dir
  if [[ -d "$p" ]]; then
    (cd "$p" && pwd -P)
    return 0
  fi
  dir="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s' "$dir" "$(basename "$p")"
}

# _link_points_into <symlink> <physical-root>
# Success when <symlink> exists and its ultimate destination lives under
# <physical-root>. Handles relative link targets and symlinked path
# components on either side (why both sides are canonicalized).
_link_points_into() {
  local link="$1" root="$2" dest dir
  [[ -L "$link" ]] || return 1

  dest="$(readlink "$link")"
  case "$dest" in
    /*) ;;
    *) dest="$(cd "$(dirname "$link")" 2>/dev/null && pwd -P)/$dest" || return 1 ;;
  esac

  if [[ -d "$dest" ]]; then
    dest="$(cd "$dest" 2>/dev/null && pwd -P)" || return 1
  else
    # dangling link, or link to a file: canonicalize the parent dir
    dir="$(cd "$(dirname "$dest")" 2>/dev/null && pwd -P)" || return 1
    dest="$dir/$(basename "$dest")"
  fi

  [[ "$dest" == "$root"/* ]]
}

# ---------------------------------------------------------------------------
# link_one <source> <absolute-dest>
# ---------------------------------------------------------------------------
link_one() {
  local src="$1" dest="$2"

  if _link_points_into "$dest" "$DOTFILES_PHYS"; then
    log_info "already linked: $dest"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    backup_path "$dest"
    BACKED_UP=$((BACKED_UP + 1))
  fi

  local src_phys
  src_phys="$(_phys_path "$src")" || die "cannot resolve source: $src"

  ensure_dir "$(dirname "$dest")"
  ln -s "$src_phys" "$dest" || die "failed to link: $dest -> $src_phys"

  log_success "linked: $dest -> $src_phys"
  LINKED=$((LINKED + 1))
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  if [[ -z "${HOME:-}" ]]; then
    die "HOME is not set"
  fi

  # Physical repo root: idempotency checks compare against this so a repo
  # reached via a symlinked path still counts as "already linked".
  DOTFILES_PHYS="$(_phys_path "$DOTFILES_ROOT")" ||
    die "cannot resolve DOTFILES_ROOT: $DOTFILES_ROOT"

  log_info "Linking configs from $DOTFILES_ROOT"

  # Phase 1: validate every source BEFORE modifying $HOME, so a partial
  # checkout can't leave the machine half-linked.
  local entry src_rel dest_rel src
  for entry in "${LINK_MAP[@]}"; do
    src_rel="${entry%%|*}"
    src="$DOTFILES_ROOT/$src_rel"
    if [[ ! -e "$src" ]]; then
      die "source missing — repo incomplete: $src"
    fi
  done

  # Phase 2: link
  for entry in "${LINK_MAP[@]}"; do
    src_rel="${entry%%|*}"
    dest_rel="${entry#*|}"
    link_one "$DOTFILES_ROOT/$src_rel" "$HOME/$dest_rel"
  done

  log_success "symlinks: $LINKED linked, $SKIPPED already linked, $BACKED_UP backed up"

  local session
  session="$(backup_session_dir)"
  if [[ -n "$session" ]]; then
    log_info "previous configs saved to: $session"
  fi
}

main "$@"
