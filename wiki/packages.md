# Packages

`install/packages.sh <os>` reads two plain-text lists — the shared one and the OS's own — and installs whatever is missing.

## Flow

```
bootstrap.sh
└── install/packages.sh <os>
    ├── install/bootstrap-pm.sh   ensure_brew | ensure_pacman_sync + ensure_paru
    └── install/common.sh
        ├── read_package_list packages/common.txt packages/<os>.txt
        └── install_brew_packages / install_arch_packages
```

One script for both OSes: they differ only in which package manager is made to exist first and which second list is read.

## List format

`install/packages/common.txt` holds every name that is **identical on both OSes**; `brew.txt` and `arch.txt` hold only that OS's own names (`gh` vs `github-cli`, `node` vs `nodejs`). Both installers read `common.txt` first, then their own list. One package per line:

```txt
# Core tools          ← comments allowed (full-line or trailing)
neovim
tmux
cask:ghostty          ← brew only: 'cask:' prefix installs a cask
```

`read_package_list` takes several files, strips everything after `#`, trims whitespace, drops empties. `common.txt` is the 14 shared names (core tools plus `nvm`, `python`, `go`); the per-OS lists add the renamed toolchains, a Nerd Font, Ghostty, and on Arch the clipboard and build tools.

A `cask:` line in the shared list would reach `pacman` as a literal package name, so `install_arch_packages` logs and skips it.

## Install behavior (idempotent)

**Arch** — uses `paru` when available (AUR support), otherwise `pacman` via `run_as_root` (sudo). Each package is first checked with `pacman -Qi`; installed ones are logged as skipped.

**macOS** — `brew list --formula -1` / `--cask -1` are snapshotted **once** per run (they used to fork per package) and grepped to decide skip vs install; `cask:` prefixed entries become `brew install --cask`.

Flags: `PACMAN_FLAGS`/`PARU_FLAGS` default to `--needed --noconfirm`, `BREW_FLAGS` is empty — all overridable via environment.

A package that fails to install is logged as a warning and recorded; the loop continues and the function still returns 0, so `bootstrap.sh` reaches the symlink step. Each function ends with a `N package(s) failed: …` summary when anything went wrong.

## Intentionally manual

Not in either list, on purpose — each ships its own installer and update
channel, so pinning it into a `brew install` loop buys drift, not
reproducibility:

| Tool | Install it with | Used by |
|---|---|---|
| `claude` (Claude Code) | its own installer / npm | `scripts/setup-claude.sh` (skips with a warning when absent) |
| `opencode` | its own installer | `oc` alias in `configs/zsh/.zshrc.d/25-aliases.zsh` |
| `pnpm` | `corepack` / its own installer | ad-hoc |

## Known gaps

Not installed by any list (relevant when reading the setup scripts):

| Missing | Consequence | Covered by |
|---|---|---|
| `tpm` | tmux would have no plugin manager | `scripts/setup-tmux.sh` |
| `oh-my-zsh` + zsh plugins | zsh config errors on fresh machines | `scripts/setup-zsh.sh` |
| Homebrew itself / Xcode CLT | fresh macOS dies at `require_command brew` | `install/bootstrap-pm.sh` (`ensure_brew`) |
| nvim formatters/linters | — | mason inside Neovim (`mason-tool-installer`); their toolchains (`node`, `python`, `go`, `openjdk`) are now in both lists |
| `paru` | AUR packages (`nvm` on Arch) are unreachable without it | `ensure_paru`, opt-in: `DOTFILES_AUR=1 ./bootstrap.sh` (it compiles, so it is off by default) |
| `shellcheck` | — | `.github/workflows/lint.yml` (shellcheck + shfmt + `tests/run.sh`) |

## Related

- [bootstrap.md](bootstrap.md) — where the install step sits in the run
- [setup-scripts.md](setup-scripts.md) — what the setup scripts provide instead of the gaps above
- [troubleshooting.md](troubleshooting.md) — install failures (`brew` missing, etc.)
