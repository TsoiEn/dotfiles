#!/usr/bin/env bash
# runner.sh — one way into the suite: scripts/runner.sh [flags] [NAME|PATH] [-- <pytest args>]
#
#   --setup            uv sync, then install the chromium browser
#   --env NAME, -e     run against local | dev | staging (default: .env TEST_ENV)
#   --local|--dev|--staging   the same, spelled shorter
#   --headed           show the browser
#   --no-video         stop recording (video is on by default)
#   --retries N        re-run each failing test up to N times (pytest-rerunfailures)
#   -n N|auto          split the run over N parallel workers (pytest-xdist)
#   --collect          list what would run, run nothing
#   --loop N, -l N     run the selection N times, each a fresh pytest session
#   -v                 verbose pytest output
#   --test NAME, -t    one test file by short name ("sign-in" -> tests/test_sign_in.py)
#   NAME|PATH          a test file by short name, a path, or else a -k keyword
#   -- ARGS            everything after -- goes to pytest untouched
#
# A trace is kept for every failing test unless you pass your own --tracing.
# --retries and -n need their plugins:
#   uv add --dev pytest-rerunfailures pytest-xdist
set -euo pipefail

case "$(uname -s)" in
  Darwin*)               OS="mac" ;;
  Linux*)                OS="linux" ;;
  MINGW*|MSYS*|CYGWIN*)  OS="windows" ;;
  *)                     OS="unknown" ;;
esac

# Avoid cp1252 encoding errors in Python on Windows consoles.
[[ "$OS" == "windows" ]] && export PYTHONUTF8=1

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() { sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

# Short name -> test file, returned in RESOLVED_TEST. "sign-in", "sign_in" and
# "test_sign_in" all resolve to tests/test_sign_in.py; without this a bare word
# reaches pytest as a path and fails with "file or directory not found".
# Returns 1 without printing when there is no such file, so a caller can fall
# back to matching the word as a keyword instead.
RESOLVED_TEST=""
find_test_file() {
  local name="${1//-/_}"
  name="${name%.py}"
  name="${name#test_}"
  [[ -f "tests/test_${name}.py" ]] || return 1
  RESOLVED_TEST="tests/test_${name}.py"
}

# The strict form, used by --test: one file or nothing. Exits 1 on an unknown
# name, listing the names that do exist, rather than widening the run to
# whatever the word happens to resemble -- that is what a bare word is for.
resolve_test() {
  if ! find_test_file "$1"; then
    echo "error: no test file for '$1' (looked for tests/test_${1//-/_}.py)" >&2
    echo "available names:" >&2
    local file
    for file in tests/test_*.py; do
      [[ -f "$file" ]] || continue
      file="${file##*/test_}"
      echo "  ${file%.py}" >&2
    done
    exit 1
  fi
}

# The environment names utils.config accepts in TEST_ENV. Names only: each
# environment's address is read from its prefixed BASE_URL in .env (gitignored),
# so no URL is committed here or printed by this script.
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
  RETRIES="$1"
}

SETUP=0
NO_VIDEO=0
LOOP=1
RETRIES=0
PYTEST_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env|-e)
      [[ $# -ge 2 ]] || { echo "error: $1 needs an environment name (${KNOWN_ENVS[*]})" >&2; exit 1; }
      resolve_env "$2"; shift ;;
    --local|--dev|--staging) resolve_env "${1#--}" ;;
    --setup)    SETUP=1 ;;
    --headed)   PYTEST_ARGS+=(--headed) ;;
    --collect)  PYTEST_ARGS+=(--collect-only -q) ;;
    --no-video) NO_VIDEO=1 ;;
    -v)         PYTEST_ARGS+=(-v) ;;
    --retries=*) resolve_retries "${1#*=}" ;;
    --retries)
      [[ $# -ge 2 ]] || { echo "error: --retries needs a count (e.g. --retries 2)" >&2; exit 1; }
      resolve_retries "$2"; shift ;;
    -n|--numprocesses)
      [[ $# -ge 2 ]] || { echo "error: $1 needs a worker count (e.g. $1 auto)" >&2; exit 1; }
      PYTEST_ARGS+=(-n "$2"); shift ;;
    --loop=*|-l=*) resolve_loop "${1#*=}" ;;
    --loop|-l)
      [[ $# -ge 2 ]] || { echo "error: $1 needs a count (e.g. $1 5)" >&2; exit 1; }
      resolve_loop "$2"; shift ;;
    --test|-t)
      [[ $# -ge 2 ]] || { echo "error: $1 needs a test name (e.g. $1 sign-in)" >&2; exit 1; }
      resolve_test "$2"
      PYTEST_ARGS+=("$RESOLVED_TEST"); shift ;;
    --)         shift; PYTEST_ARGS+=("$@"); break ;;
    -h|--help)  usage ;;
    -*)         PYTEST_ARGS+=("$1") ;;
    *)
      # An existing path (or node id) goes straight through. A bare word is a
      # short test name when there is a file by that name -- which keeps
      # collection to that one file -- and a pytest -k keyword otherwise.
      if [[ -e "$1" || -e "${1%%::*}" ]]; then
        PYTEST_ARGS+=("$1")
      elif find_test_file "$1"; then
        PYTEST_ARGS+=("$RESOLVED_TEST")
      else
        PYTEST_ARGS+=(-k "$1")
      fi ;;
  esac
  shift
