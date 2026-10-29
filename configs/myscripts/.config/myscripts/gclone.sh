#!/usr/bin/env bash
#
# gclone.sh — `git clone` that picks the right GitHub identity from the
# directory you are standing in.
#
# Two accounts, one ~/.ssh/config with two Hosts for the same HostName:
#
#   Host github.com          IdentityFile ~/.ssh/id_ed25519           (work)
#   Host github-personal     IdentityFile ~/.ssh/id_ed25519_personal  (personal)
#
# So a personal repo has to be cloned through the `github-personal` alias,
# and its commits have to be signed with the personal name/email. Both are
# easy to forget, and both are annoying to fix after the fact. This script
# derives them from $PWD instead:
#
#   ~/Development/Personal/...  -> git@github-personal:owner/repo.git
#                                  + [user] name/email in .git/config
#   ~/Development/Work/...      -> git@github.com:owner/repo.git  (untouched)
#   anywhere else               -> work defaults + a warning
#
# Usage:
#   gclone git@github.com:TsoiEn/GoTask.git          # the normal case
#   gclone https://github.com/TsoiEn/GoTask.git      # browser-copied URL
#   gclone TsoiEn/GoTask                             # owner/repo shorthand
#   gclone TsoiEn/GoTask mydir --depth 1             # extra args reach git
#   gclone --dry-run TsoiEn/GoTask                   # print, don't run
#   gclone --no-cd TsoiEn/GoTask                     # clone, stay put
#
# After a successful clone the shell is moved into the new repo. A script
# cannot cd its parent shell, so the path is written to $GCLONE_CD_FILE and
# the `gclone` shell function (25-aliases.zsh) cds there once we exit.
#
# The input host never matters: whatever you paste is normalized to the
# scp-like form with the host this directory calls for. Non-GitHub URLs are
# passed through to git untouched.
#
# Written for bash 3.2 (macOS's stock /bin/bash) as well as modern bash.
#
# Env overrides: GCLONE_PERSONAL_ROOT, GCLONE_WORK_ROOT, GCLONE_PERSONAL_HOST,
#                GCLONE_WORK_HOST, GCLONE_PERSONAL_NAME, GCLONE_PERSONAL_EMAIL

set -euo pipefail

PERSONAL_ROOT="${GCLONE_PERSONAL_ROOT:-$HOME/Development/Personal}"
WORK_ROOT="${GCLONE_WORK_ROOT:-$HOME/Development/Work}"

PERSONAL_HOST="${GCLONE_PERSONAL_HOST:-github-personal}"
WORK_HOST="${GCLONE_WORK_HOST:-github.com}"

PERSONAL_NAME="${GCLONE_PERSONAL_NAME:-TsoiEn}"
PERSONAL_EMAIL="${GCLONE_PERSONAL_EMAIL:-paulanrenz23@gmail.com}"

# Colors only when stdout is a terminal (same convention as scripts/utils.sh).
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_INFO=$'\033[1;34m'
  C_WARN=$'\033[1;33m'
  C_ERROR=$'\033[1;31m'
else
  C_RESET=""; C_INFO=""; C_WARN=""; C_ERROR=""
fi

info()  { printf '%s==>%s %s\n' "$C_INFO" "$C_RESET" "$*"; }
warn()  { printf '%swarn:%s %s\n' "$C_WARN" "$C_RESET" "$*" >&2; }
die()   { printf '%serror:%s %s\n' "$C_ERROR" "$C_RESET" "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
gclone — clone a GitHub repo with the identity this directory calls for.

  gclone [--dry-run] [--no-cd] <repo> [dest] [git-clone-args...]

  <repo>   git@github.com:owner/repo.git | https://github.com/owner/repo
           | ssh://git@github.com/owner/repo.git | owner/repo

Under ~/Development/Personal the URL is rewritten to the github-personal
ssh host and the personal user.name/user.email are written into the new
repo's .git/config. Under ~/Development/Work nothing is changed.

The shell lands in the freshly cloned repo; --no-cd leaves it where it is.
EOF
}

# ---------------------------------------------------------------------------
# Which account does this directory belong to?
# ---------------------------------------------------------------------------

# _phys <path> — physical path of an existing dir, else the path as given
# (realpath is not on older macOS; a non-existent root still gets compared).
_phys() {
  if [[ -d "$1" ]]; then (cd "$1" && pwd -P); else printf '%s' "$1"; fi
}

