#!/usr/bin/env bash
# runner-init.sh — put scripts/runner.sh into a Playwright+pytest repo.
#
#   runner-init.sh [REPO]     REPO defaults to the current directory
#
# Writes scripts/runner.sh, and a .env.example stub when the repo has neither
# that nor a .env (runner.sh refuses to run without one). Never overwrites an
# existing file; run with --force to replace runner.sh only.
set -euo pipefail

usage() { sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

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
[[ -f "$REPO/pyproject.toml" ]] || echo "note: $REPO has no pyproject.toml — runner.sh needs one for 'uv run'." >&2

mkdir -p "$REPO/scripts"
if [[ -e "$REPO/scripts/runner.sh" && "$FORCE" -eq 0 ]]; then
  echo "scripts/runner.sh already exists (use --force to replace it)" >&2
  exit 1
fi
cp "$HERE/assets/runner.sh" "$REPO/scripts/runner.sh"
chmod +x "$REPO/scripts/runner.sh"
echo "wrote scripts/runner.sh"

if [[ ! -e "$REPO/.env.example" && ! -e "$REPO/.env" ]]; then
  cat > "$REPO/.env.example" <<'ENV'
# Copy to .env and fill in real values. .env must be gitignored; this file is
# committed, so never put real credentials or addresses here.

# Which environment the tests run against: local | dev | staging
TEST_ENV=staging

# Shared login, used by every environment unless the prefixed key below is set.
USER_EMAIL=
USER_PASSWORD=

# Each environment's address. No shared fallback and no default in source, so
# fill in the one you run against. staging is PW_STG_, matching the secret
# names DevOps issues.
LOCAL_BASE_URL=
DEV_BASE_URL=
PW_STG_BASE_URL=
ENV
  echo "wrote .env.example (stub)"
fi

echo
echo "next: ./scripts/runner.sh --setup && ./scripts/runner.sh --collect"
echo "for --retries and -n: uv add --dev pytest-rerunfailures pytest-xdist"
