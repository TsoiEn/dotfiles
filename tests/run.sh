#!/usr/bin/env bash
#
# tests/run.sh — sandboxed checks for the installer.
#
# Nothing here touches the real machine: every run gets its own
# HOME=$(mktemp -d), and `brew`/`pacman`/`sudo` are stubs on PATH that
# log their arguments instead of installing anything. The last check is a
# tripwire asserting the real $HOME was not modified.
#
# Usage: bash tests/run.sh        (exit 0 = all checks passed)

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_HOME="$HOME"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0

# check <description> <command...> — the command decides pass/fail.
check() {
  local desc="$1"
  shift
  if "$@"; then
    PASSED=$((PASSED + 1))
    printf '  ok   %s\n' "$desc"
  else
    FAILED=$((FAILED + 1))
    printf '  FAIL %s\n' "$desc"
  fi
}

# not <command...> — for `check` conditions that must NOT hold.
not() {
  ! "$@"
}

# ---------------------------------------------------------------------------
# Stubs — a fake package manager that records what it was asked to do.
# ---------------------------------------------------------------------------
STUB_BIN="$WORK/bin"
mkdir -p "$STUB_BIN"

cat >"$STUB_BIN/brew" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_LOG"
case "$1" in
  list) exit 0 ;; # nothing installed yet
  install)
    if [[ -n "${STUB_FAIL:-}" && "$*" == *"$STUB_FAIL"* ]]; then exit 1; fi
    ;;
esac
exit 0
STUB

cat >"$STUB_BIN/pacman" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_LOG"
case "$1" in
  -Qi) exit 1 ;; # nothing installed yet
esac
exit 0
STUB

cat >"$STUB_BIN/sudo" <<'STUB'
#!/usr/bin/env bash
exec "$@"
STUB

