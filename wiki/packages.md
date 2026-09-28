# Packages

`install/<os>.sh` reads a plain-text list and installs whatever is missing.

## Flow

```
bootstrap.sh
└── install/macos.sh  (or install/arch.sh)
    └── install/common.sh
        ├── read_package_list <file>
        └── install_brew_packages / install_arch_packages
```

Both OS scripts are near-identical (resolve `DOTFILES_ROOT`, source `common.sh`, init logging, install one list) — deduplication is Phase 5.

## List format

`install/packages/brew.txt` and `arch.txt` — one package per line:

```txt
# Core tools          ← comments allowed (full-line or trailing)
neovim
tmux
cask:ghostty          ← brew only: 'cask:' prefix installs a cask
```

`read_package_list` strips everything after `#`, trims whitespace, drops empties. Currently **11 shared core packages**: `neovim tmux git zsh fzf ripgrep zoxide yazi eza lazygit lazydocker`.

## Install behavior (idempotent)

**Arch** — uses `paru` when available (AUR support), otherwise `pacman` via `run_as_root` (sudo). Each package is first checked with `pacman -Qi`; installed ones are logged as skipped.

**macOS** — `brew list --formula` / `--cask` greps decide skip vs install; `cask:` prefixed entries become `brew install --cask`.

Flags: `PACMAN_FLAGS`/`PARU_FLAGS` default to `--needed --noconfirm`, `BREW_FLAGS` is empty — all overridable via environment.

## Known gaps

Not installed by any list (relevant when reading the setup scripts):

| Missing | Consequence | Covered by |
|---|---|---|
| `oh-my-zsh` + zsh plugins | zsh config errors on fresh machines | Phase 3 |
| `tpm` | tmux would have no plugin manager | `scripts/setup-tmux.sh` |
| Ghostty | `cask:ghostty` is commented out in `brew.txt` | manual, or uncomment + re-run |
| Homebrew itself / Xcode CLT | fresh macOS dies at `require_command brew` | Phase 5 |
| nvim formatters/linters | — | mason inside Neovim (`mason-tool-installer`) |
| `shellcheck` | no linting of these scripts yet | Phase 6 CI |

## Related

- [bootstrap.md](bootstrap.md) — where the install step sits in the run
- [setup-scripts.md](setup-scripts.md) — what the setup scripts provide instead of the gaps above
- [troubleshooting.md](troubleshooting.md) — install failures (`brew` missing, etc.)
