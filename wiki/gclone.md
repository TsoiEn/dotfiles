# gclone

`configs/myscripts/.config/myscripts/gclone.sh` → linked to `~/.config/myscripts/gclone.sh`, aliased to **`gclone`** in [`25-aliases.zsh`](../configs/zsh/.config/zshrc/25-aliases.zsh).

A `git clone` wrapper that picks the GitHub identity from the directory you are standing in.

## The problem

Two accounts share one `HostName github.com`, split by ssh alias in `~/.ssh/config`:

| ssh Host | IdentityFile | Account |
|---|---|---|
| `github.com` | `~/.ssh/id_ed25519` | work |
| `github-personal` | `~/.ssh/id_ed25519_personal` | personal |

A personal repo therefore has to be cloned through `github-personal`, *and* needs the personal `user.name`/`user.email` in its `.git/config` — otherwise commits go out under the work identity. Both are easy to forget and annoying to repair later.

## What it does

```bash
gclone git@github.com:TsoiEn/GoTask.git
```

| cwd | Clone URL | `.git/config` |
|---|---|---|
| under `~/Development/Personal` | `git@github-personal:TsoiEn/GoTask.git` | `[user]` name + email written |
| under `~/Development/Work` | `git@github.com:TsoiEn/GoTask.git` | untouched (inherits global) |
| anywhere else | work host, plus a warning | untouched |

The host you paste never matters — it is normalized to whatever the current directory calls for, in both directions (a `github-personal` URL pasted inside `Work/` becomes `github.com`).

## Accepted inputs

```bash
gclone git@github.com:TsoiEn/GoTask.git          # scp-like
gclone https://github.com/TsoiEn/GoTask          # browser-copied
gclone ssh://git@github.com/TsoiEn/GoTask.git    # ssh://
gclone TsoiEn/GoTask                             # owner/repo shorthand
gclone TsoiEn/GoTask mydir --depth 1             # dest + git args pass through
gclone --dry-run TsoiEn/GoTask                   # print the command, run nothing
```

Anything that is not a recognized GitHub URL — another forge, a local path, an existing directory — is handed to `git clone` unchanged with a warning.

## How it works

- **Account detection** compares `pwd -P` against the physically-resolved roots, so a symlinked `~/Development` still matches. Personal is tested first, so a nested root wins over an enclosing one.
- **The identity is set at clone time** via `git clone -c user.name=… -c user.email=…`, which git writes into the *new* repo's `.git/config`. That is why the script never has to know or guess which directory git chose — `[dest]`, `--separate-git-dir` and friends all keep working.
- **Finding the repo argument** skips flags *and* the values of the git options that take a separate value, so `-b feature/x` is never mistaken for `owner/repo`.
- A failed clone prints a hint pointing at the `Host` entry and its key.
- Bash 3.2 compatible (stock macOS `/bin/bash`).

## Overrides

| Env var | Default |
|---|---|
| `GCLONE_PERSONAL_ROOT` | `$HOME/Development/Personal` |
| `GCLONE_WORK_ROOT` | `$HOME/Development/Work` |
| `GCLONE_PERSONAL_HOST` | `github-personal` |
| `GCLONE_WORK_HOST` | `github.com` |
| `GCLONE_PERSONAL_NAME` | `TsoiEn` |
| `GCLONE_PERSONAL_EMAIL` | `paulanrenz23@gmail.com` |

Handy for testing without touching the real tree:

```bash
GCLONE_PERSONAL_ROOT="$PWD" gclone --dry-run TsoiEn/GoTask
```

## Related

- [symlinks.md](symlinks.md) — how `~/.config/myscripts` gets linked
- [development.md](development.md) — testing conventions
