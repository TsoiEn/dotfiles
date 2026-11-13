# git

Two files, both linked by [`setup-symlinks.sh`](symlinks.md): `configs/git/.config/git/ignore` → `~/.config/git/ignore`, and `configs/git/.gitconfig` → `~/.gitconfig`. Identity (`user.name`, `user.email`) is in **neither** — [`gclone`](gclone.md) sets it per directory instead.

## What it is

`~/.config/git/ignore` is git's **global excludes file**: patterns that apply to every repo on the machine, on top of each repo's own `.gitignore`. Git reads it at `$XDG_CONFIG_HOME/git/ignore` by default, so no `git config` is needed — creating the file is enough.

Current content: `commit.md`.

## Why `commit.md` is ignored machine-wide

The global [`commit-log`](claude.md) skill writes a `commit.md` at the root of whatever repo it is used in — one proposed commit message for the current branch. It is scratch, not content: the message is meant to end up *in* a commit, never *as* a tracked file.

Since the skill is global, the file appears in every repo, including ones owned by other people. Of git's three exclusion mechanisms, only the global file fits:

| Mechanism | Why not |
|---|---|
| the repo's `.gitignore` | tracked and shared — ignoring a personal scratch file would be a commit in someone else's project |
| `.git/info/exclude` | machine-local but per clone, so it has to be redone in every repo, forever |
| **`~/.config/git/ignore`** | one tracked line here, reproduced by `./bootstrap.sh` on every machine |

A skill cannot do this itself. A skill is prose the model reads; nothing in it stops `git add -A` from staging the file. Exclusion has to come from git.

## Tradeoff

`commit.md` is now invisible to `git status` **everywhere**, including a repo where such a file would be legitimate content. Force it through when that happens:

```bash
git add -f commit.md
```

The same applies to any pattern added here later — the bar for this file is "never a repo's real content", not "usually noise".

## Caveat: `core.excludesFile`

The XDG path is only the default: whatever `git config --get core.excludesFile` prints is what git actually reads, and `~/.config/git/ignore` is then silently dead. This is why `.gitconfig` sets it explicitly — but a machine with the value in a *higher*-precedence place (a repo's own config, `GIT_CONFIG_GLOBAL`) still wins, so on a machine where the link looks right but nothing is ignored, check that first.

## `~/.gitconfig`

Three lines of config and no identity:

```ini
[core]
	excludesFile = ~/.config/git/ignore
[init]
	defaultBranch = main
[include]
	path = ~/.config/git/local
```

- **`excludesFile`** — makes the ignore file above authoritative instead of merely the default (see the caveat).
- **`defaultBranch`** — `main`, so a fresh `git init` matches what every remote here uses.
- **`include`** — `~/.config/git/local` is untracked and absent on a fresh machine, which git ignores silently. It is where machine-local settings belong: a credential helper, a signing key, or a fallback identity.

Two consequences worth knowing:

1. **An existing `~/.gitconfig` is moved into `backups/<timestamp>/` on the first run** — nothing is deleted, but a machine-wide identity that lived there stops applying. Copy what you still want into `~/.config/git/local`:
   ```bash
   cat backups/<timestamp>/.gitconfig >> ~/.config/git/local
   ```
2. **`git config --global …` now writes into this repo**, because `~/.gitconfig` is a symlink to it. That is the point — the setting becomes a tracked change — but identity and tokens must go to `~/.config/git/local` instead, or they end up in a commit.

Identity stays out on purpose: [`gclone`](gclone.md) sets `user.name`/`user.email` per clone from the directory tree it lands in (Personal vs Work), which a global value would only mask.

## Verifying

```bash
git check-ignore -v commit.md
# /Users/<you>/.config/git/ignore:14:commit.md    commit.md
```

`git check-ignore` is authoritative — it names the file and line that matched, so it distinguishes "the global file worked" from "some repo `.gitignore` happened to cover it".

## Adding a pattern

```bash
$EDITOR configs/git/.config/git/ignore
```

No script re-run and no re-link: `~/.config/git/ignore` *is* that file through the symlink, so the edit takes effect immediately — and is a tracked change in this repo.
