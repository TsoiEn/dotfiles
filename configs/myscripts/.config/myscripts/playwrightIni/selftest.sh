#!/usr/bin/env bash
# selftest.sh — prove the kit still installs into a fresh repo and works.
#
#   selftest.sh      builds a throwaway repo in a temp dir and checks:
#                    runner.sh resolves a short test name and the flags,
#                    and a real pytest run prints the QA summary table.
#
# Needs uv (for the ephemeral pytest) and network on the first run.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ "${1:-}" != -h && "${1:-}" != --help ]] || { sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }

command -v uv >/dev/null 2>&1 || { echo "skipped: uv is not installed (run ./uv-setup.sh)" >&2; exit 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tests" "$TMP/stub"

cat > "$TMP/pyproject.toml" <<'T'
[project]
name = "qa-kit-selftest"
version = "0"
requires-python = ">=3.10"

[tool.pytest.ini_options]
testpaths = ["tests"]
T

cat > "$TMP/tests/test_sign_in.py" <<'T'
import pytest


def test_passes():
    assert True


def test_fails():
    assert False


@pytest.mark.skip(reason="selftest")
def test_skipped():
    pass


@pytest.mark.xfail(reason="selftest")
def test_pending():
    assert False
T

"$HERE/runner-init.sh" "$TMP" > /dev/null
"$HERE/summary-init.sh" "$TMP" > /dev/null

fail() { echo "FAIL: $1" >&2; echo "$2" >&2; exit 1; }

for path in scripts/runner.sh src/utils/terminal_summary.py conftest.py .env.example; do
  [[ -e "$TMP/$path" ]] || fail "$path was not created" ""
done

# runner.sh, with a stub uv that only reports what it was handed: this checks
# the name resolution and the flags without starting a browser.
printf '#!/usr/bin/env bash\necho "UV-ARGS: $*"\n' > "$TMP/stub/uv"
chmod +x "$TMP/stub/uv"
cp "$TMP/.env.example" "$TMP/.env"

out="$(cd "$TMP" && PATH="$TMP/stub:$PATH" ./scripts/runner.sh sign-in --no-video --dev 2>&1)"
grep -q 'UV-ARGS: run pytest tests/test_sign_in.py --video=off' <<<"$out" \
  || fail "runner.sh did not resolve 'sign-in' and --no-video" "$out"
grep -q 'Environment: dev' <<<"$out" || fail "runner.sh did not report the environment" "$out"

out="$(cd "$TMP" && PATH="$TMP/stub:$PATH" ./scripts/runner.sh nothing-like-this 2>&1)"
grep -q 'UV-ARGS: run pytest -k nothing-like-this' <<<"$out" \
  || fail "an unknown word should become a -k keyword" "$out"

# --retries and -n each take their value here, and a trace is kept for failures
# without being asked for.
out="$(cd "$TMP" && PATH="$TMP/stub:$PATH" ./scripts/runner.sh --retries 2 -n auto 2>&1)"
grep -q 'UV-ARGS: run pytest -n auto --tracing=retain-on-failure --reruns 2 --reruns-delay 1' <<<"$out" \
  || fail "--retries / -n / the default trace did not reach pytest" "$out"

out="$(cd "$TMP" && PATH="$TMP/stub:$PATH" ./scripts/runner.sh -- --tracing=off 2>&1)"
grep -q 'UV-ARGS: run pytest --tracing=off$' <<<"$out" \
  || fail "a --tracing of their own should win" "$out"

out="$(cd "$TMP" && PATH="$TMP/stub:$PATH" ./scripts/runner.sh --retries nope 2>&1 || true)"
grep -q "error: --retries needs a whole number" <<<"$out" \
  || fail "--retries should reject a non-number" "$out"

# The summary itself: a real pytest session, no Playwright involved.
out="$(cd "$TMP" && uv run --no-project --with pytest pytest 2>&1 || true)"
grep -q 'QA test summary' <<<"$out" || fail "no QA summary section" "$out"
grep -q 'Passing' <<<"$out" || fail "no table header" "$out"
grep -q 'test_passes: PASSED' <<<"$out" || fail "no live log line" "$out"
grep -q 'test_fails: FAILED' <<<"$out" || fail "a failure was not logged" "$out"

echo "ok — runner.sh and the QA summary both work in a fresh repo"
