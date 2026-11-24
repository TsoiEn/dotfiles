#!/usr/bin/env bash
# ts-runner-init.sh — put scripts/runner.sh into a Playwright+TypeScript repo.
#
#   ts-runner-init.sh [REPO]     REPO defaults to the current directory
#
# Writes scripts/runner.sh, plus a .env.example stub (runner.sh refuses to run
# without a .env) and a playwright.config.ts, each only when the repo has
# neither it nor its real counterpart. Never overwrites an existing file; run
# with --force to replace runner.sh only.
set -euo pipefail

usage() { sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

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
if [[ ! -f "$REPO/package.json" ]]; then
  echo "note: $REPO has no package.json — start the suite with" >&2
  echo "  npm init playwright@latest" >&2
  echo "then re-run this script to replace what it wrote with the kit's runner." >&2
fi

mkdir -p "$REPO/scripts"
if [[ -e "$REPO/scripts/runner.sh" && "$FORCE" -eq 0 ]]; then
  echo "scripts/runner.sh already exists (use --force to replace it)" >&2
  exit 1
fi
cp "$HERE/assets/runner-ts.sh" "$REPO/scripts/runner.sh"
chmod +x "$REPO/scripts/runner.sh"
echo "wrote scripts/runner.sh"

# The config is the other half of the runner: --no-video, the per-environment
# base URL and artifacts/ all live in it. Left alone when the repo has one,
# because that is where a suite keeps its own decisions.
if [[ -e "$REPO/playwright.config.ts" ]]; then
  echo "playwright.config.ts already exists — left as it is"
  echo "  for --no-video and --env to work, it needs what"
  echo "  $HERE/assets/playwright.config.ts does with PW_VIDEO and TEST_ENV"
else
  cp "$HERE/assets/playwright.config.ts" "$REPO/playwright.config.ts"
  echo "wrote playwright.config.ts"
fi

if [[ ! -e "$REPO/.env.example" && ! -e "$REPO/.env" ]]; then
  cat > "$REPO/.env.example" <<'ENV'
# Copy to .env and fill in real values. .env must be gitignored; this file is
# committed, so never put real credentials or addresses here.

# Which environment the tests run against: local | dev | staging
TEST_ENV=staging

# Shared login, used by every environment.
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
