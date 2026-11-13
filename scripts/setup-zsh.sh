#!/usr/bin/env bash
#
# setup-zsh.sh — ensure oh-my-zsh and its external plugins exist.
#
# configs/zsh/.config/zshrc/20-customization.zsh sources
# "$ZSH/oh-my-zsh.sh" and lists three plugins that are NOT bundled with
# omz, so without this script every new shell errors on arrival.
#
# oh-my-zsh is CLONED, never installed with the curl|sh installer: that
# installer rewrites ~/.zshrc, which is this repo's symlink.
#
# Everything here is BEST EFFORT: failures degrade to a warning plus the
# by-hand command, never a failed bootstrap.
#
# Env: ZSH / ZSH_CUSTOM to override locations; DOTFILES_ROOT/LOG_* as usual.

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

ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
OMZ_URL="https://github.com/ohmyzsh/ohmyzsh"

# Plugin name -> clone URL. Each is listed in 20-customization.zsh but is
# not part of oh-my-zsh itself.
PLUGIN_NAMES=(
  zsh-autosuggestions
  zsh-syntax-highlighting
  fast-syntax-highlighting
)
PLUGIN_URLS=(
  https://github.com/zsh-users/zsh-autosuggestions
  https://github.com/zsh-users/zsh-syntax-highlighting
  https://github.com/zdharma-continuum/fast-syntax-highlighting
)

# clone_if_absent <url> <dest> <label> — skip-if-present git clone that
# warns instead of failing. Returns non-zero only when the clone failed.
clone_if_absent() {
  local url="$1" dest="$2" label="$3"

  if [[ -d "$dest/.git" ]]; then
    log_info "$label already installed: $dest"
    return 0
  fi

  if [[ -e "$dest" ]]; then
    log_warn "$label path exists but is not a git repo — leaving it untouched: $dest"
    return 0
  fi

  ensure_dir "$(dirname "$dest")"
  log_info "Installing $label from $url"
  if GIT_TERMINAL_PROMPT=0 git clone --depth 1 "$url" "$dest"; then
    log_success "$label installed: $dest"
  else
    log_warn "$label clone failed (offline?) — re-run bootstrap when online"
    return 1
  fi
}

# set_login_shell — chsh to zsh when it isn't the login shell already.
# chsh prompts for a password, so a failure is only ever a warning.
set_login_shell() {
  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    log_info "Login shell is already zsh"
    return 0
  fi

  # chsh refuses any shell missing from /etc/shells.
  if ! grep -Fxq "$zsh_path" /etc/shells 2>/dev/null; then
    log_warn "zsh is not in /etc/shells — add it, then run: chsh -s $zsh_path"
    return 0
  fi

  log_info "Changing login shell to $zsh_path (may ask for your password)"
  if chsh -s "$zsh_path"; then
    log_success "Login shell set to zsh — open a new terminal to use it"
  else
    log_warn "chsh failed — run it by hand: chsh -s $zsh_path"
  fi
}

main() {
  if [[ -z "${HOME:-}" ]]; then
    die "HOME is not set"
  fi

  if ! command_exists zsh; then
    log_warn "zsh not installed — skipping oh-my-zsh setup"
    return 0
  fi

  if ! command_exists git; then
    log_warn "git not installed — cannot install oh-my-zsh"
    return 0
  fi

  # No omz means no $ZSH/custom to clone plugins into, so stop there.
  if ! clone_if_absent "$OMZ_URL" "$ZSH" "oh-my-zsh"; then
    return 0
  fi

  local i
  for i in "${!PLUGIN_NAMES[@]}"; do
    clone_if_absent "${PLUGIN_URLS[$i]}" \
      "$ZSH_CUSTOM/plugins/${PLUGIN_NAMES[$i]}" \
      "plugin ${PLUGIN_NAMES[$i]}" || true
  done

  set_login_shell
}

main "$@"
