#!/usr/bin/env bash
#
# setup-claude.sh — link the repo's Claude Code config into ~/.claude.
#
# Why this is NOT in setup-symlinks.sh's LINK_MAP:
#
#   1. ~/.claude cannot be linked as one directory. It mixes authored config
#      (CLAUDE.md, skills/, agents/, commands/) with machine-local runtime
#      state (projects/, sessions/, history.jsonl, cache/, plugins/,
#      shell-snapshots/, telemetry/, settings.json). Linking the whole tree
#      would drag this machine's history into the repo.
#   2. ~/.claude/skills also holds plugin-managed content (skills/synced),
#      so the skills DIRECTORY must stay real — only each authored skill
#      inside it is linked.
#   3. The authored set is open-ended. Instead of one LINK_MAP line per
#      skill, FANOUT_DIRS below is globbed, so dropping a new directory into
#      configs/claude/.claude/skills/ and re-running bootstrap links it with
#      no edit to any script.
#
# Per entry, the same contract as setup-symlinks.sh:
#   1. validate ALL sources first (never touch $HOME on a broken repo)
#   2. already a symlink into this repo  -> skip (idempotent re-run)
#   3. something else exists there       -> backup_path, then link
#   4. nothing exists                    -> mkdir -p parent, link
#
# Claude Code itself is never installed here: an absent `claude` CLI is
# reported and the links are made anyway, so provisioning a machine before
# installing the CLI still works.
#
# Plugins are the one part that is NOT a symlink. They live in
# ~/.claude/plugins (a git clone per marketplace) and are recorded in
# ~/.claude/settings.json under `enabledPlugins` — both machine-local, so the
# repo keeps the plugin LIST and lets the `claude` CLI reproduce the state:
#
#   claude plugin marketplace add <source>
#   claude plugin install <plugin>@<marketplace>
#
# This needs network, so every plugin step warns instead of dying: a machine
# provisioned offline still gets a complete set of symlinks.
#
# Standalone use:  bash scripts/setup-claude.sh
# Env overrides:   DOTFILES_ROOT, LOG_DIR, LOG_FILE, BACKUP_DIR, HOME,
#                  CLAUDE_HOME, DOTFILES_SKIP_PLUGINS, CLAUDE_PLUGINS_YES

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${DOTFILES_ROOT:-}" ]]; then
  DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  export DOTFILES_ROOT
fi

# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR/utils.sh"
# shellcheck source=scripts/backup.sh
source "$SCRIPT_DIR/backup.sh"

# Same default as bootstrap.sh:14 so standalone runs work too.
BACKUP_DIR="${BACKUP_DIR:-$DOTFILES_ROOT/backups}"
export BACKUP_DIR

if [[ -z "${LOG_FILE:-}" ]]; then
  log_init
  export LOG_FILE
fi

# ---------------------------------------------------------------------------
# What gets linked
# ---------------------------------------------------------------------------

# Source tree in this repo.
CLAUDE_SRC="$DOTFILES_ROOT/configs/claude/.claude"

# Destination. Overridable so the test suite can point at a sandbox.
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

# Generated settings file that fences the plugins below out of the 99 Neovim
# plugin. See write_99_settings. Overridable for the same reason.
NINETY_NINE_SETTINGS="${NINETY_NINE_SETTINGS:-$HOME/.config/99/claude-settings.json}"

# Linked whole, by name, relative to CLAUDE_SRC -> CLAUDE_HOME.
DIRECT_LINKS=(
  "CLAUDE.md"
)

# Linked per-child: every entry inside these is linked individually, leaving
# the containing directory real so plugin-managed siblings survive.
FANOUT_DIRS=(
  "skills"
  "agents"
  "commands"
)

# Plugins to install, as "plugin|marketplace|source".
#
#   plugin       the plugin's own name, as its marketplace.json lists it
#   marketplace  the marketplace's `name`, which is NOT always the repo name
#   source       owner/repo, a git/https URL, or a local path
#
# Only the official marketplace is registered automatically, so a third-party
# plugin needs its marketplace added first — hence all three fields.
#
# Verify a new entry before adding it, since a plugin can ship hooks that run
# on every session:
#
#   curl -s https://raw.githubusercontent.com/<owner>/<repo>/HEAD/.claude-plugin/marketplace.json
#
# `name` in that file is the marketplace field; `plugins[].name` is the plugin.
PLUGINS=(
  "ponytail|ponytail|DietrichGebert/ponytail"
  "graphify|graph-plugins|Marinski/graph-plugins"
  "agent-skills|addy-agent-skills|addyosmani/agent-skills"
  "claude-mem|thedotmack|thedotmack/claude-mem"
)

