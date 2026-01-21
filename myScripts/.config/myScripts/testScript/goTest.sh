#!/usr/bin/env bash

# gotest.sh
# A helper script to run Go tests with coverage in multiple modes.
# Usage:
#   ./gotest.sh [mode]
# Modes:
#   basic    - show normal go test output + coverage
#   verbose  - show detailed test logs + coverage summary
#   ci       - quiet, only shows pass/fail + coverage summary
#   total    - outputs total coverage only
# Example:
#   ./gotest.sh verbose

set -e

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# Functions for each mode
run_basic() {
    echo "🧪 Running Go tests (basic mode)..."
    go test ./... -coverprofile="$TMPFILE"
    echo
    go tool cover -func="$TMPFILE"
}

run_verbose() {
    echo "🧪 Running Go tests (verbose mode)..."
    if go test ./... -v -coverprofile="$TMPFILE"; then
        echo
        echo "✅ All tests passed."
    else
        echo
        echo "❌ Some tests failed."
    fi
    echo
    echo "📊 Coverage report:"
    go tool cover -func="$TMPFILE"
}

run_ci() {
    echo "🧪 Running Go tests (CI mode)..."
    if ! go test ./... -coverprofile="$TMPFILE" -covermode=atomic > /dev/null; then
        echo "❌ Tests failed. Check test output manually."
    else
        echo "✅ All tests passed."
    fi
    echo
    echo "📊 Coverage summary:"
    go tool cover -func="$TMPFILE"
}

run_total() {
    echo "🧪 Running Go tests (total coverage mode)..."
    go test ./... -coverprofile="$TMPFILE" -covermode=atomic > /dev/null
    TOTAL=$(go tool cover -func="$TMPFILE" | grep total | awk '{print $3}')
    echo "✅ Total coverage: $TOTAL"
}

# Interactive menu
show_menu() {
    echo "======================================"
    echo "     🧩 Go Test CLI — Coverage Tool"
    echo "======================================"
    echo "Select an option:"
    echo "1) Basic mode     — Normal test output + coverage"
    echo "2) Verbose mode   — Detailed test logs + coverage"
    echo "3) CI mode        — Quiet, pass/fail summary + coverage"
    echo "4) Total mode     — Show total coverage only"
    echo "5) Exit"
    echo "======================================"
    echo -n "Enter choice [1-5]: "
}

# Main flow
while true; do
    show_menu
    read -r choice
    echo

    case "$choice" in
        1) run_basic ;;
        2) run_verbose ;;
        3) run_ci ;;
        4) run_total ;;
        5)
            echo "Exiting Go Test CLI."
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Please enter a number between 1 and 5."
            ;;
    esac

    echo
    read -rp "Press Enter to continue..."
    clear
done