chmod +x "$STUB_BIN"/*

# sandbox <name> — fresh HOME + log/backup dirs, printed as one path.
sandbox() {
  local sb="$WORK/sandbox-$1"
  mkdir -p "$sb"
  printf '%s' "$sb"
}

# run_bootstrap <sandbox> [args...] — bootstrap.sh against a sandbox HOME
# with the stubs first on PATH. stdout+stderr land in <sandbox>/out.
run_bootstrap() {
  local sb="$1"
  shift
  HOME="$sb" \
    PATH="$STUB_BIN:$PATH" \
    LOG_DIR="$sb/logs" \
    BACKUP_DIR="$sb/backups" \
    STUB_LOG="$sb/stub.log" \
    bash "$REPO/bootstrap.sh" "$@" >"$sb/out" 2>&1
}

# run_packages <sandbox> <os> [name-that-fails]
run_packages() {
  local sb="$1" os="$2"
  HOME="$sb" PATH="$STUB_BIN:$PATH" LOG_DIR="$sb/logs" \
    STUB_LOG="$sb/stub.log" STUB_FAIL="${3:-}" \
    bash "$REPO/install/packages.sh" "$os" >"$sb/out" 2>&1
}

# link_dests — the $HOME-relative half of every LINK_MAP entry, read from
# the script itself so a new target is covered without editing this file.
link_dests() {
  grep -oE '"configs/[^"]+\|[^"]+"' "$REPO/scripts/setup-symlinks.sh" |
    tr -d '"' | sed 's/.*|//'
}

# count_backup_sessions <sandbox>
count_backup_sessions() {
  find "$1/backups" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l
}

# ---------------------------------------------------------------------------
echo "symlinks"
# ---------------------------------------------------------------------------
SB="$(sandbox links)"
printf 'KEEP ME\n' >"$SB/.zshrc" # pre-existing config: must be backed up
run_bootstrap "$SB" --only=setup-symlinks
rc=$?
check "exits 0" test "$rc" -eq 0

missing=0
outside=0
while IFS= read -r dest; do
  target="$SB/$dest"
  [[ -L "$target" ]] || missing=$((missing + 1))
  resolved="$(cd "$(dirname "$(readlink "$target")")" 2>/dev/null && pwd -P)"
  [[ "$resolved" == "$REPO"* ]] || outside=$((outside + 1))
done < <(link_dests)
check "every LINK_MAP target is a symlink" test "$missing" -eq 0
check "every LINK_MAP target resolves into the repo" test "$outside" -eq 0
check "pre-existing ~/.zshrc moved to backups, contents intact" \
  grep -rq 'KEEP ME' "$SB/backups"

before="$(count_backup_sessions "$SB")"
run_bootstrap "$SB" --only=setup-symlinks
rc=$?
check "re-run exits 0" test "$rc" -eq 0
check "re-run reports already linked" \
  grep -q 'already linked: .*\.zshrc' "$SB/out"
check "re-run creates no new backup session" \
  test "$before" -eq "$(count_backup_sessions "$SB")"

# ---------------------------------------------------------------------------
echo "flags"
# ---------------------------------------------------------------------------
SB="$(sandbox flags)"
run_bootstrap "$SB" --only=setup-symlinks
check "--only never reaches the package manager" test ! -s "$SB/stub.log"
check "--only implies --skip-packages" \
  grep -q 'Skipping package installation' "$SB/out"

run_bootstrap "$SB" --help
rc=$?
check "--help exits 0" test "$rc" -eq 0
run_bootstrap "$SB" --nope
rc=$?
check "an unknown flag exits 1" test "$rc" -eq 1

# ---------------------------------------------------------------------------
echo "packages"
# ---------------------------------------------------------------------------
SB="$(sandbox brew)"
run_packages "$SB" macos
rc=$?
check "macos exits 0" test "$rc" -eq 0

# Every name in common.txt + brew.txt must have reached the stub.
missing=0
while IFS= read -r line; do
  line="${line%%#*}"
  line="$(printf '%s' "$line" | tr -d '[:space:]')"
  [[ -n "$line" ]] || continue
  case "$line" in
    cask:*) want="install --cask ${line#cask:}" ;;
    *) want="install $line" ;;
  esac
  grep -qx -- "$want" "$SB/stub.log" || missing=$((missing + 1))
done < <(cat "$REPO/install/packages/common.txt" "$REPO/install/packages/brew.txt")
check "every brew.txt + common.txt name was installed" test "$missing" -eq 0
check "no cask: prefix is passed to brew as a formula" \
  not grep -q 'install cask:' "$SB/stub.log"
check "brew list runs twice, not once per package" \
  test "$(grep -c '^list ' "$SB/stub.log")" -eq 2

SB="$(sandbox pacman)"
run_packages "$SB" arch
rc=$?
check "arch exits 0" test "$rc" -eq 0
check "pacman database is synced first" \
  grep -q -- '-Sy --noconfirm' "$SB/stub.log"
check "a cask: line is never passed to pacman" \
  not grep -q 'cask:' "$SB/stub.log"
check "an arch-only name was installed" \
  grep -q -- '-S --needed --noconfirm ttf-nerd-fonts-symbols' "$SB/stub.log"

SB="$(sandbox failing)"
run_packages "$SB" macos fzf
rc=$?
check "a failing package still exits 0" test "$rc" -eq 0
check "the failure is reported" grep -q 'package(s) failed: fzf' "$SB/out"
# ---------------------------------------------------------------------------
echo "pkg"
# ---------------------------------------------------------------------------
# The stubs here answer queries instead of recording them, and -i is only
# ever driven without a tty below, so nothing can install: the checks stop
# at the command pkg would have run after confirmation.
# They are also the only way to exercise the Arch side (pacman, AUR,
# pacman -Qo) from a Mac and vice versa.
PKG_BIN="$WORK/pkgbin"
mkdir -p "$PKG_BIN" "$WORK/gopath/bin"

cat >"$PKG_BIN/pacman" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  -Qen) printf 'ripgrep 14.1.0\nfzf 0.56.3\n' ;;
  -Qm) printf 'paru 2.0.1\n' ;;
  -Qo) case "$2" in
    */rg) printf '%s is owned by ripgrep 14.1.0\n' "$2" ;;
    *) exit 1 ;;
  esac ;;
  -Ssq) case "$2" in
    '^neovim$') printf 'neovim\n' ;;
    *) exit 1 ;;
  esac ;;
  -Ss) case "$3" in
    neovim) printf 'extra/neovim-nightly 0.11.0-1\n    Nightly build\nextra/neovim 0.10.2-1\n    Fork of Vim\n' ;;
    fzf) printf 'extra/fzf 0.56.3-1\n    Command-line fuzzy finder\n' ;;
    *) exit 1 ;;
  esac ;;
