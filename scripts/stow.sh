#!/usr/bin/env bash
#
# stow.sh — link configs/ into $HOME with GNU Stow.
#
# Every directory under configs/ is a Stow package whose layout mirrors
# $HOME (configs/zsh/.zshrc -> ~/.zshrc), so Stow can link it as-is.
# This is an alternative to setup-symlinks.sh + setup-claude.sh, not a
# replacement: bootstrap.sh still uses those.
#
# Usage:  bash scripts/stow.sh [options] [package...]
#   (no packages)  every package in configs/ that fits this OS
#   -n             dry run — show what Stow would do, change nothing
#   -D             unstow (remove the links)
#   -R             restow (unstow then stow; prunes stale links)
#   -l             list packages and exit
#   -h             help
#
# Safety:
#   - Stow never overwrites a real file: a conflict aborts that package
#     with nothing changed. Move the file aside (or into the repo) and
#     re-run. --adopt is deliberately not exposed.
#   - KEEP_REAL dirs are created as real directories first, so Stow can't
#     "fold" them into one symlink — otherwise ~/.claude or ~/.config would
#     become a link into this repo and runtime state would land here.
#   - Absolute links made earlier by setup-symlinks.sh / setup-claude.sh
#     point into this repo but Stow doesn't recognise them as its own, so
#     they are swapped for Stow's relative links (they never held data).
#
# Env overrides:  DOTFILES_ROOT, LOG_DIR, LOG_FILE, HOME

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${DOTFILES_ROOT:-}" ]]; then
  DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  export DOTFILES_ROOT
fi

# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR/utils.sh"
# shellcheck source=scripts/detect-os.sh
source "$SCRIPT_DIR/detect-os.sh"

if [[ -z "${LOG_FILE:-}" ]]; then
  log_init
  export LOG_FILE
fi

STOW_DIR="$DOTFILES_ROOT/configs"

# $HOME-relative dirs that must stay real directories (see header).
KEEP_REAL=(
  .config
  .config/git
  .claude
  .claude/skills
)

# Basename regexes Stow must not link (Stow's own defaults still apply).
IGNORE=(
  '\.gitkeep'
  'plan\.md' # configs/myscripts/plan.md is notes, not a dotfile
)

# package|os — packages that only make sense on one OS.
OS_ONLY=(
  "aerospace|macos"
)

usage() {
  sed -n '/^# Usage:/,/^# *-h/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

all_packages() {
  local d
  for d in "$STOW_DIR"/*/; do
    basename "$d"
  done
}

# fits_os <package> — false when OS_ONLY pins it to another OS.
fits_os() {
  local pkg="$1" entry
  for entry in "${OS_ONLY[@]}"; do
    if [[ "${entry%%|*}" == "$pkg" && "${entry#*|}" != "$OS" ]]; then
      return 1
    fi
  done
}

# _clear_legacy_links <package> — remove absolute symlinks in $HOME that
# point into this repo for paths the package provides. Each removal is
# recorded in REMOVED ("dest|target") so a failed stow can put it back.
_clear_legacy_links() {
  local pkg="$1" rel dest target
  while IFS= read -r rel; do
    dest="$HOME/$rel"
    [[ -L "$dest" ]] || continue
    target="$(readlink "$dest")"
    if [[ "$target" == "$DOTFILES_PHYS"/* || "$target" == "$DOTFILES_ROOT"/* ]]; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "would replace legacy link: $dest"
      else
        rm "$dest"
        REMOVED+=("$dest|$target")
        log_info "replaced legacy link: $dest"
      fi
    fi
  done < <(cd "$STOW_DIR/$pkg" && find . -mindepth 1 | sed 's|^\./||')
}

main() {
  local action="-S" opt
  DRY_RUN=0

  while getopts ":nDRlh" opt; do
    case "$opt" in
      n) DRY_RUN=1 ;;
      D) action="-D" ;;
      R) action="-R" ;;
      l) all_packages; exit 0 ;;
      h) usage; exit 0 ;;
      *) usage >&2; exit 2 ;;
    esac
  done
  shift $((OPTIND - 1))

  [[ -n "${HOME:-}" ]] || die "HOME is not set"
  command_exists stow ||
    die "GNU Stow not found — install it (pacman -S stow / brew install stow)"

  OS="$(detect_os)"
  DOTFILES_PHYS="$(cd "$DOTFILES_ROOT" && pwd -P)"

  local packages=() pkg
  if [[ $# -gt 0 ]]; then
    for pkg in "$@"; do
      [[ -d "$STOW_DIR/$pkg" ]] || die "no such package: $pkg (try -l)"
      packages+=("$pkg")
    done
  else
    while IFS= read -r pkg; do
      if fits_os "$pkg"; then
        packages+=("$pkg")
      else
        log_info "skipping $pkg (not for $OS)"
      fi
    done < <(all_packages)
  fi

  local stow_args=(--dir="$STOW_DIR" --target="$HOME" "$action")
  if [[ "$DRY_RUN" -eq 1 ]]; then
    stow_args+=(--no --verbose=1)
  fi
  local re
  for re in "${IGNORE[@]}"; do
    stow_args+=(--ignore="$re")
  done

  if [[ "$action" != "-D" ]]; then
    local d
    for d in "${KEEP_REAL[@]}"; do
      if [[ "$DRY_RUN" -eq 0 && ! -L "$HOME/$d" ]]; then
        ensure_dir "$HOME/$d"
      fi
    done
  fi

  local failed=() entry
  for pkg in "${packages[@]}"; do
    REMOVED=()
    if [[ "$action" != "-D" ]]; then
      _clear_legacy_links "$pkg"
    fi
    if stow "${stow_args[@]}" "$pkg" 2>&1 | tee -a "$LOG_FILE"; then
      log_success "$pkg"
    else
      # Stow changes nothing on conflict, so restoring the old links
      # leaves this package exactly as it was.
      for entry in ${REMOVED[@]+"${REMOVED[@]}"}; do # bash 3.2-safe
        ln -s "${entry#*|}" "${entry%%|*}"
      done
      log_error "$pkg — see conflicts above"
      failed+=("$pkg")
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    die "failed: ${failed[*]}"
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_info "dry run — nothing changed"
  fi
  log_success "stow: ${#packages[@]} package(s) done"
}

main "$@"
