#!/usr/bin/env bash
#
# pkg.sh — which package manager installed this, and which one can.
#
# The problem it solves: a tool gets installed once, on whichever machine
# and with whichever manager was closest to hand — pacman here, an AUR
# helper there, brew on the Mac, `go install` or `cargo install` or a global
# pnpm for the rest. Six months later `fzf` is on PATH and nothing says how
# it got there, so upgrading or removing it means guessing. Installing has
# the same problem from the other end: the name is known, the manager that
# carries it is not.
#
# pkg asks every manager that exists on this machine. No database of its
# own is kept: the managers already are the log, and querying them cannot
# go stale. `pkg -l > packages.txt` is the snapshot if you want a file.
#
#   $ pkg fzf
#   MANAGER    PACKAGE                      VERSION
#   brew       fzf                          0.56.3
#
#   binary     /opt/homebrew/bin/fzf -> /opt/homebrew/Cellar/fzf/0.56.3/bin/fzf
#              brew formula: fzf
#
# Usage:
#   pkg                    # the popup: type, search every manager, install
#                          #   (tmux: prefix+p)
#   pkg <name>             # who has this package / owns this binary — and
#                          #   when nothing here has it, the -i search
#   pkg -i <name>          # ask every manager, pick in a popup, install
#                          #   (ctrl-a ticks a row, alt-enter installs the lot)
#   pkg -i cask:ghostty    # skip the search, use this manager
#   pkg -l                 # everything, grouped by manager (the snapshot)
#   pkg -l brew pip        # only these managers
#   pkg -m                 # which managers exist on this machine
#
# Matching is exact first; with no exact hit, substrings are shown instead.
#
# -i asks every manager on this machine at once — in parallel, so the
# slowest registry sets the wait — and shows everything they found in an
# fzf picker. Inside tmux that picker is a display-popup, the same modal
# sessionizer.sh uses: j/k moves, enter installs the highlighted row, esc
# cancels, and the preview is the exact command enter will run. Exact name
# matches come first, then the system managers, then the language ones.
#
# Every row carries a box. ctrl-a ticks the one under the cursor, which
# moves it to the bottom of the list — so the ticked rows are a list of
# their own, under the candidates, and ctrl-a on a ticked row unticks it.
# With anything ticked, enter does nothing and alt-enter is what installs:
# all the ticked rows, in the order they are listed, each with its own
# manager — a pacman row and a cargo row in one go. (Not ctrl-enter: a
# terminal sends the same byte for that as for enter.)
#
# The install runs in the popup, under the row that started it, so the log
# (and a sudo prompt) is there to watch, and enter closes it when it is
# done. Nothing is printed outside the popup: with no terminal of its own —
# a tmux key binding — stray output becomes a view window over the session.
#
# `pkg` with no name at all opens the same popup empty and searches as you
# type (every letter after the second, debounced), which is what tmux's
# prefix+p is bound to. Typing is the search there, so j and k have to stay
# letters: movement is ctrl-j/ctrl-k. In the `pkg <name>` popup, where the
# term is already given, j/k move. A ticked row stays in the list as the
# query changes, so a second package can be searched for and ticked before
# alt-enter installs them all.
# With a single candidate, or with no fzf and no tty, it falls back to the
# numbered y/N prompt — nothing is ever installed unattended.
#
# The name is NOT added to install/packages/*.txt: -i is the one-off, the
# list + `install/packages.sh` is how a package reaches both machines. The
# line to add is printed after a successful install.
#
# Managers (query): pacman, aur (pacman -Qm, i.e. paru/yay builds), brew,
#   cask, npm, pnpm, yarn, cargo, go, pipx, pip, gem, flatpak, snap, mas
# Managers (-i): pacman, aur, brew, cask, node (pnpm or npm), cargo, go,
#   pypi (pipx or pip), gem, flatpak, snap
#
# Written for bash 3.2 (macOS's stock /bin/bash) as well as modern bash.
#
# Env overrides: NO_COLOR

set -uo pipefail

MANAGERS="pacman aur brew cask npm pnpm yarn cargo go pipx pip gem flatpak snap mas"

POPUP_W="85%"
POPUP_H="80%"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'
else
  C_RESET='' C_DIM='' C_BOLD='' C_GREEN='' C_YELLOW=''
fi

have() { command -v "$1" >/dev/null 2>&1; }

# The script re-runs itself for each manager's search (one process per
# manager, all at once) and for fzf's preview, so it has to know its own
# path. Resolved through the symlink, since that is what -i hands to tmux.
SELF="$(realpath "$0" 2>/dev/null || printf '%s' "$0")"

# A registry that never answers must not hang the picker.
SEARCH_TIMEOUT=""
have timeout && SEARCH_TIMEOUT="timeout 15"

# The header block above, whatever length it grows to.
usage() {
  awk 'NR > 2 && /^#/ { sub(/^# ?/, ""); print; next } NR > 2 { exit }' "$0"
}

# ---------------------------------------------------------------------------
# Managers
#
# Each list prints one "name<TAB>version" line per installed package. Every
# command is read-only, and a manager that is not installed is skipped by
# mgr_available, so the same script runs unchanged on Arch and macOS.
# ---------------------------------------------------------------------------

# pip is pip3 on most systems and pip inside a venv; resolved once.
PIP="$(command -v pip3 2>/dev/null || command -v pip 2>/dev/null || true)"

mgr_available() {
  case "$1" in
    pacman | aur) have pacman ;;
    brew | cask) have brew ;;
    pip) [[ -n "$PIP" ]] ;;
    *) have "$1" ;;
  esac
}

# at_version — stdin of "name@version" lines (npm/yarn style, tree glyphs
# and colors included) to "name<TAB>version". Splits on the LAST @ so that
# scoped names like @scope/pkg@1.0.0 survive.
at_version() {
  awk '{
    line = $0
    gsub(/\033\[[0-9;]*m/, "", line)
    sub(/[[:space:]]+$/, "", line)
    sub(/^[^A-Za-z@]*/, "", line)
    n = match(line, /@[^@]*$/)
    if (n > 1) printf "%s\t%s\n", substr(line, 1, n - 1), substr(line, n + 1)
  }'
}