done

# Video is switched on in pyproject.toml, so it needs no flag; --no-video turns
# it off. A --video of their own anywhere in the arguments wins, so
# `-- --video=on` still records the passing cases too: pytest reads addopts
# first and the command line after it, and the last --video applies.
VIDEO_SET_BY_USER=0
TRACE_SET_BY_USER=0
for arg in "${PYTEST_ARGS[@]+"${PYTEST_ARGS[@]}"}"; do
  [[ "$arg" == --video || "$arg" == --video=* ]] && VIDEO_SET_BY_USER=1
  [[ "$arg" == --tracing || "$arg" == --tracing=* ]] && TRACE_SET_BY_USER=1
done

if [[ "$NO_VIDEO" -eq 1 && "$VIDEO_SET_BY_USER" -eq 0 ]]; then
  PYTEST_ARGS+=(--video=off)
fi

# A trace is what tells you why a case failed -- the DOM, network and console at
# every step -- so it is on for failures without anyone asking, like video.
if [[ "$TRACE_SET_BY_USER" -eq 0 ]]; then
  PYTEST_ARGS+=(--tracing=retain-on-failure)
fi

# The delay gives a slow backend a moment to settle: an immediate re-run of a
# timeout usually times out again.
if [[ "$RETRIES" -gt 0 ]]; then
  PYTEST_ARGS+=(--reruns "$RETRIES" --reruns-delay 1)
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "error: uv is not installed (https://docs.astral.sh/uv/)" >&2
  case "$OS" in
    mac)     echo "  install: brew install uv  (or: curl -LsSf https://astral.sh/uv/install.sh | sh)" >&2 ;;
    linux)   echo "  install: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2 ;;
    windows) echo "  install (PowerShell): powershell -ExecutionPolicy ByPass -c \"irm https://astral.sh/uv/install.ps1 | iex\"" >&2
             echo "  then restart Git Bash so uv is on your PATH." >&2 ;;
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
# plain run. load_dotenv does not override real environment variables, so this
# wins.
if [[ -n "$TEST_ENV_NAME" ]]; then
  export TEST_ENV="$TEST_ENV_NAME"
  echo "Environment: $TEST_ENV" >&2
else
  echo "Environment: from .env TEST_ENV" >&2
fi

# Said out loud because video is on without anyone asking for it. Silent when
# the user set --video themselves (the banner would be guessing) or when
# nothing is going to run.
if [[ "$VIDEO_SET_BY_USER" -eq 0 ]] && ! printf '%s\n' "${PYTEST_ARGS[@]+"${PYTEST_ARGS[@]}"}" | grep -qx -- '--collect-only'; then
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
  uv sync
  uv run playwright install chromium
fi

# Each round is a separate pytest session, so fixtures, logins and test data are
# built fresh -- which is the point of looping one case. The rounds all run even
# after a failure, and artifacts/ is emptied by every session, so only the last
# round leaves evidence behind.
if [[ "$LOOP" -gt 1 ]]; then
  FAILED=()
  for ((round = 1; round <= LOOP; round++)); do
    echo "Round $round/$LOOP" >&2
    uv run pytest "${PYTEST_ARGS[@]+"${PYTEST_ARGS[@]}"}" || FAILED+=("$round")
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
  uv run pytest "${PYTEST_ARGS[@]+"${PYTEST_ARGS[@]}"}"
  exit $?
fi

exec uv run pytest "${PYTEST_ARGS[@]+"${PYTEST_ARGS[@]}"}"
