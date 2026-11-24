#!/usr/bin/env bash
# ts-selftest.sh — prove the TypeScript kit installs into a fresh repo and works.
#
#   ts-selftest.sh    builds a throwaway repo in a temp dir and checks:
#                     runner.sh resolves a short spec name and the flags,
#                     and a real Playwright run prints the QA summary table.
#
# Needs npm and network on the first run. No browser is installed: the tests it
# writes assert on plain values, so nothing is launched.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ "${1:-}" != -h && "${1:-}" != --help ]] || { sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }

command -v npm >/dev/null 2>&1 || { echo "skipped: npm is not installed" >&2; exit 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tests" "$TMP/stub"

cat > "$TMP/package.json" <<'T'
{ "name": "qa-kit-ts-selftest", "version": "0.0.0", "private": true }
T

cat > "$TMP/tests/sign-in.spec.ts" <<'T'
import { expect, test } from '@playwright/test';

test('passes', () => {
  expect(1).toBe(1);
});

test('fails', () => {
  expect(1).toBe(2);
});

test.skip('skipped', () => {});

test('pending', () => {
  test.fail();
  expect(1).toBe(2);
});
T

"$HERE/ts-runner-init.sh" "$TMP" > /dev/null
"$HERE/ts-summary-init.sh" "$TMP" > /dev/null

fail() { echo "FAIL: $1" >&2; echo "$2" >&2; exit 1; }

for path in scripts/runner.sh playwright.config.ts src/utils/qaReporter.ts .env.example; do
  [[ -e "$TMP/$path" ]] || fail "$path was not created" ""
done
grep -q "qaReporter" "$TMP/playwright.config.ts" || fail "the config was not pointed at the reporter" ""

# runner.sh, with a stub npx that only reports what it was handed: this checks
# the name resolution and the flags without running a suite.
printf '#!/usr/bin/env bash\necho "PW-ARGS: $*"\n' > "$TMP/stub/npx"
chmod +x "$TMP/stub/npx"
cp "$TMP/.env.example" "$TMP/.env"

out="$(cd "$TMP" && PATH="$TMP/stub:$PATH" ./scripts/runner.sh sign-in --no-video --dev 2>&1)"
grep -q 'PW-ARGS: playwright test tests/sign-in.spec.ts --trace retain-on-failure' <<<"$out" \
  || fail "runner.sh did not resolve 'sign-in'" "$out"
grep -q 'Environment: dev' <<<"$out" || fail "runner.sh did not report the environment" "$out"
grep -q 'Video: off' <<<"$out" || fail "--no-video was not reported" "$out"

out="$(cd "$TMP" && PATH="$TMP/stub:$PATH" ./scripts/runner.sh sign_in 2>&1)"
grep -q 'PW-ARGS: playwright test tests/sign-in.spec.ts' <<<"$out" \
  || fail "an underscore should resolve to the same spec" "$out"

out="$(cd "$TMP" && PATH="$TMP/stub:$PATH" ./scripts/runner.sh nothing-like-this 2>&1)"
grep -q 'PW-ARGS: playwright test -g nothing-like-this' <<<"$out" \
  || fail "an unknown word should become a -g title match" "$out"

out="$(cd "$TMP" && PATH="$TMP/stub:$PATH" ./scripts/runner.sh --retries 2 -n auto 2>&1)"
grep -q 'PW-ARGS: playwright test --retries 2 --workers 100% --trace retain-on-failure' <<<"$out" \
  || fail "--retries / -n / the default trace did not reach playwright" "$out"

out="$(cd "$TMP" && PATH="$TMP/stub:$PATH" ./scripts/runner.sh -- --trace off 2>&1)"
grep -q 'PW-ARGS: playwright test --trace off$' <<<"$out" \
  || fail "a --trace of their own should win" "$out"

out="$(cd "$TMP" && PATH="$TMP/stub:$PATH" ./scripts/runner.sh --retries nope 2>&1 || true)"
grep -q "error: --retries needs a whole number" <<<"$out" \
  || fail "--retries should reject a non-number" "$out"

out="$(cd "$TMP" && PATH="$TMP/stub:$PATH" ./scripts/runner.sh --test nope 2>&1 || true)"
grep -q "error: no spec for 'nope'" <<<"$out" || fail "--test should reject an unknown name" "$out"

# The summary itself: a real Playwright session, no browser involved.
(cd "$TMP" && npm install --silent --no-audit --no-fund -D @playwright/test >/dev/null 2>&1) \
  || { echo "skipped: could not npm install @playwright/test (offline?)" >&2; exit 0; }

echo 'LOCAL_BASE_URL=http://localhost:3000' >> "$TMP/.env"
out="$(cd "$TMP" && TEST_ENV=local npx playwright test --workers 1 2>&1 || true)"
grep -q 'QA test summary' <<<"$out" || fail "no QA summary section" "$out"
grep -q 'Passing' <<<"$out" || fail "no table header" "$out"
grep -q 'passes: PASSED' <<<"$out" || fail "no live log line" "$out"
grep -q 'fails: FAILED' <<<"$out" || fail "a failure was not logged" "$out"
# No other reporter is left to say why, so this one has to.
grep -q 'Received' <<<"$out" || fail "a failure printed no reason" "$out"
grep -q 'skipped: SKIPPED' <<<"$out" || fail "a skip was not logged" "$out"
grep -q 'pending: PENDING' <<<"$out" || fail "a test.fail() was not logged as pending" "$out"
grep -q '1 of 1 failed (100%)' <<<"$out" || fail "no totals row" "$out"

# A selection that matches nothing, which no other reporter is left to report.
out="$(cd "$TMP" && TEST_ENV=local npx playwright test -g zzz-nothing 2>&1 || true)"
grep -q 'No tests ran' <<<"$out" || fail "an empty selection said nothing" "$out"

# A retried case: the attempt that was superseded must not be counted, or the
# case shows up twice.
cat > "$TMP/tests/flaky.spec.ts" <<'T'
import { expect, test } from '@playwright/test';

test('settles on the second try', () => {
  expect(test.info().retry).toBeGreaterThan(0);
});
T
out="$(cd "$TMP" && TEST_ENV=local npx playwright test flaky --retries 1 2>&1 || true)"
grep -q 'RETRYING' <<<"$out" || fail "a superseded attempt was not reported" "$out"
grep -q 'PASSED (flaky)' <<<"$out" || fail "a retried case did not settle as passed" "$out"
grep -q '1 of 1 passed (100%)' <<<"$out" || fail "a retried case was counted twice" "$out"

echo "ok — runner.sh and the QA summary both work in a fresh TypeScript repo"
