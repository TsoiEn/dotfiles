# Setup scripts

Three per-app checks run after symlinking. All share one philosophy: **report problems, never fail bootstrap** — packages, symlinks and backups are already done by the time they run, so a missing optional tool must not undo that. (The one exception: `setup-symlinks.sh` — see [symlinks.md](symlinks.md).)

## setup-nvim.sh

Default run is **offline and forks no nvim process**.

| Check | Output |
|---|---|
| `nvim` not on PATH | warn + skip |
| `~/.config/nvim/init.lua` missing | warn → "run scripts/setup-symlinks.sh first" |
| config is a symlink | `nvim config linked: … -> <target>` |
| config is a real dir | `… (not a symlink)` |
| lazy.nvim installed | `lazy.nvim installed: <path> (N plugin(s))` |
| lazy.nvim absent | "it bootstraps on first nvim launch" (`lazy.lua`) |

Plugin state is computed from `stdpath('data')` **arithmetically** (`${XDG_DATA_HOME:-~/.local/share}/nvim`) rather than asking a headless nvim — instant and guaranteed offline. The plugin count excludes `lazy.nvim` itself.

**Opt-in sync:** `SETUP_NVIM_SYNC=1 bash scripts/setup-nvim.sh` runs `nvim --headless "+Lazy! sync" +qa` (network, can take minutes). Its output is appended to `$LOG_FILE`, never printed to the console; failure produces a `:Lazy sync` hint, exit code stays 0.

## setup-tmux.sh

Installs **tpm** (`https://github.com/tmux-plugins/tpm`), which `.tmux.conf` expects at `~/.tmux/plugins/tpm` but no package list provides.

1. `tmux` missing → warn + skip.
2. tpm missing → `GIT_TERMINAL_PROMPT=0 git clone --depth 1` (clone failure — offline — warns and returns 0).
3. tpm exists but isn't a git repo → warn, **never clobbered**.
4. Plugins are synced **only when actually needed**: fresh tpm, or a tpm with zero sibling plugin dirs. On a provisioned machine the script logs "nothing to do" and **runs neither `git` nor `tmux`**.
5. Sync = `tmux start-server \; run-shell '…/tpm/bin/install_plugins'`. Success is judged by plugin directories appearing on disk (older tmux doesn't propagate `run-shell` exit codes). Failure → `open tmux and press <prefix> + I`.

Override the location with `TPM_DIR=/path/to/tpm`.

## setup-ghostty.sh

App detection understands both install shapes:

- `ghostty` CLI on PATH, **or**
- an app bundle in `GHOSTTY_APP_DIRS` (colon-separated, default `/Applications:$HOME/Applications`).

Then:

| Situation | Output |
|---|---|
| macOS, no Ghostty, brew present | hint: uncomment `cask:ghostty` in `install/packages/brew.txt` |
| macOS, no Ghostty, no brew | adjusted hint (no cask suggestion) |
| Arch | warn: not in `arch.txt` — config link only |
| unsupported OS | warn — config link only |

Config check happens on **all** platforms at the directory level (`~/.config/ghostty`, because that is what the symlink map links): `linked` / `broken` (link exists, config doesn't) / `present (not a symlink)` / `missing`. Never auto-installs a GUI app; always exit 0.

## Common to all three

- Standalone-runnable; init their own logging when `$LOG_FILE` is unset.
- Non-fatal: warnings only, `log_success … checks complete` at the end.
- No side effects on a fully provisioned machine (verified by tripwire tests — see [development.md](development.md)).

## Related

- [bootstrap.md](bootstrap.md) — where they run in the sequence
- [packages.md](packages.md) — what the install step does *not* provide
- [troubleshooting.md](troubleshooting.md) — interpreting their warnings
