#!/usr/bin/env bash
# runner.sh — one way into the suite: scripts/runner.sh [flags] [NAME|PATH] [-- <playwright args>]
#
#   --setup            npm install, then install the chromium browser
#   --env NAME, -e     run against local | dev | staging (default: .env TEST_ENV)
#   --local|--dev|--staging   the same, spelled shorter
#   --headed           show the browser
#   --no-video         stop recording (video is on by default)
#   --retries N        re-run each failing test up to N times
#   -n N|auto          split the run over N parallel workers (auto: every core)
#   --collect          list what would run, run nothing
#   --loop N, -l N     run the selection N times, each a fresh session
#   --test NAME, -t    one spec by short name ("sign-in" -> tests/sign-in.spec.ts)
#   NAME|PATH          a spec by short name, a path, or else a -g title match
#   -- ARGS            everything after -- goes to playwright untouched
#
# The flags are the Python kit's, so one suite reads like the other. Every case
# is printed as it settles, so there is no -v. A trace is kept for every
# failing test unless you pass your own --trace.
set -euo pipefail

case "$(uname -s)" in
  Darwin*)               OS="mac" ;;
  Linux*)                OS="linux" ;;
  MINGW*|MSYS*|CYGWIN*)  OS="windows" ;;
  *)                     OS="unknown" ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() { sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

# Short name -> spec file, returned in RESOLVED_TEST. "sign-in", "sign_in" and
# "sign-in.spec.ts" all resolve to tests/sign-in.spec.ts, wherever under tests/
# it lives. Returns 1 without printing when there is no such file, so a caller
# can fall back to matching the word against test titles instead.
RESOLVED_TEST=""
find_test_file() {
  local wanted="${1%.spec.ts}"
  wanted="${wanted%.ts}"
  wanted="${wanted//_/-}"
  local file base
  while IFS= read -r file; do
    base="${file##*/}"
    base="${base%.spec.ts}"
    if [[ "${base//_/-}" == "$wanted" ]]; then
      RESOLVED_TEST="$file"
      return 0
    fi
  done < <(find tests -name '*.spec.ts' -type f 2>/dev/null | sort)
  return 1
}

# The strict form, used by --test: one file or nothing. Exits 1 on an unknown
# name, listing the names that do exist, rather than widening the run to
# whatever the word happens to resemble -- that is what a bare word is for.
resolve_test() {
  if find_test_file "$1"; then
    return
  fi
  echo "error: no spec for '$1' (looked for tests/**/${1//_/-}.spec.ts)" >&2
  echo "available names:" >&2
  local file
  while IFS= read -r file; do
    file="${file##*/}"
    echo "  ${file%.spec.ts}" >&2
  done < <(find tests -name '*.spec.ts' -type f 2>/dev/null | sort)
  exit 1
}

# The environment names playwright.config.ts accepts in TEST_ENV. Names only:
# each environment's address is read from its prefixed BASE_URL in .env
# (gitignored), so no URL is committed here or printed by this script.
KNOWN_ENVS=(local dev staging)

# Validates a name and records it in TEST_ENV_NAME. Exits 1 on an unknown name
# rather than letting a typo quietly run against the default environment.
TEST_ENV_NAME=""
resolve_env() {
  local name known
  name="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  for known in "${KNOWN_ENVS[@]}"; do
    if [[ "$name" == "$known" ]]; then
      TEST_ENV_NAME="$name"
      return
    fi
  done
  echo "error: unknown environment '$1'" >&2
  echo "available environments: ${KNOWN_ENVS[*]}" >&2
  echo "each one's address comes from its prefixed BASE_URL in .env" >&2
  exit 1
}

# A loop count is only useful as a positive whole number; a typo would
# otherwise run once silently (or not at all).
resolve_loop() {
  if [[ ! "$1" =~ ^[0-9]+$ || "$1" -lt 1 ]]; then
    echo "error: --loop needs a positive whole number, got '$1'" >&2
    exit 1
  fi
  LOOP="$1"
}

# Non-negative, unlike --loop: `--retries 0` is a meaningful "off" when the
# count comes from a variable in CI.
resolve_retries() {
  if [[ ! "$1" =~ ^[0-9]+$ ]]; then
    echo "error: --retries needs a whole number, got '$1'" >&2
    exit 1
  fi
  PW_ARGS+=(--retries "$1")
  RETRIES="$1"
}

SETUP=0
NO_VIDEO=0
LOOP=1
RETRIES=0
PW_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env|-e)
      [[ $# -ge 2 ]] || { echo "error: $1 needs an environment name (${KNOWN_ENVS[*]})" >&2; exit 1; }
      resolve_env "$2"; shift ;;
    --local|--dev|--staging) resolve_env "${1#--}" ;;
    --setup)    SETUP=1 ;;
    --headed)   PW_ARGS+=(--headed) ;;
    --collect)  PW_ARGS+=(--list) ;;
    --no-video) NO_VIDEO=1 ;;
    --retries=*) resolve_retries "${1#*=}" ;;
    --retries)
      [[ $# -ge 2 ]] || { echo "error: --retries needs a count (e.g. --retries 2)" >&2; exit 1; }
      resolve_retries "$2"; shift ;;
    -n|--workers)
      [[ $# -ge 2 ]] || { echo "error: $1 needs a worker count (e.g. $1 auto)" >&2; exit 1; }
      # xdist spells "every core" as auto; Playwright spells it as a share of
      # them, and defaults to half.
      if [[ "$2" == "auto" ]]; then PW_ARGS+=(--workers "100%"); else PW_ARGS+=(--workers "$2"); fi
      shift ;;
    --loop=*|-l=*) resolve_loop "${1#*=}" ;;
    --loop|-l)
      [[ $# -ge 2 ]] || { echo "error: $1 needs a count (e.g. $1 5)" >&2; exit 1; }
      resolve_loop "$2"; shift ;;
    --test|-t)
      [[ $# -ge 2 ]] || { echo "error: $1 needs a spec name (e.g. $1 sign-in)" >&2; exit 1; }
      resolve_test "$2"
      PW_ARGS+=("$RESOLVED_TEST"); shift ;;
    --)         shift; PW_ARGS+=("$@"); break ;;
    -h|--help)  usage ;;
    -*)         PW_ARGS+=("$1") ;;
    *)
      # An existing path (or path:line) goes straight through. A bare word is a
      # short spec name when there is a file by that name -- which keeps
      # collection to that one file -- and a title match otherwise.
      if [[ -e "$1" || -e "${1%%:*}" ]]; then
        PW_ARGS+=("$1")
      elif find_test_file "$1"; then
        PW_ARGS+=("$RESOLVED_TEST")
      else
        PW_ARGS+=(-g "$1")
      fi ;;
  esac
  shift
