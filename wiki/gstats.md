# gstats

`configs/myscripts/.config/myscripts/gstats.sh` → linked to `~/.config/myscripts/gstats.sh`, aliased to **`gstats`** in [`25-aliases.zsh`](../configs/zsh/.config/zshrc/25-aliases.zsh).

One `git status` for every repo under your development roots.

## The problem

Work is spread over a dozen clones under `~/Development`, and the things that bite are the ones no single repo can tell you about: the branch left dirty on Friday, the three commits that never got pushed, the repo whose upstream moved on without you. Finding them means `cd`-ing through every directory in turn and running `git status` by hand.

`gstats` walks the roots once and prints one table. **By default only repos that want something from you are listed** — `-a` adds the clean ones.

## What it looks like

```
$ gstats
repo                       branch   sync   changes  last
Personal/dotfiles          main            ~1 ?1    11m
Work/frontend-monorepo     develop         *1       1d
Work/philhealthExtraction  master   local  ?10      -
Work/patientCreation       master   local  ?8       -
10 repos · 5 with changes · 0 unpushed
(ahead/behind as of the last fetch — gstats -f to refresh)
```

Newest activity first, so the repo you are actually working in is the top row.

## Columns

| Column | Meaning |
|---|---|
| `repo` | Path relative to the root it was found under, so `Personal/x` and `Work/x` stay distinct. Over-long paths are truncated from the **left** (`…tail`) — the distinctive end survives. |
| `branch` | Current branch, or `detached` |
| `sync` | `^N` ahead · `vN` behind · `local` no upstream configured · `gone` upstream branch deleted · blank in sync |
| `changes` | `+`staged `~`unstaged `?`untracked `!`conflicts `*`stashes |
| `last` | Age of the last commit (`2h`, `3d`, `5w`, `3mo`); `-` for a repo with no commits yet |

A repo is listed when it has any changes, any sync state, or a detached HEAD. Clean and in sync means silent (and dimmed when shown with `-a`).

## Usage

```bash
gstats                     # repos needing attention, newest activity first
gstats -a                  # include clean, fully-pushed repos
gstats -f                  # git fetch everything first (real behind counts)
gstats -s name             # sort by path instead of last-commit time
gstats -r ~/src -r ~/work  # scan these roots instead of the defaults
gstats -d 6                # search deeper below each root
gstats --no-color          # plain output (also honours NO_COLOR)
```

### Fetch or not

Without `-f` **nothing touches the network** — the ahead/behind numbers are whatever your last fetch left behind, which is why a run over 30 repos is instant (~0.4s for 10). A repo whose remote moved since you last fetched will look in sync. The footer says so on every no-fetch run.

`-f` runs `git fetch --all --prune` in every repo, `GSTATS_JOBS` (8) at a time, and is the slow but accurate mode. Fetch failures are deliberately silent — offline, no remote, a key needing a passphrase — the scan then just reports the last known numbers, which is what the default mode does anyway.

## What it skips

- **Pruned directories** — `node_modules`, `vendor`, `.venv`, `venv`, `.cache`, `Library`, `.Trash`, `.terraform`, `target`. Vendored trees hide hundreds of `.git` directories and none of them are yours. Override with `GSTATS_PRUNE`.
- **Submodules** — a `.git` *file* pointing into another repo's `modules/` store. They are the parent's business, they double the table, and every one of them reads "detached".
- **Anything below `.git`** — `find` prunes at `.git` itself, which keeps the object database (where nearly all the inodes are) out of the walk.
- Linked **worktrees** are *not* skipped — they are real working trees with their own state.

## How it works

- **One `git status --porcelain=v2 --branch` per repo** gives branch, upstream, ahead/behind and every file state in a single call. `--no-optional-locks` means a scan never writes to a repo you might have open elsewhere.
- **`gone` vs `local`** — an upstream that is configured but missing from the remote prints a `# branch.upstream` line and *no* `# branch.ab` line. That absence is the only thing distinguishing a deleted upstream from one in sync.
- **Staged and unstaged are counted separately** from the porcelain `XY` field (`X` index, `Y` worktree, `.` unchanged), so one file edited both ways counts in both columns.
- **Rows are joined with US (`0x1f`), not tab.** `IFS` collapses runs of *whitespace* into one delimiter, so a tab-joined row with an empty column silently shifts every field after it.
- **Columns are padded by hand**, not with `printf '%-*s'`, which pads by bytes — one multibyte glyph in a column would shift every row below it.
- Bash 3.2 compatible (stock macOS `/bin/bash`).

## Overrides

| Env var | Default |
|---|---|
| `GSTATS_ROOTS` | `$HOME/Development` (colon-separated) |
| `GSTATS_DEPTH` | `4` |
| `GSTATS_JOBS` | `8` (parallel fetches) |
| `GSTATS_PRUNE` | `node_modules:vendor:.venv:venv:.cache:Library:.Trash:.terraform:target` |
| `NO_COLOR` | unset |

Handy for testing without touching the real tree:

```bash
GSTATS_ROOTS=/tmp/sandbox gstats -a
```

## Related

- [gclone.md](gclone.md) — the other half: cloning with the right identity per directory
- [symlinks.md](symlinks.md) — how `configs/myscripts/` reaches `~/.config/myscripts`