go_bin() {
  local b gopath
  b="${GOBIN:-$(go env GOBIN 2>/dev/null)}"
  if [[ -z "$b" ]]; then
    # No GOPATH would make this "/bin", and every binary in it a go install.
    gopath="$(go env GOPATH 2>/dev/null)"
    [[ -n "$gopath" ]] && b="$gopath/bin"
  fi
  printf '%s' "$b"
}

# go has no installed-package database: the binaries in GOBIN are it, and
# each one carries the module it was built from.
go_list() {
  local bin f v
  bin="$(go_bin)"
  [[ -d "$bin" ]] || return 0
  for f in "$bin"/*; do
    [[ -f "$f" && -x "$f" ]] || continue
    v="$(go version -m "$f" 2>/dev/null | awk '$1 == "mod" { print $3; exit }')"
    printf '%s\t%s\n' "${f##*/}" "${v:--}"
  done
}

mgr_list() {
  case "$1" in
    pacman) pacman -Qen 2>/dev/null | awk 'NF >= 2 { print $1 "\t" $2 }' ;;
    aur) pacman -Qm 2>/dev/null | awk 'NF >= 2 { print $1 "\t" $2 }' ;;
    brew) brew list --formula --versions 2>/dev/null | awk 'NF >= 1 { print $1 "\t" $2 }' ;;
    cask) brew list --cask --versions 2>/dev/null | awk 'NF >= 1 { print $1 "\t" $2 }' ;;
    npm) npm ls -g --depth=0 2>/dev/null | at_version ;;
    pnpm) pnpm ls -g --depth=0 2>/dev/null | at_version ;;
    yarn) yarn global list --depth=0 2>/dev/null | awk -F'"' '/^info/ && NF >= 2 { print $2 }' | at_version ;;
    cargo) cargo install --list 2>/dev/null | awk '/^[^ ]/ { v = $2; sub(/^v/, "", v); sub(/:$/, "", v); print $1 "\t" v }' ;;
    go) go_list ;;
    pipx) pipx list --short 2>/dev/null | awk 'NF >= 2 { print $1 "\t" $2 }' ;;
    pip) "$PIP" list --format=freeze 2>/dev/null | awk -F'==' 'NF == 2 { print $1 "\t" $2 }' ;;
    gem) gem list --local 2>/dev/null | awk '/^[A-Za-z0-9]/ { v = $0; sub(/^[^(]*\(/, "", v); sub(/\)$/, "", v); sub(/^default: /, "", v); print $1 "\t" v }' ;;
    flatpak) flatpak list --app --columns=application,version 2>/dev/null ;;
    snap) snap list 2>/dev/null | awk 'NR > 1 { print $1 "\t" $2 }' ;;
    mas) mas list 2>/dev/null | awk '{ id = $1; $1 = ""; v = $NF; gsub(/[()]/, "", v); $NF = ""; sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); print $0 "\t" v }' ;;
  esac
}

# ---------------------------------------------------------------------------
# Binary ownership
#
# The package name and the command name often differ (ripgrep/rg), and a
# hand-dropped binary belongs to no manager at all — both only show up by
# following what is actually on PATH.
# ---------------------------------------------------------------------------