esac
exit 0
STUB

cat >"$PKG_BIN/paru" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  -Ssqa) case "$2" in
    '^yay-bin$') printf 'yay-bin\n' ;;
    *) exit 1 ;;
  esac ;;
esac
exit 0
STUB

cat >"$PKG_BIN/go" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "env GOBIN") printf '\n' ;;
  "env GOPATH") printf '%s\n' "$STUB_GOPATH" ;;
  "version -m") printf '\tpath\tgithub.com/acme/mytool\n\tmod\tgithub.com/acme/mytool\tv1.2.3\n' ;;
esac
exit 0
STUB

# brew and npm only have to EXIST for -i to consider them: the command it
# would run is checked, never run. `info` failing keeps the candidate list
# to pacman where a check expects exactly that.
cat >"$PKG_BIN/brew" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  info) exit 1 ;;
esac
exit 0
STUB

cat >"$PKG_BIN/npm" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  view) exit 1 ;;
esac
exit 0
STUB

# Silent stubs: -i now asks every manager in parallel, so any real cargo,
# gem, flatpak, snap or pip on the host would make the suite hit the network.
for quiet in cargo gem flatpak snap pip3 pip pnpm; do
  printf '#!/bin/sh\nexit 0\n' >"$PKG_BIN/$quiet"
done

# The popup installs what it picked, so the picker check below runs a real
# install command: sudo has to be a stub too, and it must reach the stubs.
printf '#!/bin/sh\nexec "$@"\n' >"$PKG_BIN/sudo"

# Stands in for display-popup: no terminal, just the pick it was told to
# make, written to the choice file named in the env handed to the popup.
cat >"$PKG_BIN/tmux" <<'STUB'
#!/usr/bin/env bash
for arg in "$@"; do
  case "$arg" in
    PKG_CHOICE=*) choice="${arg#PKG_CHOICE=}" ;;
  esac
done
if [[ -n "${choice:-}" && -n "${STUB_PICK:-}" ]]; then
  printf '%b\n' "$STUB_PICK" >"$choice"
fi
exit 0
STUB

