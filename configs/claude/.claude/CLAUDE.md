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

## graphify

When a repo has `graphify-out/graph.json`, consult it before editing shared
code: `graphify affected "<symbol>"` lists every caller with `file:line`, and
`graphify query "<question>"` returns structure instead of whole files. Run
`graphify update` when the graph looks stale — it drifts after a refactor that
deletes code, and a stale graph answers worse than no graph.

Inert in repos with no `graphify-out/`. The command is `graphify`; the package
is `graphifyy`.

Skip it in the `99` Neovim plugin: 99 replaces the selection and nothing else,
so a caller list is unusable there and `graphify update` is a reindex inside a
one-shot request. (99 fences out the plugin, but still loads this file.)