# resolve <path> — follow symlinks without readlink -f (not on old macOS).
resolve() {
  local p="$1" target dir
  while [[ -L "$p" ]]; do
    target="$(readlink "$p")"
    case "$target" in
      /*) p="$target" ;;
      *)
        dir="$(cd "$(dirname "$p")" 2>/dev/null && pwd)" || break
        p="$dir/$target"
        ;;
    esac
  done
  printf '%s' "$p"
}

# owner <resolved-path> — one line naming what put the file there, or
# nothing when no manager claims it.
owner() {
  local real="$1" pkg mod

  if have pacman; then
    pkg="$(pacman -Qo "$real" 2>/dev/null | awk '{ print $(NF-1), $NF }')"
    if [[ -n "$pkg" ]]; then
      if pacman -Qm 2>/dev/null | grep -q "^${pkg% *} "; then
        printf 'aur package: %s' "$pkg"
      else
        printf 'pacman package: %s' "$pkg"
      fi
      return 0
    fi
  fi

  case "$real" in
    */Cellar/*)
      pkg="${real#*/Cellar/}"
      printf 'brew formula: %s' "${pkg%%/*}"
      return 0
      ;;
    */Caskroom/*)
      pkg="${real#*/Caskroom/}"
      printf 'brew cask: %s' "${pkg%%/*}"
      return 0
      ;;
    "$HOME"/.cargo/bin/*)
      printf 'cargo install'
      return 0
      ;;
    */node_modules/*)
      pkg="${real#*/node_modules/}"
      printf 'node package: %s' "${pkg%%/*}"
      return 0
      ;;
  esac

  if have go && [[ "$real" == "$(go_bin)"/* ]]; then
    mod="$(go version -m "$real" 2>/dev/null | awk '$1 == "path" { print $2; exit }')"
    printf 'go install: %s' "${mod:-unknown module}"
    return 0
  fi

  return 1
}

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

row() { printf '%-10s %-28s %s\n' "$1" "$2" "$3"; }

list_all() {
  local m count
  for m in "$@"; do
    mgr_available "$m" || continue
    printf '%s%s%s\n' "$C_BOLD" "$m" "$C_RESET"
    count=0
    while IFS=$'\t' read -r name version; do
      [[ -n "$name" ]] || continue
      printf '  %-30s %s%s%s\n' "$name" "$C_DIM" "${version:--}" "$C_RESET"
      count=$((count + 1))
    done < <(mgr_list "$m")
    [[ "$count" -eq 0 ]] && printf '  %s(none)%s\n' "$C_DIM" "$C_RESET"
    printf '\n'
  done
}

lookup() {
  local query="$1" q m hits found=0 real path_line owner_line
  q="$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')"
  hits="$(mktemp "${TMPDIR:-/tmp}/pkg.XXXXXX")" || return 1

  for m in $MANAGERS; do
    mgr_available "$m" || continue
    mgr_list "$m" | awk -F'\t' -v mgr="$m" -v q="$q" '
      { n = tolower($1) }
      n == q { print "0\t" mgr "\t" $1 "\t" $2; next }
      index(n, q) { print "1\t" mgr "\t" $1 "\t" $2 }
    ' >>"$hits"
  done

  # Exact matches win outright; substrings are a fallback, not a mix.
  if grep -q '^0' "$hits" 2>/dev/null; then
    grep '^0' "$hits" >"$hits.show"
  else
    cp "$hits" "$hits.show"
    [[ -s "$hits.show" ]] &&
      printf '%sno exact match for "%s" — showing substring matches%s\n\n' \
        "$C_YELLOW" "$query" "$C_RESET"
  fi

  if [[ -s "$hits.show" ]]; then
    found=1
    row "MANAGER" "PACKAGE" "VERSION"
    while IFS=$'\t' read -r _ mgr name version; do
      row "$mgr" "$name" "${version:--}"
    done <"$hits.show"
  fi
  rm -f "$hits" "$hits.show"

  # What is actually on PATH, which is the real question when the command
  # name and the package name differ.
  path_line="$(command -v -- "$query" 2>/dev/null)"
  if [[ -n "$path_line" && -e "$path_line" ]]; then
    found=1
    real="$(resolve "$path_line")"
    printf '\n'
    if [[ "$real" == "$path_line" ]]; then
      printf '%-10s %s\n' "binary" "$path_line"
    else
      printf '%-10s %s %s->%s %s\n' "binary" "$path_line" "$C_DIM" "$C_RESET" "$real"
    fi
    if owner_line="$(owner "$real")"; then
      printf '%-10s %s%s%s\n' "" "$C_GREEN" "$owner_line" "$C_RESET"
    else
      printf '%-10s %snot owned by any manager — installed by hand%s\n' \
        "" "$C_YELLOW" "$C_RESET"
    fi
  fi

  if [[ "$found" -eq 0 ]]; then
    printf '%s: nothing matching "%s" in any manager, and no such command\n' \
      "${0##*/}" "$query" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Installing
#
# A second manager list, because installing groups them differently from
# querying: npm/pnpm/yarn share one registry and pip/pipx share PyPI, so
# each pair is a single candidate here, installed with whichever half of it
# exists. mas needs an app id rather than a name, so it stays query-only.
# ---------------------------------------------------------------------------

SYSTEM_INSTALLERS="pacman aur brew cask"
LANG_INSTALLERS="node cargo pypi gem flatpak snap go"

AUR_HELPER="$(command -v paru 2>/dev/null || command -v yay 2>/dev/null || true)"
NODE_GLOBAL="$(command -v pnpm 2>/dev/null || command -v npm 2>/dev/null || true)"

inst_available() {
  case "$1" in
    aur) [[ -n "$AUR_HELPER" ]] ;;
    brew | cask) have brew ;;
    node) [[ -n "$NODE_GLOBAL" ]] ;;
    pypi) have pipx || [[ -n "$PIP" ]] ;;
    *) have "$1" ;;
  esac
}

# valid_name <name> — a name reaches a shell command below, so anything
# that is not plausibly a package name is refused here rather than quoted
# through four managers' argument conventions.
valid_name() {
  case "$1" in
    *[!A-Za-z0-9._/@+-]* | '' | -* | *..*) return 1 ;;
    *) return 0 ;;
  esac
}

