# playwrightIni

The QA output layer of `playwright-automation`, packaged so the next site to be
automated gets the same terminal documentation without rebuilding it: one way
into the suite, and a Cypress-style spec table at the end of every run.

It comes in both languages a QA team gets asked for — **Python + pytest** and
**TypeScript + @playwright/test** — with the same flags and the same table, so
one suite reads like the other.

Each script prints its own `--help`, refuses to overwrite, and takes `--force`
where replacing is meaningful.

## Python (pytest)

Run them in order, from inside the new repo (or pass its path):

```bash
~/.config/myscripts/playwrightIni/uv-setup.sh        # uv: check, install if missing
~/.config/myscripts/playwrightIni/runner-init.sh     # -> scripts/runner.sh (+ .env.example stub)
~/.config/myscripts/playwrightIni/summary-init.sh    # -> src/utils/terminal_summary.py + conftest.py hooks
~/.config/myscripts/playwrightIni/selftest.sh        # optional: proves the kit still works
```

| Path | From | What it is |
| ---- | ---- | ---------- |
| `scripts/runner.sh` | `assets/runner.sh` | the single entry point: `--setup`, `--env`, `--headed`, `--no-video`, `--retries N`, `-n N\|auto`, `--collect`, `--loop N`, `--test NAME`, `-- <pytest args>` |
| `.env.example` | inline stub | only when the repo has neither it nor `.env`, which `runner.sh` requires |
| `src/utils/terminal_summary.py` | `assets/terminal_summary.py` | the table and the live log, verbatim from `playwright-automation` |
| `conftest.py` (repo root) | `assets/conftest_summary.py` | the render function and the four pytest hooks that drive it |

The hooks go in the **root** `conftest.py`, not `tests/conftest.py`: pytest
loads it for every run, pytest calls every implementation of a hook, so the
suite's own conftest is left alone. `summary-init.sh` appends to an existing
root conftest and refuses only when that file already defines one of the same
hooks by hand.

## TypeScript (@playwright/test)

Start the suite with Playwright's own scaffolder, then the same two steps:

```bash
npm init playwright@latest                            # once, in an empty repo
~/.config/myscripts/playwrightIni/ts-runner-init.sh   # -> scripts/runner.sh (+ playwright.config.ts, .env.example)
~/.config/myscripts/playwrightIni/ts-summary-init.sh  # -> src/utils/qaReporter.ts, wired into the config
~/.config/myscripts/playwrightIni/ts-selftest.sh      # optional: proves the kit still works
```

There is no `ts` equivalent of `uv-setup.sh`: Node is not installable in one
safe line (nvm, brew, winget all disagree), so `runner.sh` just says how when
`npm` is missing.

| Path | From | What it is |
| ---- | ---- | ---------- |
| `scripts/runner.sh` | `assets/runner-ts.sh` | the single entry point, with the Python kit's flags |
| `playwright.config.ts` | `assets/playwright.config.ts` | only when the repo has none: the `.env` reader, the per-environment `baseURL`, video/trace/screenshot, `artifacts/`, chromium |
| `.env.example` | inline stub | only when the repo has neither it nor `.env`, which `runner.sh` requires |
| `src/utils/qaReporter.ts` | `assets/qa-reporter.ts` | the table, the live log and the failure output, as a Playwright reporter |

A reporter is not loaded by sitting in the right place, the way a `conftest.py`
is, so `ts-summary-init.sh` has to edit the config: it replaces the
`reporter: 'list'` line this kit writes, and otherwise prints the line to add
by hand rather than guess at a config it did not write.

### What differs from the Python kit, and why

* `-v` is gone: every case is printed as it settles, so there was nothing left
  for it to turn on.
* `--retries N` and `-n N|auto` need no plugins — they are
  `--retries` and `--workers` (`auto` is every core, which Playwright spells
  `100%`; its own default is half of them).
* `--no-video` travels as `PW_VIDEO=off`, because Playwright has no `--video`
  on the command line. That is the one flag that needs the kit's
  `playwright.config.ts`; the rest work against any config.
* A bare unknown word becomes `-g` (a title match), where pytest took `-k`.
* `--collect` is `--list`, `--trace` is native, and a `--trace` of your own
  still wins.
* Playwright runs spec files in parallel, so a spec is closed when the last of
  its own cases settles rather than when the heading changes, and a heading is
  reprinted when the run jumps back to a spec. Under `--workers 1` the screen
  is the Python kit's exactly.
* `qaReporter.ts` prints why a case failed, which on the Python side pytest
  itself still did. Replacing Playwright's `list` reporter means replacing that
  too.
* A case is labelled by its `describe` titles and its own; a spec, by its file.
  `PW_QA_ASCII=1` draws the table without box characters.

## What both kits deliberately leave out

* the CSV/XLSX run reports (`utils.run_report`, `reports/`) — terminal only here
* the `tc_*` markers, `--match` keyword matching and the run order
  (`utils.tc_metadata`, `utils.keyword_select`, `utils.run_order`) — without
  them a case is labelled by its nodeid (Python) or its titles (TypeScript) and
  a spec by its file, and a bare word on the command line becomes a plain
  keyword match
* the `--appointments` load-run flag, which belongs to that one suite

`terminal_summary.py` is a verbatim copy, so its docstrings still mention the
`utils.csv_report` / `utils.run_report` modules that stay behind. Re-copy it
from `playwright-automation` when that file changes; nothing syncs by itself.
`qa-reporter.ts` is a port of it, not a copy — a change to one is not a change
to the other.
