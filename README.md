# dotfiles

Cross-platform dotfiles installer for **Arch Linux** and **macOS** — one command provisions a machine.

## Introduction

This repository is the single source of truth for how a development machine is set up. Instead of copying configuration files around, `bootstrap.sh` **symlinks** everything in `configs/` straight into `$HOME`, so editing a live config is editing this repo — changes are versioned, reviewable, and portable.

Design goals:

- **One command** — `./bootstrap.sh` detects the OS, installs packages, and wires every config.
- **Idempotent** — re-running is always safe; a fully provisioned machine is a no-op.
- **Never destructive** — existing configs are moved to `backups/<timestamp>/` before linking, never deleted.
- **Fully logged** — bootstrap and every child script write to one shared log file.
- **Fail loudly, degrade politely** — a broken repo aborts *before* touching `$HOME`; optional extras (plugins, GUI apps) warn instead of failing.

Manages: **zsh**, **Neovim**, **tmux**, **Ghostty**, **git**, **Claude Code** — 41 config files.

## What's new — Phase 1

The installer previously referenced a `scripts/` directory that did not exist, so `bootstrap.sh` could not run at all. Phase 1 made it functional end-to-end:

| Script | Job |
|---|---|
| `scripts/utils.sh` | Logging (`log_init`, `log_info/…`), `die`, `ensure_dir`, `command_exists`, `require_command`, `run_as_root` |
| `scripts/detect-os.sh` | `detect_os` → `arch` \| `macos` (uname → os-release → pacman fallback) |
| `scripts/backup.sh` | `backup_path` — moves existing configs into a timestamped session, `$HOME`-scoped safety rails |
| `scripts/setup-symlinks.sh` | Links all 9 targets (validates every source first, then backs up + links) |
| `scripts/setup-zsh.sh` | Clones oh-my-zsh + its three external plugins, optional `chsh` |
| `scripts/setup-tmux.sh` | Installs tpm + plugins (best effort; not in any package list) |
| `scripts/setup-nvim.sh` | Verifies config wiring + lazy.nvim state; optional `SETUP_NVIM_SYNC=1` |
| `scripts/setup-ghostty.sh` | Detects Ghostty (CLI or app bundle) + verifies config link |

Symlink map — 9 targets (directory-level, plus the single files):

| Source | Target |
|---|---|
| `configs/zsh/.zshrc` | `~/.zshrc` |
| `configs/zsh/.config/zshrc` | `~/.config/zshrc` |
| `configs/nvim/.config/nvim` | `~/.config/nvim` |
| `configs/tmux/.tmux.conf` | `~/.tmux.conf` |
| `configs/tmux/.config/tmuxScript` | `~/.config/tmuxScript` |
| `configs/ghostty/.config/ghostty` | `~/.config/ghostty` |
| `configs/aerospace/.aerospace.toml` | `~/.aerospace.toml` |
| `configs/myscripts/.config/myscripts` | `~/.config/myscripts` |
| `configs/git/.config/git/ignore` | `~/.config/git/ignore` |
| `configs/git/.gitconfig` | `~/.gitconfig` |

Also included: physical-path canonicalization (idempotent even through symlinked repo paths), validate-first ordering (a broken repo never half-links `$HOME`), and a sandboxed test suite — `bash tests/run.sh`, **23 checks** with a `mktemp` `$HOME`, stubbed package managers and a tripwire asserting the real `$HOME` was never touched.

**Not yet fixed** — known config bugs (zsh hardcoded paths, duplicate nvim plugin specs) are tracked in the roadmap below.

## Quick start

```bash
git clone git@github.com:TsoiEn/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
```

**First run:** detects the OS → installs missing packages from `install/packages/*.txt` → links the 9 targets (anything already at those paths is moved to `backups/<timestamp>/`) → runs the per-app setup checks. Read the run's log at `logs/bootstrap-<timestamp>.log`.

**Re-run:** safe at any time — installed packages are skipped, correct links are reported as `already linked`, and no new backup session is created if there is nothing to back up.

## How it works

```
bootstrap.sh
├── source scripts/utils.sh, scripts/detect-os.sh
├── log_init → logs/bootstrap-<ts>.log       (exported to all children)
├── detect_os → arch | macos  (else die)
├── install/packages.sh <os>
│   └── install/common.sh → read_package_list → pacman/paru/brew  (skip installed)
└── setup scripts (order matters — symlinks first)
    ├── setup-symlinks.sh   backup existing → ln -s ×9
    ├── setup-zsh.sh        oh-my-zsh + plugins + optional chsh
    ├── setup-nvim.sh       verify config + lazy.nvim state
    ├── setup-tmux.sh       install tpm + plugins (best effort)
    ├── setup-ghostty.sh    detect app + verify config link
    └── setup-claude.sh     fan-out link ~/.claude config + install plugins
```

Details: [wiki/bootstrap.md](wiki/bootstrap.md).

## Repository structure