# inst_search <manager> <name> — success when that manager carries exactly
# this name. All of these hit the network except pacman and brew.
inst_search() {
  case "$1" in
    pacman) pacman -Ssq "^$2\$" 2>/dev/null | grep -qx -- "$2" ;;
    aur) "$AUR_HELPER" -Ssqa "^$2\$" 2>/dev/null | grep -qx -- "$2" ;;
    brew) brew info --formula "$2" >/dev/null 2>&1 ;;
    cask) brew info --cask "$2" >/dev/null 2>&1 ;;
    node)
      case "${NODE_GLOBAL##*/}" in
        pnpm) pnpm info "$2" version >/dev/null 2>&1 ;;
        *) npm view "$2" version >/dev/null 2>&1 ;;
      esac
      ;;
    cargo) cargo search --limit 1 -- "$2" 2>/dev/null | grep -q "^$2 = " ;;
    # shortcut: `pip index versions` is experimental, so a pip too old for
    # it just means PyPI is never offered — `pkg -i pip:name` still works.
    pypi) [[ -n "$PIP" ]] && "$PIP" index versions "$2" >/dev/null 2>&1 ;;
    gem) gem search -eq -- "$2" 2>/dev/null | grep -q "^$2 " ;;
    # shortcut: flatpak/snap names rarely equal the app id (com.foo.Bar),
    # so these match loosely and can offer a near miss.
    flatpak) flatpak search "$2" 2>/dev/null | grep -qi -- "$2" ;;
    snap) snap find "$2" 2>/dev/null | awk 'NR > 1 { print $1 }' | grep -qx -- "$2" ;;
    # go installs a module path, not a name: only something that looks like
    # one (host.tld/owner/tool) can be a candidate.
    go) case "$2" in *.*/*) return 0 ;; *) return 1 ;; esac ;;
  esac
}

# ss_two_line — pacman's and the AUR helpers' "repo/name version" line
# followed by an indented description, to "name<TAB>description".
ss_two_line() {
  awk '/^[^[:space:]]/ {
    name = $1
    sub(/^[^\/]*\//, "", name)
    desc = ""
    if ((getline line) > 0) { desc = line; sub(/^[[:space:]]+/, "", desc) }
    gsub(/\t/, " ", desc)
    print name "\t" desc
  }'
}

# inst_query <manager> <name> — every package that manager can offer for
# this name, as "name<TAB>description" lines (description may be empty).
# This is the loose half of the search: inst_search answers yes/no about one
# exact name, this one answers "what have you got". A manager with no search
# of its own (pypi since pip search was retired, go, which installs a module
# path rather than a name) returns nothing here and is covered by the exact
# fallback in query_mode.
inst_query() {
  case "$1" in
    pacman) pacman -Ss -- "$2" 2>/dev/null | ss_two_line ;;
    aur) "$AUR_HELPER" -Ssa -- "$2" 2>/dev/null | ss_two_line ;;
    # brew search prints bare names, and a "==> Formulae" banner to drop.
    brew) brew search --formula "$2" 2>/dev/null | awk 'NF == 1 && $1 !~ /^==>/ { print $1 "\t" }' ;;
    cask) brew search --cask "$2" 2>/dev/null | awk 'NF == 1 && $1 !~ /^==>/ { print $1 "\t" }' ;;
    # --parseable is name<TAB>description<TAB>author<TAB>date<TAB>version.
    node) have npm && npm search --parseable -- "$2" 2>/dev/null | awk -F'\t' 'NF >= 1 { print $1 "\t" $2 }' ;;
    cargo) cargo search --limit 40 -- "$2" 2>/dev/null |
      awk '/^[A-Za-z0-9_-]+ = / { h = index($0, "#"); print $1 "\t" (h ? substr($0, h + 2) : "") }' ;;
    gem) gem search -r -- "$2" 2>/dev/null | awk '/^[A-Za-z0-9]/ { print $1 "\t" }' ;;
    # The app id is what flatpak installs, so that is the name column.
    flatpak) flatpak search --columns=application,description "$2" 2>/dev/null |
      awk -F'\t' 'NF >= 1 { print $1 "\t" $2 }' ;;
    snap) snap find "$2" 2>/dev/null |
      awk 'NR > 1 && NF >= 5 { n = $1; $1 = $2 = $3 = $4 = ""; sub(/^[[:space:]]+/, ""); print n "\t" $0 }' ;;
  esac
}

# query_mode <manager> <name> — one manager's rows, capped. Run as its own
# process (see search_all), which is also what makes the timeout possible.
# No search results but an exact hit still means the manager carries it.
query_mode() {
  local out
  out="$(inst_query "$1" "$2" 2>/dev/null | head -40)"
  if [[ -n "$out" ]]; then
    printf '%s\n' "$out"
  elif inst_search "$1" "$2" 2>/dev/null; then
    printf '%s\t\n' "$2"
  fi
}

# installed_snapshot — "name<TAB>manager" for every package on the machine.
# The local half of a search: forked alongside the registry queries, so it
# hides behind them and the rows can say what is already here.
installed_snapshot() {
  local m
  for m in $MANAGERS; do
    mgr_available "$m" || continue
    mgr_list "$m" | awk -F'\t' -v m="$m" '$1 != "" { print $1 "\t" m }'
  done
}

# search_all <name> — every manager asked at once, as picker rows:
# "display<TAB>manager<TAB>name<TAB>installed-with", exact names first,
# system managers before language ones (the sort keys are dropped by cut).
# The fourth column is the manager that already holds that name, if any, so
# the row says so on sight and the preview needs no lookup of its own.
#
# A name from a registry ends up in an eval down in do_install, so every
# row is put through valid_name here, where the untrusted data arrives.
#
# Rows whose name does not contain what was typed are dropped: npm's and
# cargo's search are relevance-ranked rather than literal, and will answer
# a nonsense name with twenty unrelated packages, which buries the one
# answer and hides the "nothing carries it" case entirely.
search_all() {
  local name="$1" d m i=0 pname desc rank snap rest inst dcolor
  d="$(mktemp -d "${TMPDIR:-/tmp}/pkgq.XXXXXX")" || return 1
  shopt -s nocasematch
  for m in $SYSTEM_INSTALLERS $LANG_INSTALLERS; do
    inst_available "$m" || continue
    # shellcheck disable=SC2086  # a command prefix, or empty
    $SEARCH_TIMEOUT "$SELF" --query "$m" "$name" >"$d/$m" 2>/dev/null &
  done
  installed_snapshot >"$d/.installed" 2>/dev/null &
  wait

  # Newline-padded, so a plain prefix removal finds "name<TAB>manager" and
  # hands back the manager: no fork per row, and no associative array
  # (bash 3.2, macOS's stock /bin/bash, has none).
  snap=$'\n'"$(cat "$d/.installed" 2>/dev/null)"$'\n'
  for m in $SYSTEM_INSTALLERS $LANG_INSTALLERS; do
    i=$((i + 1))
    [[ -s "$d/$m" ]] || continue
    while IFS=$'\t' read -r pname desc; do
      [[ -n "$pname" ]] || continue
      valid_name "$pname" || continue
      [[ "$pname" == *"$name"* ]] || continue
      if [[ "$pname" == "$name" ]]; then rank=0; else rank=1; fi

      rest="${snap#*$'\n'"$pname"$'\t'}"
      inst=""
      dcolor="$C_DIM"
      if [[ "$rest" != "$snap" ]]; then
        inst="${rest%%$'\n'*}"
        desc="● already installed with $inst"
        dcolor="$C_YELLOW"
      fi

      printf '%d\t%d\t%s[ ]%s %s%-8s%s %-28s %s%s%s\t%s\t%s\t%s\n' \
        "$rank" "$i" "$C_DIM" "$C_RESET" "$C_BOLD" "$m" "$C_RESET" "$pname" \
        "$dcolor" "${desc:0:90}" "$C_RESET" "$m" "$pname" "$inst"
    done <"$d/$m"
  done | sort -t$'\t' -k1,1n -k2,2n | cut -f3-
  shopt -u nocasematch
  rm -rf "$d"
}

# ---------------------------------------------------------------------------
# Picking
#
# Rows are "display<TAB>manager<TAB>name"; fzf shows the display column and
# hands back the two hidden ones. Inside tmux the fzf half runs in a
# display-popup — the same modal as tmuxScript/sessionizer.sh — and writes
# the pick to a file, because a popup's stdout goes to the popup and not to
# the command that opened it.
#
# The install itself also runs in the popup, so its log (pacman's download
# bars, a sudo prompt, cargo's build) is right under the row that started
# it. That log dies with the popup, so the popup holds on a keypress before
# closing, and the result line is printed in there too. The file then
# carries a third field — the install's exit status — which is how the
# caller knows it already ran, and that it has nothing to print itself.
# ---------------------------------------------------------------------------

# Rows ticked with ctrl-a are kept in a file of our own, not in fzf's
# --multi selection: a tick has to survive the next search, and fzf drops a
# mark on a row a reload removed from the list. Every reload prints the file
# back at the bottom, boxes ticked, so ticking a row moves it out of the
# candidates and into the list of what is about to be installed.
#
# With anything ticked, enter does nothing and alt-enter is the install
# key: a ticked set must not be mixed with whatever row the cursor happens
# to sit on. (Not ctrl-enter — a terminal sends the same byte for it as for
# enter, and fzf rejects the key name outright. alt-enter is the one a
# terminal can actually tell apart.)

# hdr_mode — the header, re-read after every tick so the count is live. A
# picker with a rows file behind it can bind j/k to movement; the one that
# searches as you type has to leave those letters alone, so there it is
# ctrl-j/ctrl-k.
hdr_mode() {
  local n=0
  [[ -n "${PKG_CART:-}" && -s "${PKG_CART}" ]] && n="$(grep -c . "$PKG_CART")"
  if [[ -n "${PKG_BASE:-}" ]]; then
    printf '  j/k move · esc cancels\n'
  else
    printf '  type to search every manager · ctrl-j/ctrl-k move · esc quits\n'
  fi
  if [[ "$n" -gt 0 ]]; then
    printf '  [x] %d ticked · alt-enter installs them · ctrl-a unticks · enter does nothing\n' "$n"
  else
    printf '  ctrl-a ticks a row · enter installs the one under the cursor\n'
  fi
}

# enter_mode — what enter does, decided when it is pressed: with rows
# ticked, nothing but a bell and a line in the preview naming the key that
# installs them; otherwise install the highlighted row.
enter_mode() {
  local n
  if [[ -n "${PKG_CART:-}" && -s "${PKG_CART}" ]]; then
    n="$(grep -c . "$PKG_CART")"
    printf 'bell+preview(echo "  %d ticked — alt-enter installs them, ctrl-a unticks")' "$n"
  else
    printf 'accept'
  fi
}

# The ticked rows, as picker rows again — the same four columns search_all
# prints, with the box ticked and the tick where the description was.
cart_rows() {
  local m n inst desc dcolor
  [[ -n "${PKG_CART:-}" && -s "$PKG_CART" ]] || return 0
  while IFS=$'\t' read -r m n inst; do
    [[ -n "$m" && -n "$n" ]] || continue
    if [[ -n "$inst" ]]; then
      desc="● already installed with $inst"
      dcolor="$C_YELLOW"
    else
      desc="alt-enter installs it"
      dcolor="$C_GREEN"
    fi
    printf '%s[x]%s %s%-8s%s %-28s %s%s%s\t%s\t%s\t%s\n' \
      "$C_GREEN" "$C_RESET" "$C_BOLD" "$m" "$C_RESET" "$n" \
      "$dcolor" "$desc" "$C_RESET" "$m" "$n" "$inst"
  done <"$PKG_CART"
}

# The rows that are not ticked, in the order they arrived: a ticked row is
# at the bottom of the list, not in both halves of it.
cart_filter() {
  if [[ -n "${PKG_CART:-}" && -s "$PKG_CART" ]]; then
    awk -F'\t' 'NR == FNR { m[$1 "\t" $2]; next } !(($2 "\t" $3) in m)' "$PKG_CART" -
  else
    cat
  fi
}

# mark_mode <manager> <name> [installed-with] — ctrl-a: the row joins the
# ticked list, or leaves it when it is already there, so ctrl-a undoes
# itself. Names come from registries, so the same check as everywhere else.
mark_mode() {
  local line rest
  [[ -n "${PKG_CART:-}" && -n "${1:-}" && -n "${2:-}" ]] || return 0
  valid_name "$2" || return 0
  inst_available "$1" || return 0
  line="$(printf '%s\t%s\t%s' "$1" "$2" "${3:-}")"
  if grep -qxF "$line" "$PKG_CART" 2>/dev/null; then
    rest="$(grep -vxF "$line" "$PKG_CART")"
    if [[ -n "$rest" ]]; then
      printf '%s\n' "$rest" >"$PKG_CART"
    else
      : >"$PKG_CART"
    fi
  else
    printf '%s\n' "$line" >>"$PKG_CART"
  fi
}

# rows_mode [query] — the list, rebuilt after every tick and (in search
# mode) every keystroke: the candidates first, then the ticked rows. The
# candidates are the rows file the picker was handed, or a fresh search of
# every manager — a single letter matches half of every registry, so a
# search starts at two. The ticked rows are printed whatever the query is,
# or they would fall out of the list and the tick with them.
rows_mode() {
  local q="${1:-}"
  if [[ -n "${PKG_BASE:-}" && -s "${PKG_BASE}" ]]; then
    cart_filter <"$PKG_BASE"
  elif [[ -z "${PKG_BASE:-}" && "${#q}" -ge 2 ]] && valid_name "$q"; then
    search_all "$q" | cart_filter
  fi
  cart_rows
}

# pick_fzf <rows-file|""> — the picker, both ways round: with a rows file it
# shows those rows and fzf's own filter refines them, with none it starts
# empty and every keystroke re-runs the search instead (--disabled, so fzf
# does not filter, and a short sleep is the debounce — fzf kills the
# previous reload when the next key arrives, so only the query you stopped
# typing on reaches the registries).
#
# </dev/null is what keeps the search picker empty until then: an fzf with
# no input of its own falls back to walking the current directory (whatever
# FZF_DEFAULT_COMMAND is), which would open the popup on a list of files.
#
# shortcut: j and k are bound to movement in the rows picker, so those two
# letters cannot be typed into its filter — the search term came from the
# command line, so the filter is only a refinement. Drop the bind if you
# ever want to type "jq" there.
pick_fzf() {
  local base="$1" out tick
  PKG_CART="$(mktemp "${TMPDIR:-/tmp}/pkgcart.XXXXXX")" || return 1
  # Exported: the --rows, --mark, --hdr and --enter children below are the
  # ones that read them.
  export PKG_CART PKG_BASE="$base"

  tick="ctrl-a:execute-silent(\"$SELF\" --mark {2} {3} {4})"
  tick="$tick+transform-header(\"$SELF\" --hdr)"

  local common=(--ansi --delimiter '\t' --with-nth=1 --prompt '  pkg  '
    --header "$(hdr_mode)" --header-first --layout=reverse --border=rounded
    --preview "\"$SELF\" --cmd {2} {3} {4}" --preview-window 'down,4,border-top'
    --bind "enter:transform(\"$SELF\" --enter)"
    --bind 'alt-enter:accept' --bind 'ctrl-alt-m:accept')

  if [[ -n "$base" ]]; then
    out="$(fzf "${common[@]}" \
      --bind "$tick+reload(\"$SELF\" --rows || true)" \
      --bind 'j:down,k:up,ctrl-j:down,ctrl-k:up' \
      <"$base" | cut -f2,3)"
  else
    out="$(fzf "${common[@]}" --disabled \
      --bind "change:reload(sleep 0.4; \"$SELF\" --rows {q} || true)" \
      --bind "$tick+reload(\"$SELF\" --rows {q} || true)" \
      --bind 'ctrl-j:down,ctrl-k:up' \
      </dev/null | cut -f2,3)"
  fi

  # Esc cancels the lot, ticks included: nothing was confirmed. Otherwise
  # the ticked rows are the answer, and the row under the cursor only when
  # nothing is ticked — enter is dead while anything is, so the two can
  # never arrive together.
  if [[ -n "$out" ]]; then
    if [[ -s "$PKG_CART" ]]; then
      cut -f1,2 "$PKG_CART"
    else
      printf '%s\n' "$out"
    fi
  fi
  rm -f "$PKG_CART"
}

# pick_popup <rows-file|""> — an empty rows file means search mode: the
# popup opens with nothing in it and fzf fills it as you type.
pick_popup() {
  local choice
  choice="$(mktemp "${TMPDIR:-/tmp}/pkgpick.XXXXXX")" || return 1
  tmux display-popup -E -w "$POPUP_W" -h "$POPUP_H" -T " pkg " \
    env PKG_ROWS="${1:-}" PKG_CHOICE="$choice" "$SELF" --pick
  cat "$choice"
  rm -f "$choice"
}

# pick_mode — the popup's half: pick the rows, install them here, hold the
# log. Every marked row is installed, one after the other, so a sudo prompt
# or a cargo build belongs to the row above it.
pick_mode() {
  local chosen c name status results="" picks=() line base=""
  [[ -n "${PKG_ROWS:-}" && -s "${PKG_ROWS}" ]] && base="$PKG_ROWS"
  chosen="$(pick_fzf "$base")"
  if [[ -z "$chosen" ]]; then
    : >"${PKG_CHOICE:?}"
    return 0
  fi
  # Collected first: the installs below need the terminal's stdin for sudo,
  # so the list cannot be what a loop is reading from. (A while-read, not
  # mapfile: bash 3.2, macOS's stock /bin/bash, has no mapfile.)
  while IFS= read -r line; do
    [[ -n "$line" ]] && picks+=("$line")
  done <<< "$chosen"

  # Written before the installs, not after: if the popup is killed halfway
  # through, the caller must read a failure and not install anything twice.
  : >"${PKG_CHOICE:?}"
  for line in "${picks[@]}"; do
    [[ -n "$line" ]] || continue
    printf '%s\t1\n' "$line" >>"$PKG_CHOICE"
  done

  for line in "${picks[@]}"; do
    [[ -n "$line" ]] || continue
    IFS=$'\t' read -r c name <<< "$line"
    install_now "$c" "$name"
    status=$?
    results+="$(printf '%s\t%s\t%d' "$c" "$name" "$status")"$'\n'
    report_install "$status" "$c" "$name"
  done
  printf '%s' "$results" >"$PKG_CHOICE"

  printf '\n  %s[enter closes this popup]%s ' "$C_DIM" "$C_RESET"
  read -r _ || true
}

# confirm_pick <rows-file> — the no-fzf path: the numbered list and a
# prompt, exactly as before. Everything it shows goes to stderr; stdout is
# the chosen "manager<TAB>name", same as the fzf path.
#
# shortcut: one row only here, no marking — accept a comma-separated answer
# if a machine without fzf ever has to install several at once.
confirm_pick() {
  local n i=0 mgr name choice
  n="$(grep -c . "$1")"
  while IFS=$'\t' read -r _ mgr name _; do
    [[ -n "$mgr" ]] || continue
    i=$((i + 1))
    printf '  %s%d)%s %-8s %s%s%s\n' \
      "$C_BOLD" "$i" "$C_RESET" "$mgr" "$C_DIM" "$(inst_cmd "$mgr" "$name")" "$C_RESET" >&2
  done <"$1"

  # Nothing is installed unattended: no tty means print the options and stop.
  if [[ ! -t 0 ]]; then
    printf '%s: no terminal to confirm on — nothing installed\n' "${0##*/}" >&2
    return 1
  fi

  if [[ "$n" -eq 1 ]]; then
    printf 'install with %s? [y/N] ' "$(cut -f2 <"$1")" >&2
    read -r choice
    case "$choice" in
      y | Y | yes) choice=1 ;;
      *) return 1 ;;
    esac
  else
    printf 'which? [1-%d, q] ' "$n" >&2
    read -r choice
    case "$choice" in
      [1-9] | [1-9][0-9]) [[ "$choice" -le "$n" ]] || return 1 ;;
      *) return 1 ;;
    esac
  fi
  sed -n "${choice}p" "$1" | cut -f2,3
}