printf '#!/bin/sh\n' >"$PKG_BIN/rg"
printf '#!/bin/sh\n' >"$WORK/gopath/bin/mytool"
chmod +x "$PKG_BIN"/* "$WORK/gopath/bin/mytool"

# run_pkg [args...] — stubs first on a PATH that holds no real
# package manager, so the output depends on the stubs alone. TMUX is unset
# too: inside tmux pkg would reach for a display-popup, and these checks are
# about the terminal path it takes everywhere else.
run_pkg() {
  env -u TMUX PATH="$PKG_BIN:$WORK/gopath/bin:/usr/bin:/bin" STUB_GOPATH="$WORK/gopath" \
    NO_COLOR=1 bash "$REPO/configs/myscripts/.config/myscripts/pkg.sh" "$@" \
    >"$WORK/pkgout" 2>&1
}

# run_pkg_popup <pick> [args...] — the same, inside tmux, with the popup
# standing in for a real one and handing back <pick> ('' for a cancel).
run_pkg_popup() {
  local pick="$1"
  shift
  TMUX=fake STUB_PICK="$pick" \
    PATH="$PKG_BIN:$WORK/gopath/bin:/usr/bin:/bin" STUB_GOPATH="$WORK/gopath" \
    NO_COLOR=1 bash "$REPO/configs/myscripts/.config/myscripts/pkg.sh" "$@" \
    >"$WORK/pkgout" 2>&1
}

run_pkg fzf
check "an exactly-matching pacman package is found" grep -qE '^pacman +fzf +0\.56\.3' "$WORK/pkgout"

run_pkg paru
check "a foreign package is reported as aur, not pacman" grep -qE '^aur +paru' "$WORK/pkgout"

run_pkg rg
check "a binary whose package has another name is traced via pacman -Qo" \
  grep -q 'pacman package: ripgrep' "$WORK/pkgout"
check "that trace is not mistaken for an aur build" not grep -q 'aur package' "$WORK/pkgout"

run_pkg mytool
check "a GOBIN binary is attributed to go install, with its module" \
  grep -q 'go install: github.com/acme/mytool' "$WORK/pkgout"
check "its go version shows in the package table" grep -qE '^go +mytool +v1\.2\.3' "$WORK/pkgout"

run_pkg zzzz-no-such-thing
rc=$?
check "an unknown name exits 1" test "$rc" -eq 1

run_pkg ripg
check "a substring falls back with a warning" grep -q 'no exact match' "$WORK/pkgout"
check "the substring match itself is shown" grep -qE '^pacman +ripgrep' "$WORK/pkgout"

run_pkg -l pacman
check "-l lists one manager's packages" grep -q 'ripgrep' "$WORK/pkgout"
check "-l with one manager leaves the others out" not grep -q 'paru' "$WORK/pkgout"

run_pkg -l nosuchmanager
rc=$?
check "-l with an unknown manager exits 1" test "$rc" -eq 1

run_pkg -i fzf
rc=$?
check "-i on something already installed stops, and says where" \
  grep -q 'fzf is already installed with pacman (0.56.3)' "$WORK/pkgout"
check "-i on something already installed exits 0" test "$rc" -eq 0

run_pkg -i neovim
check "-i finds the manager that carries it and shows the exact command" \
  grep -q 'sudo pacman -S --needed neovim' "$WORK/pkgout"
check "-i never installs without a confirmation" \
  grep -q 'no terminal to confirm on' "$WORK/pkgout"

check "-i offers every search hit, not just the exact name" \
  grep -q 'neovim-nightly' "$WORK/pkgout"
check "the exact name is the first candidate" \
  grep -qE '^  1\) pacman .*--needed neovim$' "$WORK/pkgout"

run_pkg neovim
check "a bare name nothing here carries falls through to the search" \
  grep -q 'searching every manager for "neovim"' "$WORK/pkgout"
check "and offers the install it found" \
  grep -q 'sudo pacman -S --needed neovim' "$WORK/pkgout"

run_pkg -i yay-bin
check "-i reaches the AUR helper when pacman does not carry it" \
  grep -qE 'paru -S --needed yay-bin' "$WORK/pkgout"

# The popup half: which row fzf hands back, and that the pick is installed
# right there, reporting its exit status to the caller. Driven headless
# through a pty (fzf needs a terminal, so this is skipped without one), on
# the stub PATH and with names no real manager carries — nothing here may
# reach the machine even if a stub were missed.
if command -v fzf >/dev/null 2>&1 && command -v script >/dev/null 2>&1; then
  printf 'pacman   zzz-pkg-test\tpacman\tzzz-pkg-test\naur      zzz-aur-test\taur\tzzz-aur-test\npacman   fzf\tpacman\tfzf\n' \
    >"$WORK/rows"
  # The fed newline is the keypress that closes the popup once the install
  # has finished; without it --pick waits there, as it should.
  pick_with() {
    : >"$WORK/choice"
    {
      printf '\r'
      sleep 2
    } |
      PATH="$PKG_BIN:/usr/bin:/bin" STUB_GOPATH="$WORK/gopath" \
        PKG_ROWS="$WORK/rows" PKG_CHOICE="$WORK/choice" \
        FZF_DEFAULT_OPTS="--bind $1" \
        timeout 30 script -qc "bash $REPO/configs/myscripts/.config/myscripts/pkg.sh --pick" \
        /dev/null >/dev/null 2>&1
    cat "$WORK/choice"
  }
  check "enter installs the highlighted row and reports it done" \
    test "$(pick_with 'load:accept')" = "$(printf 'pacman\tzzz-pkg-test\t0')"
  check "moving down one row picks the next one" \
    test "$(pick_with 'load:down+accept')" = "$(printf 'aur\tzzz-aur-test\t0')"
  check "esc installs nothing" test -z "$(pick_with 'load:abort')"
  check "picking a row the machine already has installs nothing (status 2)" \
    test "$(pick_with 'load:down+down+accept')" = "$(printf 'pacman\tfzf\t2')"

  # Search mode: no rows file, so the popup starts empty and every keystroke
  # re-runs the search. Typing a name and pressing enter twice (once for the
  # row, once for the popup's hold) must land on the exact pacman hit.
  search_pick() {
    : >"$WORK/choice"
    {
      printf 'neovim'
      sleep 3
      printf '\r'
      sleep 2
      printf '\r'
      sleep 1
    } |
      PATH="$PKG_BIN:/usr/bin:/bin" STUB_GOPATH="$WORK/gopath" \
        PKG_ROWS="" PKG_CHOICE="$WORK/choice" \
        timeout 40 script -qc "bash $REPO/configs/myscripts/.config/myscripts/pkg.sh --pick" \
        /dev/null >/dev/null 2>&1
    cat "$WORK/choice"
  }
  check "typing in the popup searches every manager and installs the pick" \
    test "$(search_pick)" = "$(printf 'pacman\tneovim\t0')"

  # ctrl-a (\001) ticks the row under the cursor, which moves it to the
  # bottom of the list; alt-enter (\033\r) installs every ticked row, and
  # enter installs nothing at all while any row is ticked. The keys are fed
  # as keystrokes rather than as a load binding, because the bindings are
  # what is under test.
  # One key per argument, a beat apart: the reload a tick kicks off is
  # asynchronous, so two ctrl-a's in the same breath would both land on the
  # row that was under the cursor when the first one was pressed — and the
  # second would untick it.
  tick_pick() {
    : >"$WORK/choice"
    {
      sleep 1
      for k in "$@"; do
        printf '%b' "$k"
        sleep 2
      done
      sleep 2
      printf '\r'
      sleep 1
    } |
      PATH="$PKG_BIN:/usr/bin:/bin" STUB_GOPATH="$WORK/gopath" \
        PKG_ROWS="$WORK/rows" PKG_CHOICE="$WORK/choice" \
        timeout 40 script -qc "bash $REPO/configs/myscripts/.config/myscripts/pkg.sh --pick" \
        /dev/null >/dev/null 2>&1
    cat "$WORK/choice"
  }
  check "ctrl-a ticks a row and alt-enter installs every ticked one" \
    test "$(tick_pick '\001' '\001' '\033\r')" = \
    "$(printf 'pacman\tzzz-pkg-test\t0\naur\tzzz-aur-test\t0')"
  check "enter installs nothing while a row is ticked" \
    test -z "$(tick_pick '\001' '\r' '\033')"

  # The same, in search mode: tick pacman's neovim, clear the query (\025 is
  # ctrl-u), search for something else, and install with alt-enter. The tick
  # has to survive the second search, and only the ticked row is installed —
  # never whatever the cursor ended up on.
  tick_search() {
    : >"$WORK/choice"
    {
      printf 'neovim'
      sleep 3
      printf '\001'
      sleep 2
      printf '\025fzf'
      sleep 3
      printf '\033\r'
      sleep 3
      printf '\r'
      sleep 1
    } |
      PATH="$PKG_BIN:/usr/bin:/bin" STUB_GOPATH="$WORK/gopath" \
        PKG_ROWS="" PKG_CHOICE="$WORK/choice" \
        timeout 60 script -qc "bash $REPO/configs/myscripts/.config/myscripts/pkg.sh --pick" \
        /dev/null >/dev/null 2>&1
    cat "$WORK/choice"
  }
  check "a tick survives the next search, and only ticked rows install" \
    test "$(tick_search)" = "$(printf 'pacman\tneovim\t0')"

  # An fzf given no input of its own runs FZF_DEFAULT_COMMAND and walks the
  # current directory, which would open the search popup on a list of files.
  # The marker file is how that shows up here: it must never be touched.
  rm -f "$WORK/walked"
  {
    sleep 1
    printf '\033'
    sleep 1
  } |
    PATH="$PKG_BIN:/usr/bin:/bin" STUB_GOPATH="$WORK/gopath" \
      PKG_ROWS="" PKG_CHOICE="$WORK/choice" \
      FZF_DEFAULT_COMMAND="touch $WORK/walked; echo bogus-row" \
      timeout 30 script -qc "bash $REPO/configs/myscripts/.config/myscripts/pkg.sh --pick" \
      /dev/null >/dev/null 2>&1
  check "the search popup starts empty, not on a directory listing" \
    not test -e "$WORK/walked"
fi

run_pkg --rows neovim
check "--rows feeds the popup's live search" \
  grep -qE '^\[ \] pacman +neovim' "$WORK/pkgout"
check "a row for something not installed carries no installed marker" \
  not grep -q 'already installed' "$WORK/pkgout"

run_pkg --rows fzf
check "a search row for something already here says so, before any enter" \
  grep -q 'fzf .*● already installed with pacman' "$WORK/pkgout"
check "and the row carries the holding manager for the preview" \
  grep -qP '\tpacman\tfzf\tpacman$' "$WORK/pkgout"
check "a one-letter query is not searched" \
  test -z "$(
    run_pkg --rows n
    cat "$WORK/pkgout"
  )"

# Whatever the popup did, it said so in there: closing it must not leave a
# line behind, which under a tmux key binding would be a view window.
if command -v fzf >/dev/null 2>&1; then
  run_pkg_popup 'pacman\tneovim\t0' -i neovim
  rc=$?
  check "a popup install leaves no output outside the popup" \
    not grep -qE 'installed neovim|install/packages' "$WORK/pkgout"
  check "and still exits 0" test "$rc" -eq 0

  run_pkg_popup 'pacman\tneovim\t1' -i neovim
  check "a popup install that failed does not report it twice" \
    not grep -q 'failed' "$WORK/pkgout"

  run_pkg_popup '' -i neovim
  rc=$?
  check "a cancelled popup leaves no output either" \
    not grep -q 'nothing installed' "$WORK/pkgout"
  check "and exits 1" test "$rc" -eq 1

  # The tmux key binding runs a bare pkg, and tmux announces any non-zero
  # status as "'...pkg.sh' returned 1" over the session. Closing the picker
  # is not a failure, so that entry point always succeeds.
  run_pkg_popup ''
  rc=$?
  check "a closed search popup is not a failed command" test "$rc" -eq 0
  check "and prints nothing at all" test ! -s "$WORK/pkgout"

  run_pkg_popup 'pacman\tneovim\t1'
  rc=$?
  check "nor is a failed install the key binding's problem" test "$rc" -eq 0
fi

run_pkg -i 'foo;rm -rf /'
rc=$?
check "-i refuses a name that is not a package name" \
  grep -q 'refusing' "$WORK/pkgout"
check "that refusal exits 1 and runs nothing" test "$rc" -eq 1

run_pkg -i cask:some-app
check "-i <manager>:<name> skips the search and uses that manager" \
  grep -q 'brew install --cask some-app' "$WORK/pkgout"

run_pkg -i npm:eslint
check "-i maps an npm/pnpm/yarn prefix onto the one node registry" \
  grep -qE '(pnpm add -g|npm install -g) eslint' "$WORK/pkgout"

# ---------------------------------------------------------------------------
echo "update"
# ---------------------------------------------------------------------------
# Its own stub dir, holding every manager update.sh reaches for and nothing
# else: no real paru or pacman can be found, so each check sees only what
# the stubs were asked to do. The log is the assertion.
UP_BIN="$WORK/upbin"
UP_LOG="$WORK/uplog"
mkdir -p "$UP_BIN"

cat >"$UP_BIN/pacman" <<'STUB'
#!/usr/bin/env bash
printf 'pacman %s\n' "$*" >>"$UP_LOG"
case "$1" in -Qtdq) printf 'orphan-one\norphan-two\n' ;; esac
exit 0
STUB

cat >"$UP_BIN/sudo" <<'STUB'
#!/usr/bin/env bash
exec "$@"
STUB

cat >"$UP_BIN/paru" <<'STUB'
#!/usr/bin/env bash
printf 'paru %s\n' "$*" >>"$UP_LOG"
exit "${STUB_UPGRADE_RC:-0}"
STUB

cat >"$UP_BIN/paccache" <<'STUB'
#!/usr/bin/env bash
printf 'paccache %s\n' "$*" >>"$UP_LOG"
STUB
cp "$UP_BIN/paccache" "$UP_BIN/pacdiff"
chmod +x "$UP_BIN"/*

# run_update [args...] — stubs first, the real managers unreachable.
run_update() {
  : >"$UP_LOG"
  env -u TMUX PATH="$UP_BIN:/usr/bin:/bin" UP_LOG="$UP_LOG" NO_COLOR=1 \
    STUB_UPGRADE_RC="${STUB_UPGRADE_RC:-0}" \
    bash "$REPO/configs/myscripts/.config/myscripts/update.sh" "$@" \
    >"$WORK/upout" 2>&1
}

run_update -n
rc=$?
check "a dry run exits 0" test "$rc" -eq 0
check "a dry run prints the upgrade it would run" grep -q 'paru -Syu' "$WORK/upout"
check "a dry run changes nothing" \
  not grep -qE 'paru -Syu|pacman -Rns|paccache -r' "$UP_LOG"

run_update
check "the upgrade is the AUR helper's, not a second pacman -Syu" \
  test "$(grep -c -- '-Syu' "$UP_LOG")" -eq 1
check "orphans pacman reported are the ones removed" \
  grep -q 'pacman -Rns orphan-one orphan-two' "$UP_LOG"
check "two versions stay in the cache, uninstalled ones do not" \
  test "$(grep -c -- 'paccache -rk2\|paccache -ruk0' "$UP_LOG")" -eq 2
check "no -Sy without the u, ever" not grep -qE -- '-Sy( |$)|-Syy' "$UP_LOG"

STUB_UPGRADE_RC=1 run_update
rc=$?
check "a failed upgrade exits 1" test "$rc" -eq 1
check "and the cleanup never runs on a half-upgraded system" \
  not grep -qE 'pacman -Rns|paccache' "$UP_LOG"
unset STUB_UPGRADE_RC

# An empty PATH on purpose: with the real /usr/bin here this check would
# start a real upgrade.
mkdir -p "$WORK/empty-bin"
env PATH="$WORK/empty-bin" NO_COLOR=1 \
  "$BASH" "$REPO/configs/myscripts/.config/myscripts/update.sh" >"$WORK/upout" 2>&1
rc=$?
check "without pacman it refuses to run" test "$rc" -eq 1

# ---------------------------------------------------------------------------
echo "os detection"
# ---------------------------------------------------------------------------
if [[ "$(uname -s)" == "Linux" ]]; then
  printf 'ID=manjaro\nID_LIKE=arch\n' >"$WORK/os-release"
  check "ID_LIKE=arch detects as arch" \
    env OS_RELEASE_FILE="$WORK/os-release" bash "$REPO/scripts/detect-os.sh"
else
  check "Darwin detects as macos" \
    test "$(bash "$REPO/scripts/detect-os.sh")" = macos
fi

# ---------------------------------------------------------------------------
echo "sessionizer"
# ---------------------------------------------------------------------------
# Only ask_dir is exercised: the functions are sourced (the trailing
# `main "$@"` line is dropped) and zoxide is a stub, so no tmux session is
# ever created and no real directory history is consulted.
mkdir -p "$WORK/zx/myproj"
ask_dir_out() {
  HOME="$WORK" bash -c '
    set -uo pipefail
    eval "$(sed "\$d" "$1")"
    zoxide() { [[ "$3" == myproj ]] && echo "$HOME/zx/myproj"; return 0; }
    ask_dir IDE 2>/dev/null
  ' _ "$REPO/configs/tmux/.config/tmuxScript/sessionizer.sh"
}

check "a typed name resolves its start directory through zoxide" \
  test "$(echo myproj | ask_dir_out)" = "$WORK/zx/myproj"
check "no zoxide match falls back to \$HOME" \
  test "$(echo nope | ask_dir_out)" = "$WORK"
check "an empty answer falls back to \$HOME" \
  test "$(echo '' | ask_dir_out)" = "$WORK"
check "a closed stdin falls back to \$HOME" \
  test "$(ask_dir_out </dev/null)" = "$WORK"

# ---------------------------------------------------------------------------
echo "tripwire"
# ---------------------------------------------------------------------------
# The real $HOME must be untouched: nothing at a link target may have been
# created or replaced while these checks ran ($WORK is this run's clock).
touched=0
while IFS= read -r dest; do
  real="$REAL_HOME/$dest"
  if [[ -e "$real" || -L "$real" ]] &&
    [[ -n "$(find "$real" -maxdepth 0 -newer "$WORK" 2>/dev/null)" ]]; then
    touched=$((touched + 1))
    printf '       modified: %s\n' "$real"
  fi
done < <(link_dests)
check "the real \$HOME was not modified" test "$touched" -eq 0

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
test "$FAILED" -eq 0
