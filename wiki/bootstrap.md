# bootstrap.sh

The single entry point. Runs top-to-bottom under `set -euo pipefail` — any failing command aborts the run.

## Flow

```
bootstrap.sh
├── resolve + export DOTFILES_ROOT          (repo root, from BASH_SOURCE)
├── source scripts/utils.sh                 (logging + helpers)
├── source scripts/detect-os.sh             (defines detect_os)
├── LOG_DIR/BACKUP_DIR defaults + export
├── log_init → logs/bootstrap-<ts>.log      (LOG_FILE exported to children)
├── ensure_dir $LOG_DIR, $BACKUP_DIR
├── OS="$(detect_os || true)"
│     └── empty → die "Unsupported OS. Supported: arch, macos"
├── case $OS
│     arch  → bash install/arch.sh
│     macos → bash install/macos.sh
└── setup scripts (each is a separate `bash` process)
      1. scripts/setup-symlinks.sh     ← must run FIRST
      2. scripts/setup-nvim.sh
      3. scripts/setup-tmux.sh
      4. scripts/setup-ghostty.sh
```

### Why symlinks run first

`setup-nvim.sh` reports on `~/.config/nvim` and `setup-ghostty.sh` reports on `~/.config/ghostty/`. Both targets only exist after `setup-symlinks.sh` has run, so ordering them last would make every fresh-machine run print a misleading "config missing" warning.

### Failure propagation

Because each child is a separate process invoked under bootstrap's `set -e`:

- A failing package installer stops everything (no setup scripts run).
- `setup-symlinks.sh` validates **all** sources before touching `$HOME`, so a broken checkout fails with `$HOME` completely untouched.
- If a setup script dies, earlier steps persist and later ones never run — there is no rollback, but there is also no false "Bootstrap complete" (the final `log_success` is only reached on full success).

## Environment

Exported by bootstrap and consumed by children:

| Variable | Default | Purpose |
|---|---|---|
| `DOTFILES_ROOT` | resolved from `bootstrap.sh` location | repo root used by every script |
| `LOG_DIR` | `$DOTFILES_ROOT/logs` | overridable: `LOG_DIR=/tmp/dl ./bootstrap.sh` |
| `LOG_FILE` | `$LOG_DIR/bootstrap-<ts>.log` | single shared log — set once, appended by all children |
| `BACKUP_DIR` | `$DOTFILES_ROOT/backups` | overridable; `backups/<ts>/` sessions are created lazily inside it |

Recognized by individual setup scripts (see [setup-scripts.md](setup-scripts.md)):
`SETUP_NVIM_SYNC`, `TPM_DIR`, `GHOSTTY_APP_DIRS`, plus `OS_RELEASE_FILE` for [os-detection.md](os-detection.md).

## Running pieces individually

Every script is standalone (`bash scripts/<name>.sh`); when run that way it resolves `DOTFILES_ROOT` itself and calls `log_init` if no `LOG_FILE` is set — so logs work even outside bootstrap.

```bash
bash scripts/setup-symlinks.sh          # re-link only
LOG_DIR=/tmp/dl ./bootstrap.sh          # full run, logs elsewhere
```

## Related

- [os-detection.md](os-detection.md) — how the OS is chosen
- [packages.md](packages.md) — what the install step does
- [symlinks.md](symlinks.md) / [backups.md](backups.md) — what the setup steps do
- [troubleshooting.md](troubleshooting.md) — when a run fails