# pick_and_install <rows-file|""> — the one path from "here are the
# candidates" (or, with no file, "start typing") to an installed package.
# A single candidate is a yes/no question rather than a picker, and inside
# tmux the picker is always the popup, which brings its own terminal — so
# this works from a tmux key binding, where there is no tty at all.
pick_and_install() {
  local rows="$1" chosen="" c name status n=0 popup=""

  [[ -n "$rows" ]] && n="$(grep -c . "$rows")"

  if have fzf && [[ "$n" -ne 1 ]] && [[ -n "${TMUX:-}" ]]; then
    chosen="$(pick_popup "$rows")"
    popup=1
  elif have fzf && [[ "$n" -ne 1 ]] && [[ -t 0 ]]; then
    chosen="$(pick_fzf "$rows")"
  elif [[ -n "$rows" ]]; then
    chosen="$(confirm_pick "$rows")"
  else
    printf '%s: the search popup needs fzf, inside tmux or a terminal\n' "${0##*/}" >&2
    return 1
  fi

  if [[ -z "$chosen" ]]; then
    [[ -n "$popup" ]] || printf 'nothing installed\n'
    return 1
  fi

  # Same stdin reason as pick_mode: the list is read into an array, not
  # piped into the loop that installs from it.
  local picks=() line failed=0
  while IFS= read -r line; do
    [[ -n "$line" ]] && picks+=("$line")
  done <<< "$chosen"

  for line in "${picks[@]}"; do
    [[ -n "$line" ]] || continue
    IFS=$'\t' read -r c name status <<< "$line"

    # A third field means the popup ran the install, and said so in there.
    # Out here there is nothing to add: with no terminal of our own (a tmux
    # key binding) anything printed becomes a view window over the session.
    if [[ -z "$status" ]]; then
      install_now "$c" "$name"
      status=$?
      report_install "$status" "$c" "$name"
    fi
    [[ "$status" -eq 0 || "$status" -eq 2 ]] || failed=1
  done
  return "$failed"
}

