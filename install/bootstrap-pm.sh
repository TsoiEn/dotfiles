#!/usr/bin/env bash
#
# bootstrap-pm.sh — make the package manager exist before install/* uses it.
#
# This file is SOURCED by install/common.sh. Unlike scripts/setup-*.sh,
# failures here are FATAL: without a package manager the rest of the run
# has nothing to install from.
#
# Provides: ensure_brew, ensure_pacman_sync

# ensure_brew — install Homebrew when missing and put it on PATH.
#
# Needs the Xcode Command Line Tools, which Homebrew's own installer and
# `git clone` both depend on. `xcode-select --install` is an asynchronous
# GUI install, so we kick it off and stop rather than poll for it.
ensure_brew() {
  if command_exists brew; then
    log_info "Homebrew already installed: $(command -v brew)"
    return 0
  fi

  # A brew that is installed but not yet on PATH (first run in a fresh shell).
  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      eval "$("$candidate" shellenv)"
      log_info "Found Homebrew at $candidate"
      return 0
    fi
  done

  if ! xcode-select -p >/dev/null 2>&1; then
    log_warn "Xcode Command Line Tools missing — starting the installer"
    xcode-select --install >/dev/null 2>&1 || true
    die "Finish the Xcode Command Line Tools install, then re-run ./bootstrap.sh"
  fi

  log_info "Installing Homebrew"
  if ! NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    die "Homebrew install failed — see https://brew.sh"
  fi

  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then
      eval "$("$candidate" shellenv)"
      log_success "Homebrew installed: $candidate"
      return 0
    fi
  done

  die "Homebrew installed but brew was not found on PATH"
}

# ensure_pacman_sync — refresh the pacman database once per run, so
# `pacman -S` on a fresh machine can't fail with "target not found".
ensure_pacman_sync() {
  if [[ -n "${_DOTFILES_PACMAN_SYNCED:-}" ]]; then
    return 0
  fi
  _DOTFILES_PACMAN_SYNCED=1

  require_command pacman
  log_info "Refreshing pacman package database"
  run_as_root pacman -Sy --noconfirm || die "pacman -Sy failed"
}

# ensure_paru — build the AUR helper, only when DOTFILES_AUR=1.
#
# Opt-in because it compiles a package: too expensive to do on every run,
# and pacman alone covers everything in arch.txt except nvm. Unlike the
# two functions above a failure is NOT fatal — pacman still works, the
# AUR lines of the list just get logged as failures.
ensure_paru() {
  if [[ -z "${DOTFILES_AUR:-}" ]]; then
    return 0
  fi

  if command_exists paru; then
    log_info "paru already installed: $(command -v paru)"
    return 0
  fi

  # makepkg refuses to run as root, and there is no safe way around it.
  if [[ "$(id -u)" -eq 0 ]]; then
    log_warn "DOTFILES_AUR=1 but running as root — install paru as your user"
    return 0
  fi

  log_info "Installing paru from the AUR (needs base-devel, compiles)"
  if ! run_as_root pacman -S --needed --noconfirm base-devel git; then
    log_warn "Could not install base-devel/git — skipping paru"
    return 0
  fi

  local build
  build="$(mktemp -d)" || return 0

  if GIT_TERMINAL_PROMPT=0 git clone --depth 1 \
    https://aur.archlinux.org/paru-bin.git "$build/paru-bin" &&
    (cd "$build/paru-bin" && makepkg -si --noconfirm); then
    log_success "paru installed: $(command -v paru)"
  else
    log_warn "paru build failed — AUR packages will be skipped"
  fi

  rm -rf "$build"
}
