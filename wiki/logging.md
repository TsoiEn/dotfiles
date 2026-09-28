# Logging

Every run — bootstrap and each child script — appends to **one shared log file** while also printing colored progress to the terminal.

## `log_init`

```bash
LOG_DIR="${LOG_DIR:-$DOTFILES_ROOT/logs}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/bootstrap-<YYYYMMDD-HHMMSS>.log}"
```

- Creates `LOG_DIR`, touches the file, exports both.
- **Never overwrites an existing `LOG_FILE`.** Bootstrap calls `log_init` once and exports `LOG_FILE`; `install/arch.sh` and `install/macos.sh` check `if [ -z "${LOG_FILE:-}" ]` before calling it again, so they append to the same file instead of starting a new one.
- When `LOG_DIR` is unset and a script runs standalone, it defaults to `<repo>/logs/`.

## Output

Format: `[YYYY-MM-DD HH:MM:SS] [LEVEL] message`

| Function | Level |
|---|---|
| `log_info` | `INFO` (blue) |
| `log_success` | `OK` (green) |
| `log_warn` | `WARN` (yellow) |
| `log_error` / `die` | `ERROR` (red) |

- **Terminal:** colored when stdout is a TTY (`[ -t 1 ]`), plain when piped or redirected.
- **File:** always plain (no ANSI codes), timestamped, appended — a failing append is `|| true`'d so it can never abort a run under `set -e`.
- `log_info` etc. never exit; only `die` (`log_error` + `exit 1`) terminates the caller.

## Overriding

```bash
LOG_DIR=/tmp/dotfiles-logs ./bootstrap.sh   # whole run logs elsewhere
LOG_FILE=/tmp/one.log bash scripts/setup-nvim.sh
```

## Reading a log

One file per run, written in execution order:

```
[14:15:30] [INFO] Starting bootstrap
[14:15:30] [INFO] Detected OS: macos
[14:15:31] [INFO] Reading packages from .../install/packages/brew.txt
[14:15:33] [INFO] Running setup scripts
[14:15:33] [OK] symlinks: 6 linked, 0 already linked, 1 backed up
[14:15:33] [INFO] backed up: /Users/x/.zshrc -> .../backups/20260925-141530/.zshrc
...
[14:15:35] [OK] Bootstrap complete
```

The absence of `Bootstrap complete` means the run failed — the last lines show where. See [troubleshooting.md](troubleshooting.md).

## Related

- [bootstrap.md](bootstrap.md) — where `LOG_FILE` is created and exported
- [development.md](development.md) — tests assert log contents
