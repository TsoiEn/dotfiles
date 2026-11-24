# ---------- QA terminal summary (playwrightIni) ----------
# A heading and a line per case as the run goes, that spec's own table once the
# run moves on, and one row per spec at the end. The table lives in
# utils/terminal_summary.py; what follows is the few lines pytest insists on
# owning.
#
# Case labels come from the tc_* attributes when a suite hangs them on its
# reports; without them a case is labelled by its nodeid and a spec by its
# file, which is all this needs.

import sys
from pathlib import Path

import pytest

try:
    from utils import terminal_summary
except ModuleNotFoundError:  # src/ is not on sys.path (no editable install)
    sys.path.insert(0, str(Path(__file__).resolve().parent / "src"))
    from utils import terminal_summary

#: The run as it happens (``utils.terminal_summary.LiveLog``), built once the
#: terminal reporter exists. Stays None when pytest runs without one.
_live = None


@pytest.hookimpl(trylast=True)
def pytest_sessionstart(session):
    """Hand the screen to the live log, and take it off pytest."""
    global _live
    reporter = session.config.pluginmanager.get_plugin("terminalreporter")
    if reporter is None:
        return
    # pytest prints a file's path before its first test; the live log heads
    # each spec itself, so that path is one line too many.
    reporter.showfspath = False

    # Flushed per line, because pytest's own per-test output is what used to
    # flush the screen and pytest_report_teststatus below silences it. Without
    # this the run is invisible wherever stdout is a pipe rather than a
    # terminal -- a CI log sits empty for the whole suite, then prints it all
    # at once, which reads as a hung job.
    def write(line, **markup):
        reporter.write_line(line, **markup)
        reporter.flush()

    _live = terminal_summary.LiveLog(
        write, lambda rows: _render_table(reporter, rows)
    )


def pytest_runtest_logreport(report):
    """Every report goes to the live log, which decides what reaches the screen."""
    if _live is not None:
        _live.record(report)


@pytest.hookimpl(hookwrapper=True)
def pytest_report_teststatus(report, config):
    """Silence pytest's own per-test output; the live log prints the run.

    A wrapper rather than an implementation of its own, because the category
    (the first field) is what pytest files the report under -- including the
    separate ``xfailed`` / ``xpassed`` / ``rerun`` buckets the tables are then
    built from. Only the letter and the word, the two fields that reach the
    screen, are dropped.
    """
    outcome = yield
    category, _letter, _word = outcome.get_result()
    outcome.force_result((category, "", ""))


def _render_table(reporter, rows) -> str:
    """The spec table, drawn the way this terminal can draw it."""
    # Unicode box drawing needs an encoding that has the characters; a cp1252
    # console falls back to an ASCII table instead of raising.
    writer_file = getattr(getattr(reporter, "_tw", None), "_file", None)
    return terminal_summary.render(
        rows,
        color=bool(getattr(reporter, "hasmarkup", False)),
        unicode=terminal_summary.supports_unicode(
            getattr(writer_file, "encoding", None)
        ),
    )


def pytest_terminal_summary(terminalreporter):
    """End of run: the last spec's table, then one row per spec of the whole run."""
    tr = terminalreporter
    if _live is None:
        return
    _live.end_spec()
    if not _live.specs:
        return

    tr.section("QA test summary")
    for line in _render_table(tr, _live.specs).splitlines():
        tr.write_line(line)