# inst_cmd <manager> <name> — the exact command, printed in the prompt and
# then run. One source of truth, so what you confirm is what executes.
inst_cmd() {
  case "$1" in
    pacman) printf 'sudo pacman -S --needed %s' "$2" ;;
    aur) printf '%s -S --needed %s' "${AUR_HELPER##*/}" "$2" ;;
    brew) printf 'brew install %s' "$2" ;;
    cask) printf 'brew install --cask %s' "$2" ;;
    node)
      case "${NODE_GLOBAL##*/}" in
        pnpm) printf 'pnpm add -g %s' "$2" ;;
        *) printf 'npm install -g %s' "$2" ;;
      esac
      ;;
    cargo) printf 'cargo install %s' "$2" ;;
    pypi)
      if have pipx; then printf 'pipx install %s' "$2"; else printf '%s install --user %s' "$PIP" "$2"; fi
      ;;
    gem) printf 'gem install %s' "$2" ;;
    flatpak) printf 'flatpak install -y flathub %s' "$2" ;;
    snap) printf 'sudo snap install %s' "$2" ;;
    go) printf 'go install %s@latest' "$2" ;;
  esac
}

# A one-off install reaches this machine only. These two lists are what
# reaches both, so the line to add is printed afterwards.
inst_list_hint() {
  case "$1" in
    pacman | aur) printf 'install/packages/arch.txt   %s' "$2" ;;
    brew) printf 'install/packages/brew.txt   %s' "$2" ;;
    cask) printf 'install/packages/brew.txt   cask:%s' "$2" ;;
    *) return 1 ;;
  esac
}

