#!/usr/bin/env bash
# ts-summary-init.sh — put the QA terminal summary into a Playwright+TS repo.
#
#   ts-summary-init.sh [REPO]   REPO defaults to the current directory
#
# Writes src/utils/qaReporter.ts -- the live log and the spec table, as a
# Playwright reporter -- and points playwright.config.ts at it. --force
# replaces the reporter.
set -euo pipefail

usage() { sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE=0
REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force|-f) FORCE=1 ;;
    -h|--help)  usage ;;
    -*)         echo "unknown flag: $1" >&2; usage 1 >&2 ;;
    *)          REPO="$1" ;;
  esac
  shift
done

REPO="$(cd "${REPO:-$PWD}" && pwd)"
CONFIG="$REPO/playwright.config.ts"
REPORTER="src/utils/qaReporter.ts"

mkdir -p "$REPO/src/utils"
if [[ -e "$REPO/$REPORTER" && "$FORCE" -eq 0 ]]; then
  echo "$REPORTER already exists (use --force to replace it)" >&2
  exit 1
fi
cp "$HERE/assets/qa-reporter.ts" "$REPO/$REPORTER"
echo "wrote $REPORTER"

# Unlike pytest's conftest.py, nothing loads a reporter by being in the right
# place: playwright.config.ts has to name it. The kit's own config says
# `reporter: 'list'`, which is the line to replace; any other config is the
# suite's own and is only told what to add.
say_by_hand() {
  echo
  echo "add the reporter to $1 by hand:"
  echo "  reporter: './$REPORTER',"
  echo "(or keep another one alongside it: reporter: [['./$REPORTER'], ['html']])"
}

if [[ ! -e "$CONFIG" ]]; then
  echo "note: no playwright.config.ts — run ts-runner-init.sh first" >&2
  say_by_hand playwright.config.ts
  exit 0
fi

if grep -q "$REPORTER" "$CONFIG"; then
  echo "playwright.config.ts already names the reporter — left as it is"
elif grep -qE "^[[:space:]]*reporter:[[:space:]]*'list',?[[:space:]]*$" "$CONFIG"; then
  # [[:space:]] rather than \s: BSD sed (macOS) does not know \s. A temp file
  # and mv, so a failed sed cannot leave the config half-written.
  sed -E "s|^([[:space:]]*)reporter:[[:space:]]*'list',?[[:space:]]*$|\1reporter: './$REPORTER',|" \
    "$CONFIG" > "$CONFIG.tmp"
  mv "$CONFIG.tmp" "$CONFIG"
  grep -q "$REPORTER" "$CONFIG" || { echo "error: could not rewrite the reporter line in $CONFIG" >&2; say_by_hand playwright.config.ts; exit 1; }
  echo "pointed playwright.config.ts at $REPORTER"
elif grep -qE "^[[:space:]]*reporter:" "$CONFIG"; then
  echo "playwright.config.ts already sets a reporter of its own:" >&2
  grep -nE "^[[:space:]]*reporter:" "$CONFIG" | sed 's/^/  /' >&2
  say_by_hand playwright.config.ts
  exit 1
else
  say_by_hand playwright.config.ts
  exit 1
fi

echo
echo "next: run the suite — each spec prints its table, and the run closes with one row per spec"
