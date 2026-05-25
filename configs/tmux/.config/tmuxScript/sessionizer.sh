#!/usr/bin/env bash
set -euo pipefail

# ===================================================================
# CONFIG
# ===================================================================
DEV_ROOT="$HOME/Development"
USE_ZOXIDE=1
DEFAULT_WINDOW="Main"

# ===================================================================
# PICK DIRECTORY (UI → stderr, result → stdout)
# ===================================================================
pick_dev_dir_numbered() {
  local dirs=()
  local i=1

  while IFS= read -r -d '' d; do
    dirs+=("$d")
  done < <(
    find "$DEV_ROOT" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z
  )

  [[ "${#dirs[@]}" -eq 0 ]] && {
    echo "No directories found in $DEV_ROOT" >&2
    return 1
  }

  echo "Select a project:" >&2
  for d in "${dirs[@]}"; do
    echo "  $i) $(basename "$d")" >&2
    ((i++))
  done

  read -rp "Choose Directory: " choice >&2

  if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#dirs[@]} )); then
    echo "Invalid selection" >&2
    return 1
  fi

  printf "%s\n" "${dirs[choice-1]}"
}

# ===================================================================
# MAKE SAFE TMUX SESSION NAME
# ===================================================================
make_session_name() {
  local raw="$1"

  printf "%s" "$raw" \
    | sed -E 's/[^a-zA-Z0-9]+/-/g; s/^-+|-+$//g' \
    | sed 's/^\(.\)/\U\1/'
}

# ===================================================================
# MAIN
# ===================================================================
main() {
  local DIR=""
  local SESSION=""

  # ---------------------------------------------------------------
  # Resolve directory
  # ---------------------------------------------------------------
  if [[ $# -gt 0 ]]; then
    if [[ -d "$1" ]]; then
      DIR="$1"
    elif [[ "$USE_ZOXIDE" -eq 1 ]] && command -v zoxide >/dev/null 2>&1; then
      DIR="$(zoxide query "$1" 2>/dev/null || true)"
      [[ -z "$DIR" ]] && {
        echo "Error: zoxide could not resolve '$1'" >&2
        exit 1
      }
    else
      echo "Error: '$1' is not a valid directory" >&2
      exit 1
    fi
  else
    DIR="$(pick_dev_dir_numbered)" || exit 1
  fi

  echo "Selected directory: $DIR" >&2

  # ---------------------------------------------------------------
  # Session name
  # ---------------------------------------------------------------
  SESSION="$(make_session_name "$(basename "$DIR")")"
  [[ -z "$SESSION" ]] && SESSION="Proj"

  # ---------------------------------------------------------------
  # Create / attach tmux session
  # ---------------------------------------------------------------
  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux new-session -ds "$SESSION " -c "$DIR" -n "$DEFAULT_WINDOW" "$SHELL -i"
  fi

  if [[ -n "${TMUX-}" ]]; then
    tmux switch-client -t "$SESSION"
  else
    tmux attach -t "$SESSION"
  fi
}

main "$@"
