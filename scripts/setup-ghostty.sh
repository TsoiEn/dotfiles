#!/usr/bin/env bash
#
# setup-ghostty.sh — verify Ghostty presence and config wiring.
#
# Never installs a GUI app: on macOS an absent Ghostty is reported with a
# pointer to the commented-out `cask:ghostty` line in
# install/packages/brew.txt; on Arch, ghostty is not in arch.txt at all,
# so only the config link is checked.
#
# Detection understands both forms of a macOS install:
#   - `ghostty` CLI on PATH (cask ships it inside the app bundle)
#   - /Applications/Ghostty.app (or ~/Applications) without a CLI
#
# Always non-fatal: bootstrap must complete regardless.

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

# ghostty_installed — success when either the CLI or the app bundle exists.
# GHOSTTY_APP_DIRS (colon-separated) overrides where bundles are looked up;
# defaults cover the standard macOS locations.
ghostty_installed() {
  if command_exists ghostty; then
    return 0
  fi
  local dirs="${GHOSTTY_APP_DIRS:-/Applications:$HOME/Applications}"
  local IFS=: d
  for d in $dirs; do
    if [[ -n "$d" && -d "$d/Ghostty.app" ]]; then
      return 0
    fi
  done
  return 1
}

# ghostty_where — printable location of the install (for logs).
ghostty_where() {
  if command_exists ghostty; then
    command -v ghostty
    return 0
  fi
  local dirs="${GHOSTTY_APP_DIRS:-/Applications:$HOME/Applications}"
  local IFS=: d
  for d in $dirs; do
    if [[ -n "$d" && -d "$d/Ghostty.app" ]]; then
      printf '%s' "$d/Ghostty.app"
      return 0
    fi
  done
  printf '%s' "unknown"
}

main() {
  if [[ -z "${HOME:-}" ]]; then
    die "HOME is not set"
  fi

  local os installed=false
  os="$(detect_os || true)"

  if [[ -z "$os" ]]; then
    log_warn "unsupported OS — checking ghostty config link only"
  elif [[ "$os" == "arch" ]]; then
    log_warn "Arch: ghostty is not in install/packages/arch.txt — config link only"
  fi

  # --- app presence ---------------------------------------------------------
  if ghostty_installed; then
    installed=true
    log_info "Ghostty found: $(ghostty_where)"
  elif [[ "$os" == "macos" ]]; then
    if command_exists brew; then
      log_info "Ghostty not installed — uncomment 'cask:ghostty' in install/packages/brew.txt and re-run bootstrap"
    else
      log_info "Ghostty not installed (Homebrew not found either — skipping install hint)"
    fi
  fi

  # --- config link ----------------------------------------------------------
  # setup-symlinks links the DIRECTORY ~/.config/ghostty, so -L must be
  # tested there — `.../ghostty/config` itself is a plain file behind it.
  local dir="$HOME/.config/ghostty"
  local cfg="$dir/config"
  if [[ -L "$dir" ]]; then
    if [[ -e "$cfg" ]]; then
      log_info "ghostty config linked: $dir -> $(readlink "$dir")"
    else
      log_warn "ghostty config symlink broken: $dir -> $(readlink "$dir") — run scripts/setup-symlinks.sh first"
    fi
  elif [[ -e "$cfg" ]]; then
    log_info "ghostty config present (not a symlink): $cfg"
  else
    log_warn "ghostty config missing at $cfg — run scripts/setup-symlinks.sh first"
  fi

  if [[ "$installed" == true ]]; then
    log_success "ghostty setup checks complete"
  else
    log_success "ghostty config checks complete (app not installed)"
  fi
}

main "$@"
