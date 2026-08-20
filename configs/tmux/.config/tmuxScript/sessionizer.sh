#!/usr/bin/env bash
#
# sessionizer.sh — a telescope/lazygit-style tmux session picker
#
# Written to run on bash 3.2 (macOS's stock /bin/bash) as well as modern
# bash — no associative arrays, no bash-4+-only builtins.
#
# Backed by fzf + zoxide. Typing always filters the list (no modes).
#
# Two views:
#   SESSIONS view (default, shown when any tmux session already exists) —
#     lists only live sessions.
#       enter    switch/attach to the highlighted session
#       ctrl-e   kill the session under the cursor
#       ctrl-n   with something typed: create a session with that name
#                with nothing typed: drop into the full directory browser
#       esc      quit
#   FULL view (shown when there are no sessions yet, or via ctrl-n above) —
#     lists live sessions + zoxide directories.
#       enter    open the highlighted session, or create+open one from the
#                highlighted directory
#       ctrl-e   kill the session under the cursor
#       ctrl-n   with something typed: create a session with that name
#                with nothing typed: just re-show this view
#       esc      quit
#
# Requires: tmux, fzf, zoxide
#
# Install:
#   cp sessionizer.sh ~/.local/bin/ts && chmod +x ~/.local/bin/ts
#   (make sure ~/.local/bin is on your PATH)
#
# Optional tmux.conf binding (e.g. prefix + f):
#   bind-key f run-shell "~/.local/bin/ts"
#
set -euo pipefail

POPUP_W="85%"
POPUP_H="80%"
POPUP_FLAG="TS_IN_POPUP"

SESSIONS_HEADER="  enter switch · ctrl-n new (type a name, or empty to browse) · ctrl-e kill · esc quit"
FULL_HEADER="  enter open/create · ctrl-n new session by name · ctrl-e kill · esc quit"

# ---------------------------------------------------------------------------
# Entry point / dispatch
# ---------------------------------------------------------------------------
main() {
  # --kill / --list / --list-sessions are on the hot path (fired on every
  # ctrl-e via execute-silent+reload), so skip the realpath resolve there —
  # it's only needed to build the self-referencing fzf binds.
  case "${1:-}" in
    --kill)          kill_session "$2"; return ;;
    --list)          build_full_candidates; return ;;
    --list-sessions)  build_sessions_candidates; return ;;
  esac

  self="$(realpath "${BASH_SOURCE[0]}")"

  case "${1:-}" in
    --picker) run_picker ;;
    *)        launch ;;
  esac
}

# If we're inside tmux but not already inside our own popup, re-launch
# ourselves inside a `tmux display-popup`. That popup *is* the modal.
# If we're outside tmux entirely, just run the picker right here.
launch() {
  if [[ -n "${TMUX:-}" && -z "${!POPUP_FLAG:-}" ]]; then
    tmux display-popup -E -w "$POPUP_W" -h "$POPUP_H" -T " ts " \
      env "${POPUP_FLAG}=1" "$self" --picker
  else
    run_picker
  fi
}

# ---------------------------------------------------------------------------
# View dispatch: sessions-only landing screen if any session already exists,
# otherwise the full directory browser.
# ---------------------------------------------------------------------------
run_picker() {
  local sessions
  sessions="$(list_live_sessions)"
  if [[ -n "$sessions" ]]; then
    run_sessions_view
  else
    run_full_view
  fi
}

# ---------------------------------------------------------------------------
# SESSIONS view
# ---------------------------------------------------------------------------
run_sessions_view() {
  local candidates
  candidates="$(build_sessions_candidates)"

  # Sessions may have disappeared between the check in run_picker and here
  # (e.g. raced by another client) — fall back gracefully.
  if [[ -z "$candidates" ]]; then
    run_full_view
    return
  fi

  local out status query second

  set +e
  out="$(printf '%s\n' "$candidates" | fzf \
    --ansi --delimiter '\t' --with-nth=1 \
    --prompt "  ts  " \
    --header "$SESSIONS_HEADER" --header-first --layout=reverse --border=rounded \
    --print-query \
    --bind "ctrl-e:execute-silent(\"$self\" --kill {3})+reload(\"$self\" --list-sessions)" \
    --bind 'ctrl-n:print(__CTRLN__)+accept')"
  status=$?
  set -e

  [[ $status -ne 0 || -z "$out" ]] && return 0

  query="$(sed -n '1p' <<< "$out")"
  second="$(sed -n '2p' <<< "$out")"

  if [[ "$second" == "__CTRLN__" ]]; then
    if [[ -n "$query" ]]; then
      create_named_session "$query"
    else
      run_full_view
    fi
  else
    [[ -n "$second" ]] && open_line "$second"
  fi
}