# detect_account -> personal | work | unknown
#
# $PWD and both roots are canonicalized before comparing so a symlinked
# ~/Development (or a path reached through one) still resolves correctly.
detect_account() {
  local cwd personal work
  cwd="$(pwd -P)"
  personal="$(_phys "$PERSONAL_ROOT")"
  work="$(_phys "$WORK_ROOT")"

  # Personal is checked first: if one root sits inside the other, the more
  # specific match should win over the enclosing one.
  case "$cwd" in
    "$personal"|"$personal"/*) printf 'personal'; return 0 ;;
  esac
  case "$cwd" in
    "$work"|"$work"/*) printf 'work'; return 0 ;;
  esac
  printf 'unknown'
}

# ---------------------------------------------------------------------------
# URL parsing — sets REPO_HOST / REPO_PATH, returns 1 on anything unparseable
# ---------------------------------------------------------------------------
REPO_HOST=""
REPO_PATH=""

parse_repo() {
  local url="$1" rest
  REPO_HOST=""
  REPO_PATH=""

  case "$url" in
    ssh://*|https://*|http://*|git://*)
      rest="${url#*://}"
      rest="${rest#*@}"            # drop user@ / token@
      REPO_HOST="${rest%%/*}"
      REPO_HOST="${REPO_HOST%%:*}" # drop :port
      REPO_PATH="${rest#*/}"
      ;;
    *@*:*)                         # scp-like  user@host:owner/repo.git
      rest="${url#*@}"
      REPO_HOST="${rest%%:*}"
      REPO_PATH="${rest#*:}"
      ;;
    */*)
      # owner/repo shorthand. Reject anything that is really a local path
      # (./src, ../x, /abs, ~/x, an existing directory) or a deeper path —
      # those go to git untouched rather than becoming a GitHub URL.
      [[ "$url" == *:* ]] && return 1
      [[ -e "$url" ]] && return 1
      case "$url" in
        .*|~*|/*|*/*/*|*/) return 1 ;;
      esac
      REPO_HOST="-shorthand-"
      REPO_PATH="$url"
      ;;
    *)
      return 1
      ;;
  esac

  REPO_HOST="${REPO_HOST#www.}"
  REPO_PATH="${REPO_PATH#/}"
  REPO_PATH="${REPO_PATH%/}"
  [[ -n "$REPO_PATH" ]] || return 1
}

# A host we know how to re-key. Anything else is somebody else's forge.
is_github_host() {
  case "$1" in
    github.com|"$PERSONAL_HOST"|"$WORK_HOST"|-shorthand-) return 0 ;;
    *) return 1 ;;
  esac
}

# looks_like_repo <token> — used to find the repo argument among git's flags.
looks_like_repo() {
  case "$1" in
    -*) return 1 ;;
    *://*|*@*:*) return 0 ;;
    */*) [[ "$1" != *:* ]] ;;
    *) return 1 ;;
  esac
}

# git clone options that take their value as a SEPARATE argument. Their value
# can look just like a repo ("-b feature/x"), so it has to be skipped while
# hunting for the repo argument. The --opt=value forms need no entry.
takes_value() {
  case "$1" in
    -b|--branch|-o|--origin|-u|--upload-pack|-c|--config|-j|--jobs|\
    --depth|--reference|--reference-if-able|--separate-git-dir|--template|\
    --shallow-since|--shallow-exclude|--filter|--server-option|--bundle-uri|\
    --revision|--ref-format|--recurse-submodules|--recurse|--single-branch-at)
      return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Where will the clone land? (so the caller can be moved into it)
# ---------------------------------------------------------------------------

# find_dest_arg <start-index> — print the explicit [dest] argument if there is
# one. Reads main's $args; flags and their separate values are skipped the same
# way the repo argument is found. Returns 1 when the user gave no dest.
find_dest_arg() {
  local i="$1" skip_next=0 arg
  while [[ $i -lt ${#args[@]} ]]; do
    arg="${args[$i]}"
    if [[ $skip_next -eq 1 ]]; then
      skip_next=0
    elif takes_value "$arg"; then
      skip_next=1
    elif [[ "$arg" != -* ]]; then
      printf '%s' "$arg"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

# default_dest <url> — the directory git would create for <url> on its own:
# the last path component with any trailing .git removed.
default_dest() {
  local base="$1"
  base="${base%/}"
  base="${base%/.git}"
  base="${base##*/}"   # https://host/owner/repo.git, git@host:owner/repo.git
  base="${base##*:}"   # git@host:repo.git (no slash at all)
  base="${base%.git}"
  printf '%s' "$base"
}

