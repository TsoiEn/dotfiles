# Plan

## Git visualizer

- feature
  - globalized git status
    - so that i know what repo or directory is currently is development or it have any changes that needs to be pushed
  - gstats is the alias

### Status: shipped

`gstats.sh` → `~/.config/myscripts/gstats.sh`, aliased `gstats`.

Scans every repo under `~/Development` and prints one table: branch,
ahead/behind, staged/unstaged/untracked/conflicts/stashes, last-commit age.
Only repos wanting attention are listed (`-a` for all), newest activity
first. No network unless `-f`.

Docs: [wiki/gstats.md](../../wiki/gstats.md)

### Ideas not built

- `--json` output, for piping into a status bar
- a tmux/ghostty status-line summary ("3 dirty, 2 unpushed")
- `gstats --push` to push everything that is only ahead and otherwise clean
