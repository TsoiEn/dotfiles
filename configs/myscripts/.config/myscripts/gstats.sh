#!/usr/bin/env bash
#
# gstats.sh — one `git status` for every repo you own.
#
# The problem it solves: work is spread over a dozen clones under
# ~/Development, and the things that bite are the ones you cannot see from
# inside any single one of them — the branch you left dirty on Friday, the
# three commits that never got pushed, the repo whose upstream moved on
# without you. Finding those means cd-ing through every directory in turn.
#
# gstats walks the roots once and prints a single table: which repo, which
# branch, how far ahead/behind, what is uncommitted, when it was last
# touched. By default only repos that want something from you are listed —
# `-a` shows the clean ones too.
#
#   repo                     branch     sync    changes        last
#   Personal/dotfiles        main       ^2      +3 ~5 ?1       2h
#   Work/frontend-monorepo   feat/auth  v12     ~2             3d
#   Personal/GoTask          main       local   ?4             3w
#
#   sync      ^N ahead · vN behind · "local" no upstream · "gone" upstream
#             deleted · blank in sync
#   changes   +staged  ~unstaged  ?untracked  !conflicts  *stashes
#
# Usage:
#   gstats                     # repos needing attention, newest activity first
#   gstats -a                  # include clean, fully-pushed repos
#   gstats -f                  # git fetch everything first (real behind counts)
#   gstats -s name             # sort by path instead of last-commit time
#   gstats -r ~/src -r ~/work  # scan these roots instead of the defaults
#
# Without -f the ahead/behind column reflects the last fetch, not the
# remote right now — no network is touched, so a run over 30 repos is
# instant. -f fetches in parallel (GSTATS_JOBS at a time) and is the slow,
# accurate mode.
#
# Written for bash 3.2 (macOS's stock /bin/bash) as well as modern bash.
#
# Env overrides: GSTATS_ROOTS (colon-separated), GSTATS_DEPTH, GSTATS_JOBS,
#                GSTATS_PRUNE (colon-separated directory names), NO_COLOR

set -uo pipefail

DEFAULT_ROOTS="${GSTATS_ROOTS:-$HOME/Development}"
MAX_DEPTH="${GSTATS_DEPTH:-4}"
FETCH_JOBS="${GSTATS_JOBS:-8}"