# ---------------------------------------------------------------------------
# FULL view (sessions + zoxide directories)
# ---------------------------------------------------------------------------
run_full_view() {
  local candidates
  candidates="$(build_full_candidates)"

  if [[ -z "$candidates" ]]; then
    echo "No zoxide entries yet. Run 'zoxide add <path>' or 'cd' around a bit first."
    read -n 1 -s -r -p "press any key to close"
    return
  fi

  local out status query second

  set +e
  out="$(printf '%s\n' "$candidates" | fzf \
    --ansi --delimiter '\t' --with-nth=1 \
    --prompt "  ts  " \
    --header "$FULL_HEADER" --header-first --layout=reverse --border=rounded \
    --print-query \
    --bind "ctrl-e:execute-silent(\"$self\" --kill {3})+reload(\"$self\" --list)" \
    --bind 'ctrl-n:print(__CTRLN__)+accept')"
  status=$?
  set -e

  [[ $status -ne 0 || -z "$out" ]] && return 0

  query="$(sed -n '1p' <<< "$out")"
  second="$(sed -n '2p' <<< "$out")"

  if [[ "$second" == "__CTRLN__" ]]; then
    if [[ -n "$query" ]]; then
      create_named_session "$query"
    else
      run_full_view
    fi
  else
    [[ -n "$second" ]] && open_line "$second"
  fi
}

# ---------------------------------------------------------------------------
# Candidate lists
# ---------------------------------------------------------------------------

list_live_sessions() {
  tmux list-sessions -F '#{session_name}' 2>/dev/null || true
}

emit_session_lines() {
  local sessions="$1" s
  [[ -z "$sessions" ]] && return 0
  while IFS= read -r s; do
    [[ -z "$s" ]] && continue
    printf ' ● %s (session)\tsession\t%s\n' "$s" "$s"
  done <<< "$sessions"
}

# Pure-bash basename/tr equivalents below (no subprocess per line) — with a
# large zoxide history, forking basename/tr/grep for every entry was the
# main source of slowness on every kill/reload. sessions_nl is newline-
# padded so a plain glob-pattern containment check can do an exact per-line
# match without associative arrays (bash 3.2, macOS's stock /bin/bash,
# doesn't support declare -A).
emit_dir_lines() {
  local sessions_nl="$1" dirs d name
  dirs="$(zoxide query -l 2>/dev/null || true)"
  [[ -z "$dirs" ]] && return 0
  while IFS= read -r d; do
    [[ -z "$d" || ! -d "$d" ]] && continue
    name="${d##*/}"
    name="${name//./_}"
    [[ "$sessions_nl" == *$'\n'"$name"$'\n'* ]] && continue
    printf '   %s\tdir\t%s\n' "$d" "$d"
  done <<< "$dirs"
}

build_sessions_candidates() {
  local sessions
  sessions="$(list_live_sessions)"
  emit_session_lines "$sessions"
}

build_full_candidates() {
  local sessions sessions_nl
  sessions="$(list_live_sessions)"
  sessions_nl=$'\n'"$sessions"$'\n'
  emit_session_lines "$sessions"
  emit_dir_lines "$sessions_nl"
}

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

open_line() {
  local line="$1" type value path session_name
  type="$(cut -f2 <<< "$line")"
  value="$(cut -f3 <<< "$line")"

  if [[ "$type" == "session" ]]; then
    session_name="$value"
  else
    path="$value"
    session_name="$(basename "$path" | tr . _)"
    if ! tmux has-session -t "=$session_name" 2>/dev/null; then
      tmux new-session -d -s "$session_name" -c "$path"
    fi
  fi

  attach_or_switch "$session_name"
}

# The directory the popup/picker was launched from — used as the starting
# directory for a brand-new, name-only session (no path involved).
start_dir() {
  if [[ -n "${TMUX:-}" ]]; then
    tmux display-message -p '#{pane_current_path}' 2>/dev/null || echo "$PWD"
  else
    echo "$PWD"
  fi
}

# Create (if needed) and attach to a session named after whatever the user
# typed — this is the ctrl-n "custom name" path. tmux session names can't
# contain dots, so those get folded the same way directory-derived names are.
create_named_session() {
  local raw_name="$1" name dir
  name="${raw_name//./_}"
  dir="$(start_dir)"
  if ! tmux has-session -t "=$name" 2>/dev/null; then
    tmux new-session -d -s "$name" -c "$dir"
  fi
  attach_or_switch "$name"
}

# Called only after fzf has fully exited, so tmux always has a real
# controlling terminal to work with here.
attach_or_switch() {
  local session_name="$1"
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "=$session_name"
  else
    tmux attach -t "=$session_name"
  fi
}

kill_session() {
  local name="$1"
  [[ -z "$name" ]] && return 0
  tmux kill-session -t "=$name" 2>/dev/null || true
}

main "$@"