done

# Video is switched on in playwright.config.ts, which reads PW_VIDEO; there is
# no --video on the Playwright command line, so --no-video goes through the
# environment. A --trace of their own anywhere in the arguments wins.
TRACE_SET_BY_USER=0
COLLECT_ONLY=0
for arg in "${PW_ARGS[@]+"${PW_ARGS[@]}"}"; do
  [[ "$arg" == --trace || "$arg" == --trace=* ]] && TRACE_SET_BY_USER=1
  [[ "$arg" == --list ]] && COLLECT_ONLY=1
done

[[ "$NO_VIDEO" -eq 1 ]] && export PW_VIDEO=off

# A trace is what tells you why a case failed -- the DOM, network and console at
# every step -- so it is on for failures without anyone asking, like video.
if [[ "$TRACE_SET_BY_USER" -eq 0 ]]; then
  PW_ARGS+=(--trace retain-on-failure)
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "error: npm is not installed (Node.js 18 or newer: https://nodejs.org/)" >&2
  case "$OS" in
    mac)     echo "  install: brew install node" >&2 ;;
    linux)   echo "  install: your package manager, or https://github.com/nvm-sh/nvm" >&2 ;;
    windows) echo "  install: winget install OpenJS.NodeJS, then restart Git Bash" >&2 ;;
  esac
  exit 1
fi

if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then
    cp .env.example .env
    echo "Created .env from .env.example — fill in real credentials, then re-run." >&2
  else
    echo "error: .env not found and no .env.example to copy from" >&2
  fi
  exit 1
fi

# Only exported when a flag asked for it, so TEST_ENV in .env still applies on a
# plain run. The config does not overwrite a real environment variable, so this
# wins.
if [[ -n "$TEST_ENV_NAME" ]]; then
  export TEST_ENV="$TEST_ENV_NAME"
  echo "Environment: $TEST_ENV" >&2
else
  echo "Environment: from .env TEST_ENV" >&2
fi

# Said out loud because video is on without anyone asking for it. Silent when
# nothing is going to run.
if [[ "$COLLECT_ONLY" -eq 0 ]]; then
  if [[ "$NO_VIDEO" -eq 1 ]]; then
    echo "Video: off (--no-video)" >&2
  else
    echo "Video: recording; kept for failing cases in artifacts/" >&2
  fi
  if [[ "$TRACE_SET_BY_USER" -eq 0 ]]; then
    echo "Trace: kept for failing cases in artifacts/" >&2
  fi
  if [[ "$RETRIES" -gt 0 ]]; then
    echo "Retries: up to $RETRIES per failing test" >&2
  fi
fi

if [[ "$SETUP" -eq 1 ]]; then
  npm install
  npx playwright install chromium
fi

# Each round is a separate session, so fixtures, logins and test data are built
# fresh -- which is the point of looping one case. The rounds all run even
# after a failure, and artifacts/ is emptied by every session, so only the last
# round leaves evidence behind.
if [[ "$LOOP" -gt 1 ]]; then
  FAILED=()
  for ((round = 1; round <= LOOP; round++)); do
    echo "Round $round/$LOOP" >&2
    npx playwright test "${PW_ARGS[@]+"${PW_ARGS[@]}"}" || FAILED+=("$round")
  done
  if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "Failed ${#FAILED[@]}/$LOOP rounds: ${FAILED[*]}" >&2
    exit 1
  fi
  echo "Passed all $LOOP rounds" >&2
  exit 0
fi

# exec is unreliable for exit codes under some Windows bash flavors; run
# normally there and exec elsewhere.
if [[ "$OS" == "windows" ]]; then
  npx playwright test "${PW_ARGS[@]+"${PW_ARGS[@]}"}"
  exit $?
fi

exec npx playwright test "${PW_ARGS[@]+"${PW_ARGS[@]}"}"
