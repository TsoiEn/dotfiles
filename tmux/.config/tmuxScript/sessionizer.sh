#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG: choose one source of directories -------------------------------
# Option A: static roots to scan (fast + predictable)
# ROOTS=( "$HOME/Development/projects" "$HOME/Work" )

# Option B: use zoxide if present (comment A, uncomment B)
USE_ZOXIDE=1

# Option C: hardcode a few favorites (comment A/B, uncomment C)
# PICK_FROM=( "$HOME/dotfiles" "$HOME/Development/projects/Personal" )

# --- PICK A DIRECTORY -------------------------------------------------------
pick_dir() {
  if [[ -n "${USE_ZOXIDE-}" ]] && command -v zoxide >/dev/null 2>&1; then
    # Zoxide list → fzf
    zoxide query -l \
      | fzf --prompt="zoxide > " --height=40% --reverse --tac
    return
  fi

  if [[ "${#PICK_FROM[@]:-0}" -gt 0 ]]; then
    printf "%s\n" "${PICK_FROM[@]}" \
      | fzf --prompt="projects > " --height=40% --reverse
    return
  fi

  # Scan roots (fd preferred; fallback to find). One level of dirs is usually enough.
  if command -v fd >/dev/null 2>&1; then
    printf "%s\0" "${ROOTS[@]}" \
    | xargs -0 -I{} fd -t d -d 2 . "{}" \
    | fzf --prompt="projects > " --height=40% --reverse
  else
    # shellcheck disable=SC2046
    find "${ROOTS[@]}" -maxdepth 2 -type d 2>/dev/null \
      | fzf --prompt="projects > " --height=40% --reverse
  fi
}

DIR="$(pick_dir || true)"
[[ -z "${DIR:-}" ]] && exit 0

# --- MAKE A SAFE SESSION NAME ----------------------------------------------
# Use last directory name; strip non-alnum with dashes; lowercase.
base="$(basename "$DIR")"
name="$(printf "%s" "$base" \
  | sed -E 's/[^a-zA-Z0-9]+/-/g; s/^-+|-+$//g' \
  | sed 's/^\(.\)/\U\1/')"
[[ -z "$name" ]] && name="Proj"

# Avoid collisions by falling back to hashed suffix if needed
if tmux has-session -t "$name" 2>/dev/null; then
  existing=1
else
  existing=0
fi

# --- CREATE OR ATTACH -------------------------------------------------------
if [[ "$existing" -eq 0 ]]; then
  tmux new-session -ds "$name" -c "$DIR" -n "Main"
fi

if [[ -n "${TMUX-}" ]]; then
  tmux switch-client -t "$name"
else
  tmux attach -t "$name"
fi
