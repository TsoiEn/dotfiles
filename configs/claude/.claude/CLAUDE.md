# Global instructions

## This config is a symlink into a dotfiles repo

`~/.claude/CLAUDE.md`, `~/.claude/skills/*`, `~/.claude/agents/*` and
`~/.claude/commands/*` are symlinks into `~/Development/Personal/dotfiles`
(`configs/claude/.claude/`). Editing them edits that repo, so a change is a
tracked, reviewable change — mention it when you make one, and don't replace a
symlink with a regular file.

Everything else in `~/.claude` is machine-local runtime state and is not
tracked.

## Skills

Global skills are on-demand: read the one that fits the task rather than
assuming its rules apply everywhere. `commit-log` governs a repository's
`commit.md` file and nothing else.
