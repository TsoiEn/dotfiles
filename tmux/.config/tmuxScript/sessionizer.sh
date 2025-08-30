#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG: choose one source of directories -------------------------------
# Option A: static roots to scan (fast + predictable)
# ROOTS=( "$HOME/Development/projects" "$HOME/Work" )

# Option B: use zoxide if present (comment A, uncomment B)
USE_ZOXIDE=1

# Option C: hardcode a few favorites (comment A/B, uncomment C)
# PICK_FROM=( "$HOME/dotfiles" "$HOME/Development/projects/Personal" )

# --- PICK A DIRECTORY (fzf/zoxide/fd/find) ----------------------------------
pick_dir() {
  if [[ -n "${USE_ZOXIDE-}" ]] && command -v zoxide >/dev/null 2>&1; then
    zoxide query -l \
      | fzf --prompt="zoxide > " --height=40% --reverse --tac
    return
  fi

  if [[ "${#PICK_FROM[@]:-0}" -gt 0 ]]; then
    printf "%s\n" "${PICK_FROM[@]}" \
      | fzf --prompt="projects > " --height=40% --reverse
    return
  fi

  if command -v fd >/dev/null 2>&1; then
    printf "%s\0" "${ROOTS[@]}" \
    | xargs -0 -I{} fd -t d -d 2 . "{}" \
    | fzf --prompt="projects > " --height=40% --reverse
  else
    find "${ROOTS[@]}" -maxdepth 2 -type d 2>/dev/null \
      | fzf --prompt="projects > " --height=40% --reverse
  fi
}

# --- ARGUMENT HANDLING ------------------------------------------------------
if [[ $# -gt 0 ]]; then
  if [[ -d "$1" ]]; then
    DIR="$1"
  elif command -v zoxide >/dev/null 2>&1; then
    DIR="$(zoxide query "$1" 2>/dev/null || true)"
  else
    echo "Error: '$1' is not a valid directory and zoxide not available" >&2
    exit 1
  fi
else
  DIR="$(pick_dir || true)"
fi

[[ -z "${DIR:-}" ]] && exit 0

# --- MAKE A SAFE SESSION NAME ----------------------------------------------
# If user gave arg → prefer that as session name, otherwise use basename of dir
if [[ $# -gt 0 ]]; then
  raw_name="$1"
else
  raw_name="$(basename "$DIR")"
fi

# Strip non-alnum, dash-separate, uppercase first letter
name="$(printf "%s" "$raw_name" \
  | sed -E 's/[^a-zA-Z0-9]+/-/g; s/^-+|-+$//g' \
  | sed 's/^\(.\)/\U\1/')"
[[ -z "$name" ]] && name="Proj"

# Check if session exists
if tmux has-session -t "$name" 2>/dev/null; then
  existing=1
else
  existing=0
fi

# --- CREATE OR ATTACH -------------------------------------------------------
if [[ "$existing" -eq 0 ]]; then
  tmux new-session -ds "$name" -c "$DIR" -n "Main" "$SHELL -i"
fi

if [[ -n "${TMUX-}" ]]; then
  tmux switch-client -t "$name"
else
  tmux attach -t "$name"
fi
