#!/usr/bin/env bash
#
# utils.sh — shared helpers for the dotfiles bootstrap.
#
# This file is SOURCED, never executed. It is pulled in by:
#   - bootstrap.sh          (sets DOTFILES_ROOT, LOG_DIR, BACKUP_DIR first)
#   - install/common.sh     (may set DOTFILES_ROOT itself)
# and can therefore be sourced twice in a single run.
#
# Contract (must exist before install/* or bootstrap.sh run):
#   log_init, log_info, log_success, log_warn, log_error,
#   die, ensure_dir, command_exists, require_command, run_as_root
#
# Top level of this file contains ONLY variable defaults and function
# definitions — callers run under `set -euo pipefail`, so no top-level
# command is allowed to fail.

# ---------------------------------------------------------------------------
# Re-source guard
# Uses `if` (not `&&`) so a failed condition can never trip `set -e`.
# ---------------------------------------------------------------------------
if [[ -n "${_DOTFILES_UTILS_SOURCED:-}" ]]; then
  return 0 2>/dev/null || unset _DOTFILES_UTILS_SOURCED
fi
_DOTFILES_UTILS_SOURCED=1

# ---------------------------------------------------------------------------
# DOTFILES_ROOT — the caller normally exports this. If not (e.g. someone
# sources install/common.sh directly), resolve it from this file's location:
# scripts/utils.sh -> repo root.
# ---------------------------------------------------------------------------
if [[ -z "${DOTFILES_ROOT:-}" ]]; then
  DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || DOTFILES_ROOT=""
fi
export DOTFILES_ROOT

# Colors (applied only when stdout is a terminal).
_DOTFILES_C_RESET=$'\033[0m'
_DOTFILES_C_INFO=$'\033[1;34m'
_DOTFILES_C_SUCCESS=$'\033[1;32m'
_DOTFILES_C_WARN=$'\033[1;33m'
_DOTFILES_C_ERROR=$'\033[1;31m'

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

# log_init — create the log directory and resolve LOG_FILE.
#
# LOG_FILE is intentionally left untouched when already set: bootstrap.sh
# exports it so install/arch.sh and install/macos.sh append to the SAME
# file (both check `if [ -z "${LOG_FILE:-}" ]` before calling this).
log_init() {
  LOG_DIR="${LOG_DIR:-${DOTFILES_ROOT:-$HOME/.dotfiles}/logs}"

  if [[ -z "${LOG_FILE:-}" ]]; then
    LOG_FILE="$LOG_DIR/bootstrap-$(date +%Y%m%d-%H%M%S).log"
  fi

  ensure_dir "$LOG_DIR"
  if ! touch "$LOG_FILE" 2>/dev/null; then
    printf 'log_error: cannot write to log file: %s\n' "$LOG_FILE" >&2
    return 1
  fi

  export LOG_DIR LOG_FILE
}

# _log <level> <color> <message...>
# Prints a colored line to stdout and a plain, timestamped line to LOG_FILE.
_log() {
  local level="$1" color="$2"
  shift 2

  local ts plain
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  plain="[$ts] [$level] $*"

  if [[ -t 1 ]]; then
    printf '%b%s%b\n' "$color" "$plain" "$_DOTFILES_C_RESET"
  else
    printf '%s\n' "$plain"
  fi

  # Appending to the log must never abort the caller under `set -e`.
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '%s\n' "$plain" >> "$LOG_FILE" 2>/dev/null || true
  fi
}

log_info() { _log "INFO" "$_DOTFILES_C_INFO" "$@"; }
log_success() { _log "OK" "$_DOTFILES_C_SUCCESS" "$@"; }
log_warn() { _log "WARN" "$_DOTFILES_C_WARN" "$@"; }
log_error() { _log "ERROR" "$_DOTFILES_C_ERROR" "$@"; }

# die <message...> — log at ERROR level and terminate the calling script.
die() {
  log_error "$@"
  exit 1
}

# ---------------------------------------------------------------------------
# Filesystem
# ---------------------------------------------------------------------------

# ensure_dir <path> — mkdir -p, aborting if it can't be created.
ensure_dir() {
  local dir="$1"

  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir" || die "Unable to create directory: $dir"
  fi
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

# command_exists <name> — success if the command is on PATH.
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# require_command <name> — die with a clear message if it's missing.
require_command() {
  local cmd="$1"
  command_exists "$cmd" || die "Required command not found: $cmd"
}

# run_as_root <cmd> [args...] — run directly when already root, else via sudo.
# Used by install/common.sh for `pacman -S`.
run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command_exists sudo; then
    sudo "$@"
  else
    die "Cannot elevate privileges: sudo not available (needed for: $*)"
  fi
}
