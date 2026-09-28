# Development

Conventions for changing the installer without breaking it.

## Before you change anything

```bash
bash -n bootstrap.sh install/*.sh scripts/*.sh    # syntax sweep (fast, always run)
```

`shellcheck`/`shfmt` + CI are Phase 6 — until then `bash -n` plus the manual patterns below are the safety net.

## Testing patterns

All installer tests are **sandboxed** — they never touch your real `$HOME` or running services.

### Sandbox the state

```bash
export HOME="$TMP/home" LOG_DIR="$TMP/logs" BACKUP_DIR="$TMP/backups"
unset LOG_FILE BACKUP_SESSION
bash scripts/setup-symlinks.sh
```

Every script honors these, so a full `bootstrap.sh` run can be exercised with zero real-world effects. Remember to export `LOG_DIR` for each test process — forgetting it once created a stray `logs/` in the repo.

### Stub commands on `PATH`

Put fake `brew` / `git` / `tmux` / `nvim` first on `PATH` to record invocations and fake results:

```bash
#!/usr/bin/env bash
echo "$0 $*" >> "$CALL_LOG"     # assert exact arguments
exit "${STUB_RC:-0}"            # or fail on purpose
```

Used to verify: package skip-vs-install branches, `git clone` args, `tmux start-server \; run-shell` invocations, `nvim --headless "+Lazy! sync" +qa`.

### Tripwires

A stub that logs **and exits 99** proves a script made *zero* invocations on a provisioned machine — the live-machine runs in Phase 1 used this for `git`, `tmux`, and `nvim` so the real services were never contacted.

### Simulating OSes

```bash
printf 'ID=arch\n' > /tmp/arch
OS_RELEASE_FILE=/tmp/arch PATH="$STUB_UNAME_LINUX:$PATH" bash scripts/detect-os.sh
```

Stub `uname` to print `Linux`, point `OS_RELEASE_FILE` at a crafted os-release — see [os-detection.md](os-detection.md).

### Real tmux without your sessions

```bash
tmux -L testprobe start-server \; run-shell 'touch /tmp/probe'
```

Custom socket (`-L`) keeps probes away from the default socket holding your live sessions.

### Live-machine verification

Running a script against the **real** `$HOME` is valuable (it must report `already linked`, not act) but only with: sandboxed `LOG_DIR`/`BACKUP_DIR`, command tripwires, and a check that no `backups/<ts>/` session appeared.

## Making changes

| Task | Where |
|---|---|
| Add a config | `LINK_MAP` in `scripts/setup-symlinks.sh` — see [symlinks.md](symlinks.md) |
| Add a package | `install/packages/{arch,brew}.txt` — see [packages.md](packages.md) |
| Logging behavior | `scripts/utils.sh` (`_log`, `log_init`) |
| Bootstrap sequence/order | `bootstrap.sh` — see [bootstrap.md](bootstrap.md) |

## Conventions observed in this codebase

- `set -euo pipefail` in every entry-point script; libraries (`utils.sh`, `backup.sh`) contain only definitions + guarded defaults so they can be sourced under it.
- Re-source guards use `if … return`, never `cond && return` (the latter poisons a function's exit status for callers under `set -e`).
- `die` = log + `exit 1`, and is reserved for "stop everything" situations; per-app setup scripts only warn.
- Failures in command substitutions inside `detect_os` are `|| true`'d where absence is legitimate (missing `ID_LIKE`).
- Bash 3.2 compatibility for anything that might run on stock macOS: no associative arrays, no `realpath`, `${@: -1}`-style expansions used carefully.

## Related

- [bootstrap.md](bootstrap.md) · [symlinks.md](symlinks.md) · [troubleshooting.md](troubleshooting.md)