# installed_by <name> — exact matches only, to catch "it is already here"
# before searching a registry for it.
installed_by() {
  local m
  for m in $MANAGERS; do
    mgr_available "$m" || continue
    mgr_list "$m" | awk -F'\t' -v mgr="$m" -v q="$1" '
      tolower($1) == tolower(q) { print mgr "\t" $1 "\t" $2 }
    '
  done
}

# already_installed <name> — one line per manager holding this exact name,
# and success when any of them does. Both installing paths ask this before
# they install anything, so a picker row for something already on the
# machine says so instead of being handed to the manager a second time.
already_installed() {
  local missing=1 m pname pver name="$1"
  while IFS=$'\t' read -r m pname pver; do
    [[ -n "$m" ]] || continue
    printf '%s%s is already installed with %s%s %s(%s)%s\n' \
      "$C_YELLOW" "$pname" "$m" "$C_RESET" "$C_DIM" "${pver:--}" "$C_RESET"
    missing=0
  done < <(installed_by "$name")
  return "$missing"
}

# resolve_installer <query-manager-name> — the -i name for a manager the
# query side calls something else, so `pkg -i npm:foo` works.
resolve_installer() {
  case "$1" in
    npm | pnpm | yarn | node) printf 'node' ;;
    pip | pipx | pypi) printf 'pypi' ;;
    *) printf '%s' "$1" ;;
  esac
}

