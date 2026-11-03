# Claude Code config

Global Claude Code config — `CLAUDE.md`, skills, subagents and slash commands — lives in this repo at `configs/claude/.claude/` and is symlinked into `~/.claude` by [`scripts/setup-claude.sh`](../scripts/setup-claude.sh).

The point is portability: a skill written once is available in **every** directory on the machine, and `./bootstrap.sh` on a new machine reproduces the whole set.

## Why `~/.claude` is not in `LINK_MAP`

Every other config in this repo is one directory-level link in [`setup-symlinks.sh`](symlinks.md). Claude Code can't be, for three reasons:

1. **`~/.claude` is not purely config.** It mixes authored files with machine-local runtime state — `projects/`, `sessions/`, `history.jsonl`, `cache/`, `shell-snapshots/`, `plugins/`, `telemetry/`, and a `settings.json` that records per-model state. Linking the directory would drag one machine's history into the repo.
2. **`skills/` has a non-repo tenant.** Plugin-managed skills land in `~/.claude/skills/synced/`. The `skills` directory itself must stay a real directory so that content survives; only each authored skill *inside* it is linked.
3. **The authored set is open-ended.** One `LINK_MAP` line per skill would mean editing a script every time a skill is added.

So `setup-claude.sh` links a **fan-out**: each child of `skills/`, `agents/` and `commands/` individually, plus `CLAUDE.md` as a single file.

## What gets linked

| Source (`configs/claude/.claude/`) | Target | How |
|---|---|---|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | direct |
| `skills/<name>/` | `~/.claude/skills/<name>` | fan-out, per child |
| `agents/<name>.md` | `~/.claude/agents/<name>.md` | fan-out, per child |
| `commands/<name>.md` | `~/.claude/commands/<name>.md` | fan-out, per child |

Untouched: everything else in `~/.claude`, including `skills/synced/` and `settings.json` — though the plugin phase below asks the `claude` CLI to write to both.

`.gitkeep` is never linked — it only exists so Git tracks an otherwise empty `agents/` and `commands/`.

## Contract

Identical to `setup-symlinks.sh`, per entry:

1. Validate **all** sources first — a partial checkout never half-links `~/.claude`.
2. Already a symlink into this repo → skip (`already linked`).
3. Something else there → [`backup_path`](backups.md), then link.
4. Nothing there → `mkdir -p` the parent, then link.

An absent `claude` CLI warns and links anyway, so a machine can be provisioned before Claude Code is installed. An empty fan-out directory is not an error.

## Adding a skill

```bash
mkdir -p configs/claude/.claude/skills/my-skill
$EDITOR configs/claude/.claude/skills/my-skill/SKILL.md
bash scripts/setup-claude.sh
```

No script edit — the glob picks it up. `SKILL.md` needs YAML frontmatter with `name` and `description`; the description is what Claude matches against to decide the skill is relevant, so write it as trigger conditions, not as a summary.

Subagents (`agents/*.md`) and slash commands (`commands/*.md`) work the same way.

## Plugins

Plugins are the one part of this config that is **not** a symlink. A plugin is a git clone under `~/.claude/plugins/marketplaces/<marketplace>/`, and the fact that it is enabled is recorded in `~/.claude/settings.json` under `enabledPlugins` — both machine-local, neither trackable here.

So the repo keeps the **list** and lets the CLI reproduce the state. `PLUGINS` in [`setup-claude.sh`](../scripts/setup-claude.sh) holds one `plugin|marketplace|source` line per plugin, and the script runs the two commands `/plugin` runs interactively:

```bash
claude plugin marketplace add <source>
claude plugin install <plugin>@<marketplace>
```

### Why all three fields

Only `claude-plugins-official` is registered automatically; everything else needs its marketplace added first. And a marketplace's **name** is not always its repo name — `thedotmack/claude-mem` publishes a marketplace called `thedotmack`, and `addyosmani/agent-skills` publishes one called `addy-agent-skills`. `install` resolves against the name, `add` against the source, so both are recorded.

### Current set

| Plugin | Marketplace | Source |
|---|---|---|
| `ponytail` | `ponytail` | `DietrichGebert/ponytail` |
| `graphify` | `graph-plugins` | `Marinski/graph-plugins` |
| `agent-skills` | `addy-agent-skills` | `addyosmani/agent-skills` |
| `claude-mem` | `thedotmack` | `thedotmack/claude-mem` |

`graphify` here is a third-party wrapper: upstream Graphify ships as the `graphifyy` PyPI package plus a `graphify install` step, not as a plugin, so the plugin only drives a CLI that must be installed separately.

### Adding one

Read the marketplace manifest first — a plugin can ship hooks that run on every session, and `ponytail` does:

```bash
curl -s https://raw.githubusercontent.com/<owner>/<repo>/HEAD/.claude-plugin/marketplace.json
```

`name` in that file is the marketplace field; `plugins[].name` is the plugin. Add the line to `PLUGINS` and re-run the script.

### Failure behaviour

Nothing in the plugin phase dies:

