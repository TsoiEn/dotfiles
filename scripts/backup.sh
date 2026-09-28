#!/usr/bin/env bash
#
# backup.sh — relocates existing dotfiles before symlinking.
#
# Sourced by scripts/setup-symlinks.sh (and safe to source standalone:
# pulls in scripts/utils.sh itself if the caller hasn't).
#
# API:
#   backup_session_dir   -> prints the session dir (creating it), or nothing
#                           if no backup has happened yet
#   backup_path <path>   -> moves an existing path into the session dir,
#                           mirroring its path relative to $HOME:
#                             ~/.zshrc -> backups/<ts>/.zshrc
#                           No-op when the path doesn't exist.
#
# Safety rails (both `die`):
#   - refuses to move anything not under $HOME
#   - refuses to move anything inside $DOTFILES_ROOT (would shuffle the
#     repo into its own backups/ directory)

# ---------------------------------------------------------------------------
# Re-source guard (same `if`/`return` pattern as utils.sh — never `&&`).
# ---------------------------------------------------------------------------
if [[ -n "${_DOTFILES_BACKUP_SOURCED:-}" ]]; then
  return 0 2>/dev/null || unset _DOTFILES_BACKUP_SOURCED
fi
_DOTFILES_BACKUP_SOURCED=1

# Pull in log_info/die/ensure_dir when used outside the bootstrap flow.
if [[ -z "${_DOTFILES_UTILS_SOURCED:-}" ]]; then
  # shellcheck source=scripts/utils.sh
  source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
fi

# ---------------------------------------------------------------------------
# backup_init — resolve (and create) this run's session directory.
#
# Called lazily by backup_path, never from bootstrap at startup: a clean
# re-run that backs nothing up must not litter backups/<timestamp>/ dirs.
# ---------------------------------------------------------------------------
backup_init() {
  if [[ -n "${BACKUP_SESSION:-}" ]]; then
    return 0
  fi

  if [[ -z "${BACKUP_DIR:-}" ]]; then
    die "backup_init: BACKUP_DIR is not set (bootstrap exports it)"
  fi

  BACKUP_SESSION="$BACKUP_DIR/$(date +%Y%m%d-%H%M%S)"
  ensure_dir "$BACKUP_SESSION"
  export BACKUP_SESSION
}

# backup_session_dir — print the session dir, or nothing if unused yet.
backup_session_dir() {
  if [[ -n "${BACKUP_SESSION:-}" ]]; then
    printf '%s\n' "$BACKUP_SESSION"
  fi
}

# ---------------------------------------------------------------------------
# backup_path <path>
# ---------------------------------------------------------------------------
backup_path() {
  if [[ $# -ne 1 ]]; then
    die "backup_path: expected exactly 1 argument, got $#"
  fi

  local target="$1"

  if [[ -z "${HOME:-}" ]]; then
    die "backup_path: HOME is not set"
  fi
  if [[ -z "${DOTFILES_ROOT:-}" ]]; then
    die "backup_path: DOTFILES_ROOT is not set"
  fi

  # Nothing to do — but -L is essential: a DANGLING symlink fails -e, and
  # skipping it would make the later `ln -s` fail with "File exists".
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    return 0
  fi

  # Make absolute and normalize without realpath (not on older macOS):
  # resolve the parent directory, keep the basename.
  local abs parent
  case "$target" in
    /*) abs="$target" ;;
    *) abs="$PWD/$target" ;;
  esac
  parent="$(cd "$(dirname "$abs")" 2>/dev/null && pwd)" ||
    die "backup_path: cannot resolve directory of: $abs"
  abs="$parent/$(basename "$abs")"

  # --- safety rails ---
  if [[ "$abs" != "$HOME"/* ]]; then
    die "backup_path: refusing to move a path outside \$HOME: $abs"
  fi
  if [[ "$abs" == "$DOTFILES_ROOT"/* ]]; then
    die "backup_path: refusing to move a path inside the repo: $abs"
  fi

  backup_init

  # Mirror the path relative to $HOME inside this run's session dir.
  local rel dest n=0
  rel="${abs#"$HOME"/}"
  dest="$BACKUP_SESSION/$rel"

  # Each target is backed up at most once per run, so this only matters if
  # the same second-resolution session dir is somehow reused.
  while [[ -e "$dest" || -L "$dest" ]]; do
    n=$((n + 1))
    dest="$BACKUP_SESSION/$rel.$n"
  done

  ensure_dir "$(dirname "$dest")"
  mv "$abs" "$dest" || die "backup_path: failed to move $abs -> $dest"

  log_info "backed up: $abs -> $dest"
  return 0
}