# A bare/mirror clone keeps the .git suffix on the directory it creates.
is_bare_clone() {
  local arg
  for arg in ${args[@]+"${args[@]}"}; do
    case "$arg" in
      --bare|--mirror) return 0 ;;
    esac
  done
  return 1
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  local dry_run=0 no_cd=0
  local args=() arg
  local url="" url_index=-1

  # Pass 1: peel off our own flags, keep everything else for git.
  for arg in "$@"; do
    case "$arg" in
      -h|--help) usage; return 0 ;;
      --dry-run) dry_run=1 ;;
      --no-cd) no_cd=1 ;;
      *) args[${#args[@]}]="$arg" ;;
    esac
  done

  [[ ${#args[@]} -gt 0 ]] || { usage >&2; return 1; }

  # Pass 2: find the repo argument, skipping flags and their values.
  local i=0 skip_next=0
  while [[ $i -lt ${#args[@]} ]]; do
    arg="${args[$i]}"
    if [[ $skip_next -eq 1 ]]; then
      skip_next=0
    elif takes_value "$arg"; then
      skip_next=1
    elif looks_like_repo "$arg"; then
      url="$arg"
      url_index=$i
      break
    fi
    i=$((i + 1))
  done

  [[ -n "$url" ]] || die "no repository argument found in: $*"

  local account
  account="$(detect_account)"

  local target_host="" rewritten="$url"
  if parse_repo "$url" && is_github_host "$REPO_HOST"; then
    case "$REPO_PATH" in
      */*/*) die "expected owner/repo, got: $REPO_PATH" ;;
    esac
    [[ "$REPO_PATH" == *.git ]] || REPO_PATH="$REPO_PATH.git"

    case "$account" in
      personal) target_host="$PERSONAL_HOST" ;;
      work)     target_host="$WORK_HOST" ;;
      unknown)
        target_host="$WORK_HOST"
        warn "$(pwd -P) is under neither $PERSONAL_ROOT nor $WORK_ROOT"
        warn "using the work host ($WORK_HOST) — cd into one of them for the other account"
        ;;
    esac
    rewritten="git@$target_host:$REPO_PATH"
  else
    warn "not a recognized GitHub URL — handing it to git unchanged: $url"
  fi

  args[$url_index]="$rewritten"

  # `git clone -c k=v` writes k=v into the NEW repo's .git/config, so the
  # identity lands there without this script needing to know (or guess) the
  # destination directory git chose.
  local cmd=(git clone)
  if [[ "$account" == "personal" && -n "$target_host" ]]; then
    cmd[${#cmd[@]}]="-c"
    cmd[${#cmd[@]}]="user.name=$PERSONAL_NAME"
    cmd[${#cmd[@]}]="-c"
    cmd[${#cmd[@]}]="user.email=$PERSONAL_EMAIL"
  fi
  for arg in ${args[@]+"${args[@]}"}; do
    cmd[${#cmd[@]}]="$arg"
  done

  if [[ -n "$target_host" ]]; then
    info "$account → $rewritten"
    [[ "$account" == "personal" ]] &&
      info "committing as $PERSONAL_NAME <$PERSONAL_EMAIL>"
  fi

  if [[ $dry_run -eq 1 ]]; then
    # %q so a destination with spaces is visibly one argument.
    printf '%q ' "${cmd[@]}"
    printf '\n'
    return 0
  fi

  local status=0
  "${cmd[@]}" || status=$?
  if [[ $status -ne 0 ]]; then
    if [[ -n "$target_host" ]]; then
      warn "clone failed — check that ~/.ssh/config has a 'Host $target_host' entry"
      warn "and that its IdentityFile key is added to the right GitHub account"
    fi
    return $status
  fi

  # Where did it land? The explicit [dest] if given, else git's own default.
  local dest landed=""
  dest="$(find_dest_arg $((url_index + 1)) || true)"
  if [[ -z "$dest" ]]; then
    dest="$(default_dest "$rewritten")"
    is_bare_clone && dest="$dest.git"
  fi
  [[ -n "$dest" && -d "$dest" ]] && landed="$(cd "$dest" && pwd -P)"

  if [[ -n "$landed" ]]; then
    info "cloned into $landed"
    # This process cannot cd the shell that called it; the gclone shell
    # function reads the path back out of this file and cds there for us.
    if [[ $no_cd -eq 0 && -n "${GCLONE_CD_FILE:-}" ]]; then
      printf '%s\n' "$landed" > "$GCLONE_CD_FILE"
    fi
  fi
  return 0
}

main "$@"