| Condition | Result |
|---|---|
| `claude` not on PATH | warn, skip all plugins, links still made |
| marketplace clone fails (offline) | warn, skip that plugin, continue |
| install fails | warn with the by-hand command, continue |
| already installed | skip, no network call |
| malformed `PLUGINS` entry | warn, continue |

That is deliberate: a plugin is an enhancement, and bootstrap on a machine with no network must still produce a complete set of symlinks. Re-running after the network is back picks up what was missed.

### `-y` is not the default

A marketplace can declare a **command** that runs as part of an install, and `--yes` accepts it unread. Bootstrap is run by a person at a terminal, so the default lets the CLI print the command and ask. `CLAUDE_PLUGINS_YES=1` opts into accepting it for an unattended run — only worth setting if every source in `PLUGINS` is trusted.

### Fencing plugins out of 99

The `99` Neovim plugin ([`99.lua`](../configs/nvim/.config/nvim/lua/tsoien/plugins/99.lua)) shells out to the same binary:

```lua
{ "claude", "--dangerously-skip-permissions", "--model", context.model, "--print", query }
```

Same user, same `~/.claude`, so it inherits every user-scope plugin. That is the wrong contract for it. 99 injects a `<TEMP_FILE>` path, tells the model to write its answer there in a strict format, then pastes that file over your visual selection — nobody reviews the turn. A plugin hook, or a skill that fires and adds prose, either corrupts the buffer or fails the read with `unable to retrieve response from temp file`. Interactive sessions have a human reading every turn; 99 does not.

`enabledPlugins` resolves **user < project < local < flag**, so a `--settings` file naming each plugin `false` beats the user-scope enablement for that one invocation. `write_99_settings` generates it at `~/.config/99/claude-settings.json`:

```json
{
  "enabledPlugins": {
    "ponytail@ponytail": false,
    "graphify@graph-plugins": false,
    "agent-skills@addy-agent-skills": false,
    "claude-mem@thedotmack": false
  }
}
```

and `99.lua` passes it through `provider_extra_args`, guarded, because `claude --settings <missing>` is a **hard error** — a machine that has not bootstrapped yet must get no flag at all:

```lua
provider_extra_args = (function()
  local fence = vim.fn.expand("~/.config/99/claude-settings.json")
  if vim.uv.fs_stat(fence) then
    return { "--settings", fence }
  end
  return {}
end)(),
```

The file is **generated from `PLUGINS`**, never hand-written. A denylist kept by hand would silently leak every newly added plugin into 99; generating it means one source of truth. Re-running the script after editing `PLUGINS` re-fences.

To let one plugin through to 99 — `ponytail` is the only plausible candidate, since a style constraint is the kind of thing that lands in a single turn — flip its line to `true` by hand and it will be overwritten on the next run, or special-case it in `write_99_settings`.

#### Why not `--bare`

`--bare` skips all hooks in one flag, which looks ideal, but it reads auth **strictly** from `ANTHROPIC_API_KEY` or `apiKeyHelper` and never touches OAuth or the keychain. On a subscription login that breaks 99 outright. It also disables CLAUDE.md auto-discovery.

### Opting out

```bash
DOTFILES_SKIP_PLUGINS=1 bash scripts/setup-claude.sh   # links + 99 fence, no installs
```

The fence is still written, since it depends only on the `PLUGINS` list and not on anything being installed.

## Shipped skills

### `commit-log`

Maintains a repository's `commit.md` — exactly one proposed commit message for the current branch, in Conventional Commits form. Replaces the entry on a branch switch rather than appending, and never creates a Git commit unless asked.

Originally a project-local `AGENTS.md` with `test(app-e2e)` hardcoded. Made global by resolving the convention per repository instead:

1. `.claude/commit-log.json` in the repo, if present:
   ```json
   { "type": "test", "scope": "app-e2e", "file": "commit.md" }
   ```
2. otherwise the dominant `type(scope):` pattern in that repo's `git log`;
3. otherwise plain Conventional Commits, type chosen to match the change.

So the repo it came from behaves as before via (2) — its history is already all `test(app-e2e)` — while any other repo gets its own convention.

## Other agent tools

The ruleset is agent-neutral prose. To expose it to a tool that reads `AGENTS.md`, link the skill body rather than copying it:

```bash
ln -s ~/.claude/skills/commit-log/SKILL.md <repo>/AGENTS.md
```

`opencode` and `gemini` are installed on this machine but are not wired up here — their global config lives in `~/.config/opencode/` and `~/.gemini/`, neither of which has a drop-in skills directory.

## Operating

```bash
bash scripts/setup-claude.sh          # standalone, idempotent
CLAUDE_HOME=/tmp/sandbox/.claude bash scripts/setup-claude.sh   # dry target
```

Env overrides: `DOTFILES_ROOT`, `LOG_DIR`, `LOG_FILE`, `BACKUP_DIR`, `HOME`, `CLAUDE_HOME`, `DOTFILES_SKIP_PLUGINS`, `CLAUDE_PLUGINS_YES`, `NINETY_NINE_SETTINGS`.

To unlink one skill: `rm ~/.claude/skills/<name>` — removes the symlink only, the repo copy stays.