do_install() {
  local spec="$1" name mgr="" rows status

  case "$spec" in
    *:*)
      mgr="$(resolve_installer "${spec%%:*}")"
      name="${spec#*:}"
      ;;
    *) name="$spec" ;;
  esac

  if ! valid_name "$name"; then
    printf '%s: refusing "%s": not a package name\n' "${0##*/}" "$name" >&2
    return 1
  fi

  rows="$(mktemp "${TMPDIR:-/tmp}/pkgrows.XXXXXX")" || return 1

  if [[ -n "$mgr" ]]; then
    # manager:name skips the search entirely — the manager is the answer.
    if ! inst_available "$mgr"; then
      printf '%s: %s cannot install here (try -m)\n' "${0##*/}" "$mgr" >&2
      rm -f "$rows"
      return 1
    fi
    printf '%s[ ]%s %s%-8s%s %s\t%s\t%s\t\n' \
      "$C_DIM" "$C_RESET" "$C_BOLD" "$mgr" "$C_RESET" "$name" "$mgr" "$name" >"$rows"
  else
    if already_installed "$name"; then
      rm -f "$rows"
      return 0
    fi

    printf '%ssearching every manager for "%s"...%s\n' "$C_DIM" "$name" "$C_RESET"
    search_all "$name" >"$rows"
  fi

  if [[ ! -s "$rows" ]]; then
    printf '%s: no manager on this machine carries "%s"\n' "${0##*/}" "$name" >&2
    rm -f "$rows"
    return 1
  fi

  pick_and_install "$rows"
  status=$?
  rm -f "$rows"
  return "$status"
}

# install_now <manager> <name> — the command, run wherever its log belongs:
# in the popup when there is one, in the terminal otherwise.
install_now() {
  local c="$1" name="$2" cmd

  # The picker's rows come from registries, not from the typed name.
  if ! valid_name "$name" || ! inst_available "$c"; then
    printf '%s: refusing "%s" from %s\n' "${0##*/}" "$name" "$c" >&2
    return 1
  fi

  # Silently, because report_install is what says it out loud — in the popup
  # and again in the terminal the popup closes over, like any other result.
  already_installed "$name" >/dev/null && return 2

  cmd="$(inst_cmd "$c" "$name")"
  printf '%s+ %s%s\n' "$C_DIM" "$cmd" "$C_RESET"
  # Safe to eval: valid_name has already rejected everything but a name.
  eval "$cmd"
}

# report_install <status> <manager> <name> — the result line, printed where
# the install ran: inside the popup for a popup install, in the terminal for
# a terminal one. Never both, so closing the popup leaves nothing behind.
report_install() {
  local status="$1" c="$2" name="$3" hint

  # 2 is install_now's "this is already here" — the name is on the machine,
  # so the answer is where it came from, not an install or a failure. The
  # managers are asked again because that line is all the popup hands back.
  if [[ "$status" -eq 2 ]]; then
    already_installed "$name" ||
      printf '%s%s is already installed%s\n' "$C_YELLOW" "$name" "$C_RESET"
    return 0
  fi

  if [[ "$status" -ne 0 ]]; then
    printf '%s: %s failed\n' "${0##*/}" "$c" >&2
    return 1
  fi

  printf '%sinstalled %s with %s%s\n' "$C_GREEN" "$name" "$c" "$C_RESET"
  if hint="$(inst_list_hint "$c" "$name")"; then
    printf '%sto get it on the other machine too, add to %s%s\n' "$C_DIM" "$hint" "$C_RESET"
  else
    printf '%s%s is not covered by install/packages/* — this one is machine-local%s\n' \
      "$C_DIM" "$c" "$C_RESET"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# The re-entry points: one search process per manager, the popup's fzf, and
# fzf's preview. All three are this same script called by itself.
case "${1:-}" in
  --query)
    query_mode "${2:-}" "${3:-}"
    exit 0
    ;;
  --pick)
    pick_mode
    exit 0
    ;;
  --rows)
    rows_mode "${2:-}"
    exit 0
    ;;
  --mark)
    mark_mode "${2:-}" "${3:-}" "${4:-}"
    exit 0
    ;;
  --hdr)
    hdr_mode
    exit 0
    ;;
  --enter)
    enter_mode
    exit 0
    ;;
  --cmd)
    # The row carries the manager that already holds it, so this is a read of
    # its fourth column — not a scan of the machine on every cursor move.
    if [[ -n "${4:-}" ]]; then
      printf '  %s%s is already installed with %s%s\n' \
        "$C_YELLOW" "${3:-}" "$4" "$C_RESET"
    elif valid_name "${3:-}"; then
      printf '  %sinstalls with%s\n  %s\n' \
        "$C_DIM" "$C_RESET" "$(inst_cmd "${2:-}" "${3:-}")"
    fi
    exit 0
    ;;
esac

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  '')
    # No name at all: the popup is the search box. This is what tmux's
    # prefix+p runs, so it has to work with no terminal of its own — and
    # always succeed: a picker that was closed is not a failed command, and
    # tmux's run-shell announces any non-zero status as "... returned 1"
    # over the session. Whatever happened, the popup has already said so.
    pick_and_install "" || true
    exit 0
    ;;
  -i | --install)
    shift
    if [[ "$#" -ne 1 ]]; then
      printf '%s: usage: pkg -i <name|manager:name>\n' "${0##*/}" >&2
      exit 1
    fi
    do_install "$1"
    exit $?
    ;;
  -m | --managers)
    for m in $MANAGERS; do
      if mgr_available "$m"; then
        printf '%s%-10s present%s\n' "$C_GREEN" "$m" "$C_RESET"
      else
        printf '%s%-10s -%s\n' "$C_DIM" "$m" "$C_RESET"
      fi
    done
    exit 0
    ;;
  -l | --list)
    shift
    if [[ "$#" -gt 0 ]]; then
      for m in "$@"; do
        case " $MANAGERS " in
          *" $m "*) ;;
          *)
            printf '%s: unknown manager: %s (try -m)\n' "${0##*/}" "$m" >&2
            exit 1
            ;;
        esac
      done
      list_all "$@"
    else
      # shellcheck disable=SC2086  # intentional word split
      list_all $MANAGERS
    fi
    exit 0
    ;;
  -*)
    printf '%s: unknown option: %s\n' "${0##*/}" "$1" >&2
    exit 1
    ;;
  *)
    # A bare name is "get me this": say where it already is, and when it is
    # nowhere on the machine, fall through to the search-and-install picker.
    lookup "$1" 2>/dev/null && exit 0
    do_install "$1"
    exit $?
    ;;
esac
