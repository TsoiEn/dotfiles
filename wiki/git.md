# git

One file so far: `configs/git/.config/git/ignore`, linked to `~/.config/git/ignore` by [`setup-symlinks.sh`](symlinks.md). Identity (`user.name`, `user.email`) is **not** here — [`gclone`](gclone.md) sets it per directory instead.

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

The XDG path is only the default. If a machine has

```bash
git config --get core.excludesFile
```

print anything, git reads **that** file and `~/.config/git/ignore` is silently dead. Nothing in the installer checks this (a `setup-git.sh` for one ignore line is not worth it), so on a machine where the link looks right but nothing is ignored, check that first.

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
