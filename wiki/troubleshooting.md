# Troubleshooting

Start with the log: `ls logs/` → newest `bootstrap-<timestamp>.log`. One file covers the whole run (bootstrap + every child). **No `Bootstrap complete` line = the run failed**; the last lines show where.

## bootstrap.sh fails immediately

```
bootstrap.sh: line 9: scripts/utils.sh: No such file or directory
```

You are not running from the repo root, or the checkout is partial. Run `./bootstrap.sh` from the repository, or check that all of `scripts/` was cloned (7 files).

## `Unsupported OS. Supported: arch, macos`

`detect_os` returned empty. On Linux check `/etc/os-release` has `ID=arch` or `ID_LIKE` containing `arch`. Diagnostics are on stderr just above the error. Simulate with `OS_RELEASE_FILE=…` — see [os-detection.md](os-detection.md).

## `Required command not found: brew` (fresh macOS)

Homebrew isn't installed yet — no script bootstraps it (Phase 5). Install brew first, then re-run `./bootstrap.sh`. Same idea for missing `git`.

## `source missing — repo incomplete: …`

`setup-symlinks.sh` validate-first check — a `LINK_MAP` source doesn't exist (incomplete clone, or you edited `LINK_MAP` wrong). **`$HOME` was not modified.** Fix the repo/entry and re-run.

## Links not created / "config missing" warnings

```bash
bash scripts/setup-symlinks.sh
```

Read the summary: `6 already linked` = nothing to do; anything else was either linked now or backed up. If a target points somewhere unexpected: `ls -l ~/.zshrc ~/.config/nvim` and compare with the [link map](symlinks.md).

## Something was moved I didn't expect

It went to `backups/<timestamp>/<path-relative-to-HOME>` — nothing is deleted. Restore with:

```bash
rm ~/.zshrc && mv backups/<timestamp>/.zshrc ~/.zshrc
```

## tpm / tmux plugins not installed

```
WARN no plugins installed yet — open tmux and press <prefix> + I (needs network)
```

Best-effort sync failed (offline, or tpm not yet cloned). Open tmux and press `prefix + I`, or re-run `bash scripts/setup-tmux.sh` with network. A directory at `~/.tmux/plugins/tpm` that isn't a git repo is deliberately left alone — delete it manually if you want a clean reinstall.

## Ghostty reported as "not installed" though it is

Detection looks for a `ghostty` CLI on PATH or an app bundle in `/Applications` / `~/Applications`. Custom location? `GHOSTTY_APP_DIRS=/your/path bash scripts/setup-ghostty.sh`.

## Neovim plugins missing

First `nvim` launch bootstraps lazy.nvim automatically (needs network). For an immediate sync: `SETUP_NVIM_SYNC=1 bash scripts/setup-nvim.sh`, or run `:Lazy sync` inside nvim. Sync output is in the log file, not on the console.

## Logs/backups ended up in the wrong place

Defaults are repo-relative. Override per run:

```bash
LOG_DIR=/tmp/dl BACKUP_DIR=/tmp/dl-backups ./bootstrap.sh
```

## Undo everything

```bash
# restore the most recent session, remove all symlinks this repo created
ls backups/                       # pick a timestamp
for each backed-up path:  rm <target> && mv backups/<ts>/<path-relative-to-HOME> <target>
```

Or simply restore from `git` — the links are the only thing bootstrap adds to `$HOME`.

## Related

- [logging.md](logging.md) — log format and overrides
- [backups.md](backups.md) — session layout
- [development.md](development.md) — reproducing issues safely