# Directory names never worth descending into. Vendored trees hide hundreds
# of .git directories and none of them are yours.
PRUNE_DIRS="${GSTATS_PRUNE:-node_modules:vendor:.venv:venv:.cache:Library:.Trash:.terraform:target}"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[1;31m'
  C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'
  C_BLUE=$'\033[1;34m'
  C_CYAN=$'\033[1;36m'
else
  C_RESET=""; C_DIM=""; C_BOLD=""
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

warn() { printf '%swarn:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
gstats — git status for every repo under your development roots.

  gstats [-a] [-f] [-s time|name] [-r ROOT]... [-d DEPTH] [--no-color]

  -a, --all        also list clean, fully-synced repos
  -f, --fetch      git fetch each repo first (parallel, slow, accurate)
  -s, --sort KEY   time (default, newest commit first) | name
  -r, --root PATH  scan PATH; repeatable, replaces the defaults
  -d, --depth N    how deep to search for repos below a root (default 4)
      --no-color   plain output
  -h, --help       this

Columns
  sync      ^N commits ahead of upstream · vN behind · local = no upstream
            configured · gone = upstream branch deleted · blank = in sync
  changes   +staged  ~unstaged  ?untracked  !conflicts  *stashed

Only repos with something outstanding are listed unless -a is given.
Defaults come from GSTATS_ROOTS (default ~/Development), GSTATS_DEPTH,
GSTATS_JOBS, GSTATS_PRUNE.
EOF
}

# ---------------------------------------------------------------------------
# Finding repos
# ---------------------------------------------------------------------------

# _phys <path> — physical path of an existing dir, else the path as given.
_phys() {
  if [[ -d "$1" ]]; then (cd "$1" && pwd -P); else printf '%s' "$1"; fi
}

# find_repos <root> — print the working-tree root of every repo under <root>,
# one per line.
#
# `-name .git -prune -print` stops find from walking the object database,
# which is where the bulk of the inodes live. Both a .git directory (normal
# clone) and a .git file (worktree, submodule) match.
find_repos() {
  local root="$1"
  local prune_expr=() name rest="$PRUNE_DIRS"

  while [[ -n "$rest" ]]; do
    name="${rest%%:*}"
    if [[ "$rest" == *:* ]]; then rest="${rest#*:}"; else rest=""; fi
    [[ -n "$name" ]] || continue
    prune_expr[${#prune_expr[@]}]="-name"
    prune_expr[${#prune_expr[@]}]="$name"
    prune_expr[${#prune_expr[@]}]="-o"
  done

  # Depth is counted from the repo's .git, so a repo at depth N needs N+1.
  find "$root" -maxdepth $((MAX_DEPTH + 1)) \
    \( "${prune_expr[@]}" -name .git \) -prune -print 2>/dev/null |
    while IFS= read -r hit; do
      [[ "${hit##*/}" == ".git" ]] || continue   # a pruned node_modules
      printf '%s\n' "${hit%/.git}"
    done
}

# is_submodule <repo> — true when .git is a file pointing into another repo's
# modules/ store. Submodules are the parent's business, not yours; listing
# them doubles the table and every one of them is "detached HEAD".
is_submodule() {
  local dotgit="$1/.git"
  [[ -f "$dotgit" ]] || return 1
  grep -q 'gitdir:.*/\.git/modules/' "$dotgit" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Reading one repo
# ---------------------------------------------------------------------------

# Set by read_repo, consumed by the caller (bash 3.2: no return-by-value).
R_BRANCH="" R_AHEAD=0 R_BEHIND=0 R_UPSTREAM=""
R_STAGED=0 R_UNSTAGED=0 R_UNTRACKED=0 R_CONFLICT=0 R_STASH=0
R_LAST=0

# read_repo <path> — fill the R_* globals. Returns 1 if the path is not a
# readable repo (deleted mid-scan, permissions, a corrupt clone).
read_repo() {
  local repo="$1" out line head upstream ab

  out="$(git -C "$repo" --no-optional-locks status --porcelain=v2 --branch 2>/dev/null)" || return 1

  R_BRANCH="" R_AHEAD=0 R_BEHIND=0 R_UPSTREAM=""
  R_STAGED=0 R_UNSTAGED=0 R_UNTRACKED=0 R_CONFLICT=0 R_STASH=0
  R_LAST=0

  while IFS= read -r line; do
    case "$line" in
      '# branch.head '*)
        head="${line#\# branch.head }"
        if [[ "$head" == "(detached)" ]]; then
          R_BRANCH="detached"
        else
          R_BRANCH="$head"
        fi
        ;;
      '# branch.upstream '*)
        R_UPSTREAM="${line#\# branch.upstream }"
        ;;
      '# branch.ab '*)
        ab="${line#\# branch.ab }"
        R_AHEAD="${ab%% *}"; R_AHEAD="${R_AHEAD#+}"
        R_BEHIND="${ab##* }"; R_BEHIND="${R_BEHIND#-}"
        ;;
      '1 '*|'2 '*)
        # "<kind> XY ..." — X is the index state, Y the worktree state,
        # '.' meaning unchanged. A file can count toward both.
        [[ "${line:2:1}" != "." ]] && R_STAGED=$((R_STAGED + 1))
        [[ "${line:3:1}" != "." ]] && R_UNSTAGED=$((R_UNSTAGED + 1))
        ;;
      'u '*) R_CONFLICT=$((R_CONFLICT + 1)) ;;
      '? '*) R_UNTRACKED=$((R_UNTRACKED + 1)) ;;
    esac
  done <<< "$out"

  # An upstream that is configured but missing from the remote prints no
  # branch.ab line at all — that is how "gone" is told apart from "in sync".
  if [[ -n "$R_UPSTREAM" && "$out" != *'# branch.ab '* ]]; then
    R_UPSTREAM="-gone-"
  fi

  R_STASH="$(git -C "$repo" stash list 2>/dev/null | wc -l | tr -d ' ')"
  R_LAST="$(git -C "$repo" log -1 --format=%ct 2>/dev/null)"
  [[ -n "$R_LAST" ]] || R_LAST=0
  return 0
}

# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------

# rel_time <epoch> — "2h", "3d", "5w"; "—" for a repo with no commits yet.
rel_time() {
  local then="$1" now diff
  [[ "$then" -gt 0 ]] 2>/dev/null || { printf -- '-'; return; }
  now="$(date +%s)"
  diff=$((now - then))
  [[ $diff -lt 0 ]] && diff=0
  if   [[ $diff -lt 3600    ]]; then printf '%dm' $((diff / 60))
  elif [[ $diff -lt 86400   ]]; then printf '%dh' $((diff / 3600))
  elif [[ $diff -lt 604800  ]]; then printf '%dd' $((diff / 86400))
  elif [[ $diff -lt 2592000 ]]; then printf '%dw' $((diff / 604800))
  else                               printf '%dmo' $((diff / 2592000))
  fi
}

# plural <n> <singular> <plural>
plural() { [[ "$1" -eq 1 ]] && printf '%s' "$2" || printf '%s' "$3"; }

# pad <text> <width> — left-align to width. Done by hand rather than with
# printf's %-*s because that pads by bytes, and a multibyte glyph in the
# column would shift every row after it.
pad() {
  local text="$1" width="$2" n
  n=$((width - ${#text}))
  printf '%s' "$text"
  while [[ $n -gt 0 ]]; do printf ' '; n=$((n - 1)); done
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  local show_all=0 do_fetch=0 sort_key="time" no_color=0
  local roots=() arg

  while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
      -h|--help)     usage; return 0 ;;
      -a|--all)      show_all=1 ;;
      -f|--fetch)    do_fetch=1 ;;
      -s|--sort)     shift; sort_key="${1:-}" ;;
      --sort=*)      sort_key="${arg#--sort=}" ;;
      -r|--root)     shift; [[ -n "${1:-}" ]] || die "--root needs a path"
                     roots[${#roots[@]}]="$1" ;;
      --root=*)      roots[${#roots[@]}]="${arg#--root=}" ;;
      -d|--depth)    shift; MAX_DEPTH="${1:-4}" ;;
      --depth=*)     MAX_DEPTH="${arg#--depth=}" ;;
      --no-color)    no_color=1 ;;
      -*)            die "unknown option: $arg (try --help)" ;;
      *)             roots[${#roots[@]}]="$arg" ;;
    esac
    shift
  done

  case "$sort_key" in
    time|name) ;;
    *) die "--sort takes 'time' or 'name', got: $sort_key" ;;
  esac
  case "$MAX_DEPTH" in
    ''|*[!0-9]*) die "--depth takes a number, got: $MAX_DEPTH" ;;
  esac
  if [[ $no_color -eq 1 ]]; then
    C_RESET=""; C_DIM=""; C_BOLD=""
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
  fi

  command -v git >/dev/null 2>&1 || die "git is not installed"

  # Roots: -r flags if any, else GSTATS_ROOTS / the default.
  if [[ ${#roots[@]} -eq 0 ]]; then
    local rest="$DEFAULT_ROOTS" one
    while [[ -n "$rest" ]]; do
      one="${rest%%:*}"
      if [[ "$rest" == *:* ]]; then rest="${rest#*:}"; else rest=""; fi
      [[ -n "$one" ]] && roots[${#roots[@]}]="$one"
    done
  fi

  local root valid_roots=()
  for root in ${roots[@]+"${roots[@]}"}; do
    root="${root/#\~/$HOME}"
    if [[ -d "$root" ]]; then
      valid_roots[${#valid_roots[@]}]="$(_phys "$root")"
    else
      warn "no such directory, skipping: $root"
    fi
  done
  [[ ${#valid_roots[@]} -gt 0 ]] || die "no readable roots to scan"

  # Collect repos (deduplicated — two roots can overlap).
  local repos=() repo seen
  for root in "${valid_roots[@]}"; do
    while IFS= read -r repo; do
      [[ -n "$repo" ]] || continue
      seen=0
      for existing in ${repos[@]+"${repos[@]}"}; do
        [[ "$existing" == "$repo" ]] && { seen=1; break; }
      done
      [[ $seen -eq 1 ]] && continue
      is_submodule "$repo" && continue
      repos[${#repos[@]}]="$repo"
    done < <(find_repos "$root")
  done

  if [[ ${#repos[@]} -eq 0 ]]; then
    printf '%sno git repos found under:%s %s\n' \
      "$C_DIM" "$C_RESET" "$(printf '%s ' "${valid_roots[@]}")"
    return 0
  fi

  # Optional fetch, FETCH_JOBS at a time. Failures (offline, no remote, a
  # key that needs a passphrase) are silent: the scan still has last
  # fetch's numbers to report, which is what the no-fetch mode shows anyway.
  if [[ $do_fetch -eq 1 ]]; then
    printf '%s==>%s fetching %d %s…' "$C_BLUE" "$C_RESET" \
      "${#repos[@]}" "$(plural "${#repos[@]}" repo repos)" >&2
    local running=0
    for repo in "${repos[@]}"; do
      git -C "$repo" fetch --quiet --all --prune >/dev/null 2>&1 &
      running=$((running + 1))
      if [[ $running -ge $FETCH_JOBS ]]; then wait; running=0; fi
    done
    wait
    printf ' done\n' >&2
  fi

  # Build one row per interesting repo, fields separated by US (0x1f). A tab
  # cannot be used: IFS treats runs of whitespace as one delimiter, so a repo
  # with an empty column would silently shift every field after it.
  local SEP=$'\x1f'
  local rows=() name label sync changes dirty total=0 n_dirty=0 n_unpushed=0
  local w_name=4 w_branch=6 w_sync=4 w_changes=7

  for repo in "${repos[@]}"; do
    read_repo "$repo" || { warn "not readable, skipping: $repo"; continue; }
    total=$((total + 1))

    # Label: path relative to the root it was found under, with the root's
    # own basename kept so Personal/x and Work/x stay distinguishable.
    label="$repo"
    for root in "${valid_roots[@]}"; do
      if [[ "$repo" == "$root"/* ]]; then
        label="${repo#"$root"/}"
        break
      elif [[ "$repo" == "$root" ]]; then
        label="${root##*/}"
        break
      fi
    done

    sync=""
    if [[ "$R_UPSTREAM" == "-gone-" ]]; then
      sync="gone"
    elif [[ -z "$R_UPSTREAM" ]]; then
      sync="local"
    else
      [[ "$R_AHEAD"  -gt 0 ]] && sync="^$R_AHEAD"
      [[ "$R_BEHIND" -gt 0 ]] && sync="${sync:+$sync }v$R_BEHIND"
    fi

    changes=""
    [[ "$R_STAGED"    -gt 0 ]] && changes="+$R_STAGED"
    [[ "$R_UNSTAGED"  -gt 0 ]] && changes="${changes:+$changes }~$R_UNSTAGED"
    [[ "$R_UNTRACKED" -gt 0 ]] && changes="${changes:+$changes }?$R_UNTRACKED"
    [[ "$R_CONFLICT"  -gt 0 ]] && changes="${changes:+$changes }!$R_CONFLICT"
    [[ "$R_STASH"     -gt 0 ]] && changes="${changes:+$changes }*$R_STASH"

    # "Wants attention": anything uncommitted, anything unpushed, or a
    # branch with nowhere to push to. A clean repo in sync is silent.
    dirty=0
    [[ -n "$changes" ]] && dirty=1
    [[ -n "$sync" ]] && dirty=1
    [[ "$R_BRANCH" == "detached" ]] && dirty=1

    [[ -n "$changes" ]] && n_dirty=$((n_dirty + 1))
    { [[ "$R_AHEAD" -gt 0 ]] || [[ "$sync" == "local" && "$R_LAST" -gt 0 ]]; } &&
      n_unpushed=$((n_unpushed + 1))

    [[ $dirty -eq 0 && $show_all -eq 0 ]] && continue

    [[ ${#label}      -gt $w_name    ]] && w_name=${#label}
    [[ ${#R_BRANCH}   -gt $w_branch  ]] && w_branch=${#R_BRANCH}
    [[ ${#sync}       -gt $w_sync    ]] && w_sync=${#sync}
    [[ ${#changes}    -gt $w_changes ]] && w_changes=${#changes}

    # sortkey | label | branch | sync | changes | last | dirtyflag
    local sortkey
    if [[ "$sort_key" == "time" ]]; then
      sortkey="$(printf '%020d' "$R_LAST")"
    else
      sortkey="$label"
    fi
    rows[${#rows[@]}]="$sortkey$SEP$label$SEP$R_BRANCH$SEP$sync$SEP$changes$SEP$(rel_time "$R_LAST")$SEP$dirty"
  done

  if [[ ${#rows[@]} -eq 0 ]]; then
    printf '%s✓%s %d %s, all clean and in sync\n' \
      "$C_GREEN" "$C_RESET" "$total" "$(plural "$total" repo repos)"
    return 0
  fi

  # Cap the widest columns so one pathological branch name cannot push the
  # rest of the table off the terminal.
  [[ $w_name   -gt 44 ]] && w_name=44
  [[ $w_branch -gt 28 ]] && w_branch=28

  local sorted
  if [[ "$sort_key" == "time" ]]; then
    sorted="$(printf '%s\n' "${rows[@]}" | sort -r -t"$SEP" -k1,1)"
  else
    sorted="$(printf '%s\n' "${rows[@]}" | sort -f -t"$SEP" -k1,1)"
  fi

  printf '%s' "$C_BOLD"
  pad "repo" "$w_name";      printf '  '
  pad "branch" "$w_branch";  printf '  '
  pad "sync" "$w_sync";      printf '  '
  pad "changes" "$w_changes"; printf '  '
  printf 'last%s\n' "$C_RESET"

  local line label_c branch_c sync_c changes_c last_c sync_color
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    IFS="$SEP" read -r _ label_c branch_c sync_c changes_c last_c dirty <<< "$line"

    # Truncate with a leading … so the distinctive tail of a long path stays.
    [[ ${#label_c}  -gt $w_name   ]] && label_c="…${label_c:$((${#label_c} - w_name + 1))}"
    [[ ${#branch_c} -gt $w_branch ]] && branch_c="…${branch_c:$((${#branch_c} - w_branch + 1))}"

    case "$sync_c" in
      gone)  sync_color="$C_RED" ;;
      local) sync_color="$C_YELLOW" ;;
      "")    sync_color="$C_DIM" ;;
      *)     sync_color="$C_CYAN" ;;
    esac

    printf '%s' "$([[ $dirty -eq 0 ]] && printf '%s' "$C_DIM")"
    pad "$label_c" "$w_name"; printf '  '
    printf '%s' "$C_BLUE"; pad "$branch_c" "$w_branch"; printf '%s  ' "$C_RESET"
    printf '%s' "$sync_color"; pad "$sync_c" "$w_sync"; printf '%s  ' "$C_RESET"
    printf '%s' "$([[ -n "$changes_c" ]] && printf '%s' "$C_YELLOW")"
    pad "$changes_c" "$w_changes"; printf '%s  ' "$C_RESET"
    printf '%s%s%s\n' "$C_DIM" "$last_c" "$C_RESET"
  done <<< "$sorted"

  printf '%s%d %s · %d with changes · %d unpushed%s\n' \
    "$C_DIM" "$total" "$(plural "$total" repo repos)" \
    "$n_dirty" "$n_unpushed" "$C_RESET"
  [[ $do_fetch -eq 0 ]] &&
    printf '%s(ahead/behind as of the last fetch — gstats -f to refresh)%s\n' \
      "$C_DIM" "$C_RESET"
  return 0
}

main "$@"
