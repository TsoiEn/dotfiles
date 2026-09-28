# Symlinks

`scripts/setup-symlinks.sh` wires `configs/` into `$HOME`. It runs first in `bootstrap.sh` and can be run standalone.

## The link map

Six directory-level targets, declared as `repo-relative source | $HOME-relative destination`:

| Source | Target |
|---|---|
| `configs/zsh/.zshrc` | `~/.zshrc` |
| `configs/zsh/.config/zshrc` | `~/.config/zshrc` |
| `configs/nvim/.config/nvim` | `~/.config/nvim` |
| `configs/tmux/.tmux.conf` | `~/.tmux.conf` |
| `configs/tmux/.config/tmuxScript` | `~/.config/tmuxScript` |
| `configs/ghostty/.config/ghostty` | `~/.config/ghostty` |

**Directory-level, not file-level:** each entry links a whole directory (or a single top-level file), so adding a file inside `~/.config/nvim/` requires no changes here. The tradeoff is that merging into a pre-existing real directory is not possible — the directory gets backed up wholesale.

## The algorithm

**Phase 1 — validate.** Every source in the map is checked to exist *before* anything in `$HOME` is touched. A partial checkout fails here with `$HOME` completely untouched.

**Phase 2 — per target:**

1. **Already linked into this repo?** → log `already linked`, skip (this is what makes re-runs no-ops).
2. **Something else exists** (file, directory, foreign symlink, dangling symlink) → [`backup_path`](backups.md), then link.
3. **Nothing exists** → `mkdir -p` the parent, `ln -s`.

Summary line: `symlinks: X linked, Y already linked, Z backed up` (a target can be both "linked" and "backed up" in the same run — the counters are orthogonal), plus a `previous configs saved to:` hint if any backup happened.

## Path canonicalization

Idempotency depends on comparing paths, so both sides are resolved to **physical** paths (`cd … && pwd -P`, which resolves symlinked components):

- `DOTFILES_PHYS` — the repo root as a physical path.
- Each link destination — via `_link_points_into`, which reads the link, absolutizes relative targets against the link's own directory, then canonicalizes.

Consequences:

- Re-running through a symlinked repo path (`/tmp/rp → ~/Development/.../dotfiles`) still reports `already linked` — links are not needlessly backed up and rewritten.
- Links are *created* pointing at the physical source, so the two path forms agree.
- Hand-made **relative** links (e.g. `~/.zshrc → Development/Personal/dotfiles/configs/zsh/.zshrc`) are recognized too.

## Safety rails

- `backup_path` refuses to move anything outside `$HOME` or inside `$DOTFILES_ROOT` — see [backups.md](backups.md).
- Dangling links are handled explicitly (`-e || -L`): a broken link counts as "something exists" and is moved aside, otherwise the subsequent `ln -s` would fail with `File exists`.

## Adding a config

1. Place it in `configs/` following the existing layout (path relative to a fake `$HOME`).
2. Add one line to `LINK_MAP` in `scripts/setup-symlinks.sh`:
   ```bash
   "configs/git/.gitconfig|.gitconfig"
   ```
3. Re-run `bash scripts/setup-symlinks.sh` — validate-first means a typo in the source path fails before `$HOME` changes.

See also [development.md](development.md) for how this is tested.

## Related

- [backups.md](backups.md) — what happens to the old files
- [bootstrap.md](bootstrap.md) — why this runs first
