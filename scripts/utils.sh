#!/usr/bin/env bash

if [ -z "${DOTFILES_ROOT:-}" ]; then
  DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

LOG_DIR="${LOG_DIR:-$DOTFILES_ROOT/logs}"
BACKUP_DIR="${BACKUP_DIR:-$DOTFILES_ROOT/backups}"

_use_color=false
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  _use_color=true
fi

COLOR_RED=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_BLUE=""
COLOR_RESET=""
if [ "$_use_color" = true ]; then
  COLOR_RED="\033[0;31m"
  COLOR_GREEN="\033[0;32m"
  COLOR_YELLOW="\033[0;33m"
  COLOR_BLUE="\033[0;34m"
  COLOR_RESET="\033[0m"
fi

ts() {
  date "+%Y-%m-%d %H:%M:%S"
}

log_init() {
  mkdir -p "$LOG_DIR"
  if [ -z "${LOG_FILE:-}" ]; then
    LOG_FILE="$LOG_DIR/install-$(date "+%Y%m%d_%H%M%S").log"
  fi
  touch "$LOG_FILE"
}

_log_to_file() {
  if [ -n "${LOG_FILE:-}" ]; then
    printf "%s\n" "$1" >>"$LOG_FILE"
  fi
}

log_info() {
  local ts_str msg plain
  ts_str="$(ts)"
  msg="$*"
  plain="$ts_str [INFO] $msg"
  _log_to_file "$plain"
  if [ "$_use_color" = true ]; then
    printf "%s [%bINFO%b] %s\n" "$ts_str" "$COLOR_BLUE" "$COLOR_RESET" "$msg"
  else
    printf "%s\n" "$plain"
  fi
}

log_warn() {
  local ts_str msg plain
  ts_str="$(ts)"
  msg="$*"
  plain="$ts_str [WARN] $msg"
  _log_to_file "$plain"
  if [ "$_use_color" = true ]; then
    printf "%s [%bWARN%b] %s\n" "$ts_str" "$COLOR_YELLOW" "$COLOR_RESET" "$msg" >&2
  else
    printf "%s\n" "$plain" >&2
  fi
}

log_error() {
  local ts_str msg plain
  ts_str="$(ts)"
  msg="$*"
  plain="$ts_str [ERROR] $msg"
  _log_to_file "$plain"
  if [ "$_use_color" = true ]; then
    printf "%s [%bERROR%b] %s\n" "$ts_str" "$COLOR_RED" "$COLOR_RESET" "$msg" >&2
  else
    printf "%s\n" "$plain" >&2
  fi
}

log_success() {
  local ts_str msg plain
  ts_str="$(ts)"
  msg="$*"
  plain="$ts_str [OK] $msg"
  _log_to_file "$plain"
  if [ "$_use_color" = true ]; then
    printf "%s [%bOK%b] %s\n" "$ts_str" "$COLOR_GREEN" "$COLOR_RESET" "$msg"
  else
    printf "%s\n" "$plain"
  fi
}

die() {
  log_error "$*"
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  if ! command_exists "$1"; then
    die "Missing required command: $1"
  fi
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    require_command sudo
    sudo "$@"
  fi
}

ensure_dir() {
  local dir="$1"
  if [ -n "$dir" ]; then
    mkdir -p "$dir"
  fi
}

abs_path() {
  local path="$1"
  if [ -d "$path" ]; then
    (cd "$path" && pwd)
  else
    (cd "$(dirname "$path")" && printf "%s/%s" "$(pwd)" "$(basename "$path")")
  fi
}
