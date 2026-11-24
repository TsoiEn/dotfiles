#!/usr/bin/env bash
# summary-init.sh — put the QA terminal summary into a Playwright+pytest repo.
#
#   summary-init.sh [REPO]    REPO defaults to the current directory
#
# Writes src/utils/terminal_summary.py (the table) and the pytest hooks that
# drive it -- the render function, the live log and the closing table -- into
# the repo's root conftest.py, creating it when there is none and appending
# when there is. --force replaces terminal_summary.py.
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
CONFTEST="$REPO/conftest.py"

mkdir -p "$REPO/src/utils"
if [[ -e "$REPO/src/utils/terminal_summary.py" && "$FORCE" -eq 0 ]]; then
  echo "src/utils/terminal_summary.py already exists (use --force to replace it)" >&2
  exit 1
fi
cp "$HERE/assets/terminal_summary.py" "$REPO/src/utils/terminal_summary.py"
echo "wrote src/utils/terminal_summary.py"

# A package, so `from utils import terminal_summary` works whether or not src/
# is installed as one.
[[ -e "$REPO/src/utils/__init__.py" ]] || { : > "$REPO/src/utils/__init__.py"; echo "wrote src/utils/__init__.py"; }

# The hooks go in the *root* conftest.py: pytest loads it for every run, and a
# suite's own tests/conftest.py is left alone. Appending is safe because pytest
# calls every implementation of a hook -- but not if this file already defines
# one of the same five by hand, which is a merge no script should guess at.
if [[ -e "$CONFTEST" ]]; then
  if grep -q 'terminal_summary' "$CONFTEST"; then
    echo "conftest.py already wires terminal_summary — left as it is"
    exit 0
  fi
  CLASH="$(grep -oE '^(def|async def) (pytest_sessionstart|pytest_runtest_logreport|pytest_report_teststatus|pytest_terminal_summary|_render_table)' "$CONFTEST" || true)"
  if [[ -n "$CLASH" ]]; then
    echo "error: $CONFTEST already defines:" >&2
    printf '%s\n' "$CLASH" | sed 's/^/  /' >&2
    echo "merge the block by hand, from:" >&2
    echo "  $HERE/assets/conftest_summary.py" >&2
    exit 1
  fi
  printf '\n\n' >> "$CONFTEST"
  cat "$HERE/assets/conftest_summary.py" >> "$CONFTEST"
  echo "appended the hooks to conftest.py (its imports now sit mid-file — move them up if you lint)"
else
  cat "$HERE/assets/conftest_summary.py" > "$CONFTEST"
  echo "wrote conftest.py"
fi

echo
echo "next: run the suite — each spec prints its table, and the run closes with one row per spec"
