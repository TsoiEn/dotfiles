---
name: commit-log
description: Maintain a repository's `commit.md` — exactly one proposed commit message per Git branch, in Conventional Commits form. Use whenever code has been added, modified, or removed and the change should be recorded; when asked to write, update, or review a commit message; when asked to commit; or when switching branches leaves a stale entry behind. Infers the repo's own commit type/scope convention instead of assuming one.
---

# commit-log

Keep a single file, `commit.md`, at the repository root holding **one** proposed
commit message for the **current branch** — never a changelog, never a history.

## Before anything else: resolve the convention

This skill is global, so never assume a type or scope. Resolve in this order and
stop at the first hit:

1. **Repo override** — read `.claude/commit-log.json` if present:
   ```json
   { "type": "test", "scope": "app-e2e", "file": "commit.md" }
   ```
   Any key may be omitted. `scope: null` means "no scope".
2. **Repo history** — `git log --pretty=%s -40` and take the dominant
   `type(scope):` pattern. If one scope covers most subjects, that repo has a
   house scope; reuse it. If scopes vary by area, pick the one matching the
   touched area.
3. **Fallback** — plain [Conventional Commits](https://www.conventionalcommits.org):
   pick the `type` that matches what actually changed (`feat`, `fix`, `test`,
   `refactor`, `docs`, `chore`, `build`, `ci`, `perf`, `style`), and a `scope`
   naming the touched package/app/area, or no scope if the change is repo-wide.

State the resolved convention in one line before writing, so a wrong inference
is visible and correctable.

## Workflow

Whenever code changes are made:

1. `git rev-parse --abbrev-ref HEAD` — identify the current branch.
2. Review the branch's changes as a whole: `git diff $(git merge-base HEAD <default-branch>)...HEAD`
   plus the working tree. The entry describes the **branch's purpose**, not the
   last edit.
3. Read the existing `commit.md`, if present.
4. If its entry belongs to the current branch → **update it in place**.
5. If it belongs to another branch → **replace the whole file** with the current
   branch's entry. Never append a second branch.
6. Consolidate related changes into one title and description.
7. Verify the title and description reflect what is actually implemented —
   not what was planned, attempted, or discussed.
8. Confirm the file holds exactly one entry and meets the length guidelines.

Document only implemented changes. If the work isn't in the tree, it isn't in
`commit.md`.

## Commit title

`<type>(<scope>): <concise summary>`

- Follow Conventional Commits; type and scope come from the resolution above.
- Imperative wording ("add", not "added" or "adds").
- Under 72 characters, descriptive, no trailing period.
- Describes the branch's overall purpose, not an individual implementation step.
- Update the title if the branch's purpose changes.

Example: `test(app-e2e): add dashboard walkthrough coverage`

## `commit.md` format

```markdown
## YYYY-MM-DD <branch-name>

**Commit title:** `<type>(<scope>): <concise summary>`

**Description:**

- Summarize the primary feature or coverage added.
- Describe important supporting changes or fixes.
- Mention significant verification results when relevant.
```

Use today's real date. Resolve it from the environment or `date +%F` — never
guess it.

### Description rules

- **2–4 bullets, 50–100 words total.** Each bullet 1–3 concise lines.
- Focus on what changed and why it matters.
- Group related changes into a single bullet.
- Mention only the most important implementation details.
- Include test results only as meaningful evidence of correctness.
- Do not repeat the title in the description.
- Do not list every modified file unless the file list is the point.
- No debugging histories, step-by-step narration, obvious code changes, or
  explanations of routine decisions.
- Do not document unimplemented work.
- If a change can't be summarized concisely, its technical detail belongs in a
  README or technical doc — not here.

## Git rules

- Exactly one proposed commit message per current branch in `commit.md`.
- Replace the previous branch's entry when switching; never append.
- **Do not create Git commits automatically.** Commit only when explicitly asked.
- When asked to commit, use the consolidated title recorded in `commit.md`.
- Before committing, verify the title and description match the intended change.
- Do not add a `Co-Authored-By` trailer for yourself.

**Scope limit:** these rules govern `commit.md` only. They never require
squashing existing commits or rewriting Git history.

## Not a Git repo / detached HEAD

If there's no branch to key the entry to, say so and stop — don't invent a
branch name or write an entry keyed to a commit SHA.
