#!/usr/bin/env bash
# uv-setup.sh — make sure uv is on this machine.
#
#   uv-setup.sh           check, and install uv if it is missing
#   uv-setup.sh --check    check only; exits 1 when uv is missing
#
# Git Bash on Windows prints the PowerShell command instead of running it: the
# installer there is PowerShell-only, and PATH needs a fresh shell anyway.
set -euo pipefail

usage() { sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

CHECK_ONLY=0
case "${1:-}" in
  --check|-c)   CHECK_ONLY=1 ;;
  -h|--help)    usage ;;
  "")           ;;
  *)            echo "unknown flag: $1" >&2; usage 1 >&2 ;;
esac

if command -v uv >/dev/null 2>&1; then
  echo "uv $(uv --version 2>/dev/null | awk '{print $2}') — $(command -v uv)"
  exit 0
fi

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  echo "uv is not installed" >&2
  exit 1
fi

echo "uv is not installed; installing it now."
case "$(uname -s)" in
  Darwin*)
    if command -v brew >/dev/null 2>&1; then
      brew install uv
    else
      curl -LsSf https://astral.sh/uv/install.sh | sh
    fi
    ;;
  Linux*)
    curl -LsSf https://astral.sh/uv/install.sh | sh
    ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "run this in PowerShell, then reopen Git Bash:" >&2
    echo '  powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"' >&2
    exit 1
    ;;
  *)
    echo "unknown platform $(uname -s); see https://docs.astral.sh/uv/" >&2
    exit 1
    ;;
esac

# The standalone installer drops uv in ~/.local/bin, which this shell may not
# have on PATH yet -- so say where it landed rather than claim failure.
if command -v uv >/dev/null 2>&1; then
  echo "uv $(uv --version 2>/dev/null | awk '{print $2}') installed — $(command -v uv)"
elif [[ -x "$HOME/.local/bin/uv" ]]; then
  echo "installed to ~/.local/bin/uv — add that to PATH or open a new shell."
else
  echo "install finished but uv is still not on PATH; see https://docs.astral.sh/uv/" >&2
  exit 1
fi