LINKED=0
SKIPPED=0
BACKED_UP=0

# ---------------------------------------------------------------------------
# Path helpers
#
# Duplicated from setup-symlinks.sh on purpose: that script runs `main` at
# load time, so it cannot be sourced, and every setup script in this repo is
# standalone. Keep the two copies in step.
# ---------------------------------------------------------------------------

# _phys_path <path> — physical (symlink-resolved) path of an existing file
# or directory.
_phys_path() {
  local p="$1" dir
  if [[ -d "$p" ]]; then
    (cd "$p" && pwd -P)
    return 0
  fi
  dir="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s' "$dir" "$(basename "$p")"
}

# _link_points_into <symlink> <physical-root>
# Success when <symlink> exists and its ultimate destination lives under
# <physical-root>.
_link_points_into() {
  local link="$1" root="$2" dest dir
  [[ -L "$link" ]] || return 1

  dest="$(readlink "$link")"
  case "$dest" in
    /*) ;;
    *) dest="$(cd "$(dirname "$link")" 2>/dev/null && pwd -P)/$dest" || return 1 ;;
  esac

  if [[ -d "$dest" ]]; then
    dest="$(cd "$dest" 2>/dev/null && pwd -P)" || return 1
  else
    dir="$(cd "$(dirname "$dest")" 2>/dev/null && pwd -P)" || return 1
    dest="$dir/$(basename "$dest")"
  fi

  [[ "$dest" == "$root"/* ]]
}

# ---------------------------------------------------------------------------
# link_one <source> <absolute-dest>
# ---------------------------------------------------------------------------
link_one() {
  local src="$1" dest="$2"

  if _link_points_into "$dest" "$DOTFILES_PHYS"; then
    log_info "already linked: $dest"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    backup_path "$dest"
    BACKED_UP=$((BACKED_UP + 1))
  fi

  local src_phys
  src_phys="$(_phys_path "$src")" || die "cannot resolve source: $src"

  ensure_dir "$(dirname "$dest")"
  ln -s "$src_phys" "$dest" || die "failed to link: $dest -> $src_phys"

  log_success "linked: $dest -> $src_phys"
  LINKED=$((LINKED + 1))
}

# ---------------------------------------------------------------------------
# collect_pairs — build PAIRS as "source|absolute-dest", resolving the globs.
#
# A FANOUT_DIR with no children is not an error: an empty agents/ or
# commands/ (just a .gitkeep) simply contributes nothing.
# ---------------------------------------------------------------------------
PAIRS=()

collect_pairs() {
  local name d child base

  for name in "${DIRECT_LINKS[@]}"; do
    if [[ -e "$CLAUDE_SRC/$name" ]]; then
      PAIRS+=("$CLAUDE_SRC/$name|$CLAUDE_HOME/$name")
    else
      log_warn "skipping absent $name in configs/claude/.claude"
    fi
  done

  for d in "${FANOUT_DIRS[@]}"; do
    [[ -d "$CLAUDE_SRC/$d" ]] || continue
    for child in "$CLAUDE_SRC/$d"/*; do
      # Unmatched glob yields the literal pattern — skip it.
      [[ -e "$child" ]] || continue
      base="$(basename "$child")"
      # .gitkeep only exists to keep an empty dir in Git; never link it.
      [[ "$base" == ".gitkeep" ]] && continue
      PAIRS+=("$child|$CLAUDE_HOME/$d/$base")
    done
  done
}

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------

# _json_has_name <json> <name> — true when the JSON holds "name": "<name>".
# Tolerant of spacing so it survives a formatting change, and keeps this
# script free of a jq dependency.
_json_has_name() {
  printf '%s' "$1" | grep -qE "\"name\"[[:space:]]*:[[:space:]]*\"$2\""
}

# ---------------------------------------------------------------------------
# setup_plugins — add each marketplace, then install each plugin.
#
# Both steps are skipped when already done, so a re-run is quiet and offline
# re-runs of an already-provisioned machine cost nothing.
#
# Nothing here dies. A plugin is an enhancement; a failed clone must not take
# the rest of bootstrap down with it.
# ---------------------------------------------------------------------------
setup_plugins() {
  if [[ -n "${DOTFILES_SKIP_PLUGINS:-}" ]]; then
    log_info "DOTFILES_SKIP_PLUGINS set — skipping plugins"
    return 0
  fi

  if [[ ${#PLUGINS[@]} -eq 0 ]]; then
    return 0
  fi

  if ! command_exists claude; then
    log_warn "claude CLI not on PATH — skipping ${#PLUGINS[@]} plugin(s)"
    return 0
  fi

  log_info "Installing Claude Code plugins"

  # One query each, reused for every entry, instead of one per plugin.
  local have_markets have_plugins
  have_markets="$(claude plugin marketplace list --json 2>/dev/null || true)"
  have_plugins="$(claude plugin list --json 2>/dev/null || true)"

  # Installing a plugin whose marketplace declares a command needs -y, which
  # accepts that command unread. Bootstrap is run by a person at a terminal,
  # so the default is to let the CLI show the command and ask. Set
  # CLAUDE_PLUGINS_YES=1 only for an unattended run whose every source above
  # you trust.
  local yes_flag=()
  if [[ -n "${CLAUDE_PLUGINS_YES:-}" ]]; then
    yes_flag=(--yes)
  fi

  local installed=0 present=0 failed=0
  local entry plugin market source rest

  for entry in "${PLUGINS[@]}"; do
    plugin="${entry%%|*}"
    rest="${entry#*|}"
    market="${rest%%|*}"
    source="${rest#*|}"

    # "$rest" without a separator means only two fields were given, which
    # would otherwise parse as market == source.
    if [[ -z "$plugin" || -z "$market" || -z "$source" ||
      "$rest" != *"|"* || "$source" == *"|"* ]]; then
      log_warn "malformed PLUGINS entry, expected 'plugin|marketplace|source': $entry"
      failed=$((failed + 1))
      continue
    fi

    if _json_has_name "$have_plugins" "$plugin"; then
      log_info "plugin already installed: $plugin"
      present=$((present + 1))
      continue
    fi

    if _json_has_name "$have_markets" "$market"; then
      log_info "marketplace already added: $market"
    elif claude plugin marketplace add "$source" >/dev/null 2>&1; then
      log_success "marketplace added: $market ($source)"
      have_markets="$(claude plugin marketplace list --json 2>/dev/null || true)"
    else
      log_warn "could not add marketplace $market from $source — skipping $plugin"
      failed=$((failed + 1))
      continue
    fi

    # The marketplace's own name is what install resolves against, so a
    # repo whose marketplace is named differently still works.
    if claude plugin install "$plugin@$market" "${yes_flag[@]}"; then
      log_success "plugin installed: $plugin@$market"
      installed=$((installed + 1))
    else
      log_warn "failed to install $plugin@$market — install it by hand with: claude plugin install $plugin@$market"
      failed=$((failed + 1))
    fi
  done

  log_success "plugins: $installed installed, $present already present, $failed failed"

  if [[ $installed -gt 0 ]]; then
    log_info "restart Claude Code to load newly installed plugins"
  fi
}

# ---------------------------------------------------------------------------
# write_99_settings — fence the plugins above out of the 99 Neovim plugin
# (ThePrimeagen/99), so they apply to the interactive CLI only.
#
# 99 shells out to the very same binary:
#
#   claude --dangerously-skip-permissions --model <m> --print <query>
#
# as the same user, against the same ~/.claude, so it inherits every
# user-scope plugin. That is the wrong contract for it. 99 injects a
# <TEMP_FILE> path, tells the model to write its answer there in a strict
# format, then pastes that file over your visual selection with nobody in the
# loop. A plugin hook, or a skill that fires and adds prose, either corrupts
# the buffer or fails the read with "unable to retrieve response from temp
# file". Interactive sessions have a human reading every turn; 99 does not.
#
# `enabledPlugins` resolves user < project < local < flag, so naming each
# plugin false in a --settings file beats the user-scope enablement, for that
# one invocation only.
#
# GENERATED from $PLUGINS, never hand-written: a denylist kept by hand would
# silently leak every newly added plugin into 99.
#
# --bare looks like the obvious alternative and is not. It skips all hooks,
# but it also reads auth strictly from ANTHROPIC_API_KEY or apiKeyHelper and
# never touches OAuth or the keychain, so it breaks 99 outright on a
# subscription login.
# ---------------------------------------------------------------------------
write_99_settings() {
  local dest="$NINETY_NINE_SETTINGS"
  local body="" entry plugin rest market

  # ${PLUGINS[@]+...} because bash 3.2 — the macOS system bash — treats
  # "${empty[@]}" as an unbound variable under `set -u`. An empty PLUGINS
  # must still produce a valid fence, so the loop cannot just be skipped.
  for entry in ${PLUGINS[@]+"${PLUGINS[@]}"}; do
    plugin="${entry%%|*}"
    rest="${entry#*|}"
    market="${rest%%|*}"
    # Same shape check as setup_plugins; a bad line is simply not fenced.
    [[ -n "$plugin" && -n "$market" && "$rest" == *"|"* ]] || continue
    [[ -n "$body" ]] && body+=","
    body+=$'\n    "'"$plugin@$market"'": false'
  done

  [[ -n "$body" ]] && body+=$'\n  '

  local content="{
  \"enabledPlugins\": {$body}
}"

  # Byte-identical rewrite is skipped so a re-run leaves the mtime alone.
  if [[ -f "$dest" && "$(cat "$dest" 2>/dev/null)" == "$content" ]]; then
    log_info "99 plugin fence already current: $dest"
    return 0
  fi

  ensure_dir "$(dirname "$dest")"

  # Never fatal: without this file 99 still works, it just inherits plugins.
  if printf '%s\n' "$content" >"$dest" 2>/dev/null; then
    log_success "99 plugin fence written: $dest (${#PLUGINS[@]} plugin(s) disabled for 99)"
  else
    log_warn "could not write 99 plugin fence: $dest"
  fi
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  if [[ -z "${HOME:-}" ]]; then
    die "HOME is not set"
  fi

  if [[ ! -d "$CLAUDE_SRC" ]]; then
    die "source missing — repo incomplete: $CLAUDE_SRC"
  fi

  DOTFILES_PHYS="$(_phys_path "$DOTFILES_ROOT")" ||
    die "cannot resolve DOTFILES_ROOT: $DOTFILES_ROOT"

  if command_exists claude; then
    log_info "Claude Code found: $(command -v claude)"
  else
    log_warn "claude CLI not on PATH — linking config anyway"
  fi

  collect_pairs

  # An empty authored set is not an error — the plugin phase still runs.
  if [[ ${#PAIRS[@]} -eq 0 ]]; then
    log_warn "nothing to link under $CLAUDE_SRC"
  else
    log_info "Linking Claude Code config into $CLAUDE_HOME"

    # Phase 1: validate every source BEFORE modifying $CLAUDE_HOME.
    local pair src
    for pair in "${PAIRS[@]}"; do
      src="${pair%%|*}"
      [[ -e "$src" ]] || die "source missing — repo incomplete: $src"
    done

    # Phase 2: link
    local dest
    for pair in "${PAIRS[@]}"; do
      src="${pair%%|*}"
      dest="${pair#*|}"
      link_one "$src" "$dest"
    done

    log_success "claude: $LINKED linked, $SKIPPED already linked, $BACKED_UP backed up"
  fi

  # Phase 3: plugins — after the links, so a plugin that reads CLAUDE.md or an
  # authored skill sees it already in place.
  setup_plugins

  # Phase 4: the 99 fence. Depends only on $PLUGINS, so it is written even
  # when the installs were skipped or the CLI is absent — the list is the
  # same either way.
  write_99_settings

  local session
  session="$(backup_session_dir)"
  if [[ -n "$session" ]]; then
    log_info "previous configs saved to: $session"
  fi
}

main "$@"
