# Wiki — dotfiles installer

Documentation for how the installer works, how to operate it, and how to extend it. Start with [bootstrap.md](bootstrap.md) for the big picture.

## Core flow

| Page | What it covers |
|---|---|
| [bootstrap.md](bootstrap.md) | Entry point: env setup, ordering, failure propagation, env vars |
| [os-detection.md](os-detection.md) | How `detect_os` decides `arch` vs `macos`, and what happens otherwise |
| [setup-scripts.md](setup-scripts.md) | The per-app checks: nvim, tmux (tpm), Ghostty — and their best-effort philosophy |

## Mechanics

| Page | What it covers |
|---|---|
| [symlinks.md](symlinks.md) | The `LINK_MAP`, the 4-step algorithm, path canonicalization, adding a config |
| [backups.md](backups.md) | `backup_path`, session directories, safety rails, restoring files |
| [logging.md](logging.md) | `log_init`, the shared `LOG_FILE` contract, log format and overrides |
| [packages.md](packages.md) | Package list format, pacman/paru/brew install loops, known gaps |

## Guides

| Page | What it covers |
|---|---|
| [troubleshooting.md](troubleshooting.md) | Symptom → fix for common failures, and where to look in the logs |
| [development.md](development.md) | Conventions, testing patterns used to verify the installer, how to change it safely |
