# Backups

`scripts/backup.sh` (sourced by `setup-symlinks.sh`) relocates anything found at a link target before it is replaced. **Nothing is ever deleted.**

## Layout

A timestamped *session* directory inside `BACKUP_DIR` (default `<repo>/backups/`), mirroring each path **relative to `$HOME`**:

```
backups/
└── 20260925-141530/
    ├── .zshrc
    ├── .config/nvim/init.lua
    └── .tmux.conf            ← even symlinks are moved as symlinks
```

Sessions are created **lazily**: `backup_init` only runs when `backup_path` actually has something to move, so a clean re-run creates no directories at all (bootstrap itself creates the empty `backups/` container).

## API

```bash
backup_path <path>      # move an existing path into the current session
backup_session_dir      # print the session dir (empty if unused)
backup_init             # resolve/create the session dir (called for you)
```

`backup_path` is a **no-op** when the path doesn't exist.

## Safety rails (both abort before any move)

1. **Must be under `$HOME`** — the path is resolved (parent directory via `cd` + `pwd -P`, no `realpath` dependency) and prefix-checked. `$HOME` itself is rejected too.
2. **Must not be inside `$DOTFILES_ROOT`** — prevents shuffling the repo into its own `backups/`.

Wrong argument count or unset `BACKUP_DIR` also abort. Because `die` calls `exit`, these failures terminate the sourcing script — `setup-symlinks.sh` stops, and so does `bootstrap.sh`.

## Edge cases handled

- **Dangling symlinks** — a link pointing at a missing file fails `-e` but passes `-L`; it is still moved (otherwise the following `ln -s` would fail).
- **Symlink vs pointee** — the link itself is moved; whatever it points at is untouched.
- **Name collisions** — if a destination somehow already exists in the session, the copy gets a `.1`, `.2`, … suffix.
- **`$HOME`-relative resolution** — relative inputs (`bash scripts/setup-symlinks.sh` run from anywhere) are absolutized before the rail check.

## Restoring

```bash
rm ~/.zshrc                                # if it's a symlink
mv backups/<timestamp>/.zshrc ~/.zshrc
```

Re-running `bootstrap.sh` afterwards backs the restored original up again and re-links.

## Related

- [symlinks.md](symlinks.md) — the caller and its ordering
- [logging.md](logging.md) — every move is logged with source and destination
