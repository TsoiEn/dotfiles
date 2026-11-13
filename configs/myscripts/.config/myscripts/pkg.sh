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
#   pkg <name>             # who has this package / owns this binary
#   pkg -i <name>          # find a manager that carries it, then install
#   pkg -i cask:ghostty    # skip the search, use this manager
#   pkg -l                 # everything, grouped by manager (the snapshot)
#   pkg -l brew pip        # only these managers
#   pkg -m                 # which managers exist on this machine
#
# Matching is exact first; with no exact hit, substrings are shown instead.
#
# -i searches the system managers first (pacman + AUR on Arch, brew + cask
# on macOS) and only falls back to the language managers when neither has
# it — that is the order you would pick by hand, and it keeps the common
# case to one query. Nothing is installed without a y/N confirmation, and
# the name is NOT added to install/packages/*.txt: -i is the one-off, the
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

usage() {
  sed -n '3,45p' "$0" | sed 's/^# \{0,1\}//'
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
  local b
  b="${GOBIN:-$(go env GOBIN 2>/dev/null)}"
  [[ -n "$b" ]] || b="$(go env GOPATH 2>/dev/null)/bin"
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
  local spec="$1" name mgr="" c cmd hint found=0 n=0 choice
  local candidates=""

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

  if [[ -n "$mgr" ]]; then
    if ! inst_available "$mgr"; then
      printf '%s: %s cannot install here (try -m)\n' "${0##*/}" "$mgr" >&2
      return 1
    fi
    candidates="$mgr"
  else
    while IFS=$'\t' read -r m pname pver; do
      [[ -n "$m" ]] || continue
      printf '%salready installed:%s %s %s %s\n' \
        "$C_YELLOW" "$C_RESET" "$m" "$pname" "${pver:--}"
      found=1
    done < <(installed_by "$name")
    [[ "$found" -eq 1 ]] && return 0

    # System managers first: if pacman or brew carries it, that is the
    # answer, and the language managers are never queried.
    printf '%ssearching for "%s"...%s\n' "$C_DIM" "$name" "$C_RESET"
    for c in $SYSTEM_INSTALLERS; do
      inst_available "$c" || continue
      inst_search "$c" "$name" && candidates="$candidates $c"
    done
    if [[ -z "${candidates// /}" ]]; then
      for c in $LANG_INSTALLERS; do
        inst_available "$c" || continue
        inst_search "$c" "$name" && candidates="$candidates $c"
      done
    fi
  fi

  candidates="${candidates# }"
  if [[ -z "$candidates" ]]; then
    printf '%s: no manager on this machine carries "%s"\n' "${0##*/}" "$name" >&2
    return 1
  fi

  for c in $candidates; do
    n=$((n + 1))
    printf '  %s%d)%s %-8s %s%s%s\n' \
      "$C_BOLD" "$n" "$C_RESET" "$c" "$C_DIM" "$(inst_cmd "$c" "$name")" "$C_RESET"
  done

  # Nothing is installed unattended: no tty means print the options and stop.
  if [[ ! -t 0 ]]; then
    printf '%s: no terminal to confirm on — nothing installed\n' "${0##*/}" >&2
    return 1
  fi

  if [[ "$n" -eq 1 ]]; then
    printf 'install with %s? [y/N] ' "$candidates"
    read -r choice
    case "$choice" in
      y | Y | yes) choice=1 ;;
      *) printf 'nothing installed\n'; return 1 ;;
    esac
  else
    printf 'which? [1-%d, q] ' "$n"
    read -r choice
    case "$choice" in
      [1-9] | [1-9][0-9]) [[ "$choice" -le "$n" ]] || { printf 'nothing installed\n'; return 1; } ;;
      *) printf 'nothing installed\n'; return 1 ;;
    esac
  fi

  # shellcheck disable=SC2086  # intentional word split into lines
  c="$(printf '%s\n' $candidates | sed -n "${choice}p")"
  cmd="$(inst_cmd "$c" "$name")"
  printf '%s+ %s%s\n' "$C_DIM" "$cmd" "$C_RESET"
  # Safe to eval: valid_name has already rejected everything but a name.
  if ! eval "$cmd"; then
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

case "${1:-}" in
  -h | --help | '')
    usage
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
    lookup "$1"
    exit $?
    ;;
esac