```
dotfiles/
├── bootstrap.sh              # entry point
├── .gitignore                # runtime output, secrets, OS/editor scratch
├── install/
│   ├── packages.sh           # the package layer, both OSes
│   ├── bootstrap-pm.sh       # ensure_brew / ensure_pacman_sync / ensure_paru
│   ├── common.sh             # shared package-install logic
│   └── packages/
│       ├── common.txt        # names identical on both OSes
│       ├── arch.txt
│       └── brew.txt
├── scripts/
│   ├── utils.sh              # logging + helpers
│   ├── detect-os.sh
│   ├── backup.sh
│   ├── setup-symlinks.sh
│   ├── setup-zsh.sh
│   ├── setup-tmux.sh
│   ├── setup-nvim.sh
│   ├── setup-ghostty.sh
│   └── setup-claude.sh
├── configs/                  # mirrored tree, symlinked into $HOME
│   ├── zsh/  nvim/  tmux/  ghostty/  aerospace/  myscripts/  claude/  git/
├── tests/run.sh              # sandboxed checks (bash tests/run.sh)
├── .github/workflows/        # shellcheck + shfmt + tests
├── wiki/                     # installer documentation
├── logs/                     # generated at runtime (not tracked)
└── backups/                  # generated at runtime (not tracked)
```

## Configurations covered

| App | Repo path | Target | Status |
|---|---|---|---|
| zsh | `configs/zsh/` | `~/.zshrc`, `~/.config/zshrc/` | ✅ linked (known path bugs → Phase 3) |
| Neovim | `configs/nvim/` | `~/.config/nvim/` | ✅ linked (duplicate plugin specs → Phase 4) |
| tmux | `configs/tmux/` | `~/.tmux.conf`, `~/.config/tmuxScript/` | ✅ linked + tpm installer |
| Ghostty | `configs/ghostty/` | `~/.config/ghostty/` | ✅ linked + `cask:ghostty` installed |
| AeroSpace | `configs/aerospace/` | `~/.aerospace.toml` | ✅ linked + `cask:aerospace` installed |
| my scripts | `configs/myscripts/` | `~/.config/myscripts/` | ✅ linked (`gclone` → [wiki/gclone.md](wiki/gclone.md), `gstats` → [wiki/gstats.md](wiki/gstats.md), `pkg`) |
| Claude Code | `configs/claude/` | `~/.claude/CLAUDE.md`, `~/.claude/skills/*`, plugins | ✅ linked + plugins ([wiki/claude.md](wiki/claude.md)) |
| git | `configs/git/` | `~/.config/git/ignore`, `~/.gitconfig` | ✅ ignore + global config linked, no identity in either ([wiki/git.md](wiki/git.md)) |

## Restoring a backup

Before any config is replaced, it is moved to a timestamped session mirroring its path relative to `$HOME`:

```
backups/20260925-141530/.zshrc
backups/20260925-141530/.config/nvim/init.lua
```

To restore one:

```bash
rm ~/.zshrc                                   # remove the symlink
mv backups/<timestamp>/.zshrc ~/.zshrc        # put the original back
```

Re-running `bootstrap.sh` afterwards will back the original up again and re-link.

## FAQ

**Does it overwrite my configs?**
Nothing is deleted. Any file or directory found at a link target is first moved into `backups/<timestamp>/`. Both safety rails (refusing to move anything outside `$HOME` or inside this repo) are enforced before any move.

**Can I skip package installation?**
```bash
./bootstrap.sh --skip-packages          # link + run every setup script
./bootstrap.sh --only=setup-symlinks    # one setup script (implies --skip-packages)
./bootstrap.sh --help
```
Every script also works standalone (`bash scripts/setup-symlinks.sh`).

**How do I add a config?**
Add it under `configs/` following the existing layout, then add one line to `LINK_MAP` in `scripts/setup-symlinks.sh`. See [wiki/symlinks.md](wiki/symlinks.md).

**Where do I put machine-specific values or secrets?**
`~/.config/zshrc/custom/` — `.zshrc` sources `custom/*.zsh` after the numbered files, so it can override anything. That path is this repo through the symlink, and `.gitignore` excludes it, so a host's tokens stay local. Example: `configs/zsh/.config/zshrc/custom/90-secrets.zsh`.

**Windows support?**
No — only Arch Linux and macOS are detected; anything else aborts with `Unsupported OS`.

## Roadmap

- **Phase 3** — zsh fixes: guard the remaining hardcoded macOS path (`PNPM_HOME`), dedupe `EDITOR`/`PATH` between `.zshrc` and `00_init.zsh`, drop conflicting syntax-highlighting plugins
- **Phase 4** — Neovim fixes: merge duplicate `conform.nvim` specs, align Mason ↔ linter tool lists
- ~~**Phase 5**~~ — done: one `install/packages.sh`, a shared `common.txt`, `--skip-packages` / `--only=`
- ~~**Phase 6**~~ — done: `.github/workflows/lint.yml` (shellcheck + shfmt + `tests/run.sh`)
- **Original spec leftovers** — `configs/git/`, `.gitconfig` and the zsh setup script have shipped. `bin/` is deliberately dropped: `configs/myscripts/` already is this repo's script directory, and a second one on `PATH` would only split it

## Wiki

Full installer documentation lives in [`wiki/`](wiki/README.md):

- **Core flow** — [bootstrap](wiki/bootstrap.md) · [OS detection](wiki/os-detection.md) · [setup scripts](wiki/setup-scripts.md)
- **Mechanics** — [symlinks](wiki/symlinks.md) · [backups](wiki/backups.md) · [logging](wiki/logging.md) · [packages](wiki/packages.md)
- **Helpers** — [gclone](wiki/gclone.md) · [gstats](wiki/gstats.md) · [Claude Code config](wiki/claude.md)
- **Guides** — [troubleshooting](wiki/troubleshooting.md) · [development](wiki/development.md)
