"""End-of-run QA summary rendered as a Cypress-style spec table.

**Terminal output only.** Nothing here touches ``reports/`` -- the CSV reports
are written by :mod:`utils.csv_report` and are unaffected by this module.

The table groups a run by **spec** (one row per test file) and mirrors the
columns Cypress prints at the end of ``cypress run``::

    ┌──────────────────────────────────────────────────────────────────────┐
    │ Spec                    │        Tests │ Passing │ Failing │ ...      │
    ├──────────────────────────────────────────────────────────────────────┤
    │ ✔  tests/test_sign_in.py   00:09 │   3   │    2    │    –    │ ...    │
    ├──────────────────────────────────────────────────────────────────────┤
    │ ✖  1 of 6 failed (17%)       05:22 │  35   │    9    │    5    │ ...  │
    └──────────────────────────────────────────────────────────────────────┘

``–`` means "none in this column", exactly as Cypress renders it.

Every spec prints its own table as the run moves past it, broken down into the
cases it is made of (:class:`LiveLog`), and the closing table is one row per
spec::

    ┌──────────────────────────────────────────────────────────────────────┐
    │ ✔  Auth / Sign In                   00:09 │  4 │  3 │  – │  – │  1   │
    ├──────────────────────────────────────────────────────────────────────┤
    │   ✔  [AUTH-TS01-TC01] Sign in with correct ...  00:04 │ 1 │ 1 │ – │ – │
    │   ✖  [AUTH-TS01-TC02] Sign in with a bad pa...  00:03 │ 1 │ – │ 1 │ – │
    │   »  [AUTH-TS01-TC03] Password reset link       00:02 │ 1 │ – │ – │ 1 │
    │   –  [AUTH-TS01-TC04] Sign in is rate limited    0ms  │ 1 │ – │ – │ – │
    └──────────────────────────────────────────────────────────────────────┘

The spec row stays as the group header (and carries the totals), the case rows
are indented under it, and the closing totals row covers spec rows only.

Column meanings:

============  ==========================================================
Spec          the test file; ✔ / ✖ is that spec's overall result
(duration)    time spent inside the tests themselves (``call`` phase)
Tests         cases in the row (1 for a case row)
Passing       cases that passed
Failing       cases that failed or errored
Pending       cases marked ``xfail`` -- expected to fail, so not a problem
Skipped       cases skipped at runtime (``pytest.skip`` / skip markers)
============  ==========================================================

Case rows use a finer marker than file rows: ``✔`` passed, ``✖`` failed,
``»`` expected to fail, ``–`` skipped. A file row only distinguishes ✔ / ✖, so
a spec whose cases were all skipped still reads as ✔.

This module deliberately does not import pytest: it consumes any object that
exposes ``nodeid``, ``when``, ``duration``, ``outcome`` and optionally
``wasxfail`` -- which a pytest ``TestReport`` does -- so it can be exercised
(and unit-tested) without starting a test session.
"""

from __future__ import annotations

import shutil
from dataclasses import dataclass

# ---------- outcomes ----------

PASSED = "passed"
FAILED = "failed"
PENDING = "pending"
SKIPPED = "skipped"

# Worst outcome wins. pytest reports one nodeid more than once when, say, a
# test passes in `call` but errors in `teardown` -- that is a failure, not a
# pass, so the higher rank replaces the lower one.
_RANK = {PASSED: 0, SKIPPED: 1, PENDING: 2, FAILED: 3}

# Stats buckets that describe no test result: warnings are diagnostics,
# deselected tests never ran, the empty key holds passed setup/teardown, and a
# "rerun" is a superseded attempt -- pytest-rerunfailures files the attempt
# that settled the case under its real outcome, so counting the discarded ones
# showed a retried case as Skipped (SKIPPED outranks PASSED, and the reruns are
# logged first). The retries are reported by utils.run_report.flakes instead.
_IGNORED_BUCKETS = frozenset({"warnings", "deselected", "rerun", ""})

# Shown in a count column that has nothing in it.
DASH = "\u2013"  # en dash, as Cypress uses

# ---------- geometry ----------

SPEC_HEADER = "Spec"

# Width of the duration column ("02:21" / "41ms", right-aligned).
DUR_WIDTH = 7

# (attribute on SpecResult, column header, width). Each width carries one space
# of padding on either side of the number, so the header's column dividers get
# room to breathe instead of sitting flush against the label.
COUNT_COLUMNS = (
    ("tests", "Tests", 7),
    ("passing", "Passing", 9),
    ("failing", "Failing", 9),
    ("pending", "Pending", 9),
    ("skipped", "Skipped", 9),
)

# Everything in a row except the spec text itself: the two border characters,
# the leading/trailing padding, the marker and the duration/count columns plus
# their separators. A row is therefore ``SPEC_WIDTH + _FIXED_WIDTH`` wide.
_FIXED_WIDTH = 62

# Never squeeze the spec column below this, even in a very narrow terminal.
MIN_SPEC_WIDTH = 28


@dataclass
class SpecResult:
    """One row of the table: a test file, or -- when nested -- one of its cases."""

    name: str
    duration: float = 0.0
    passing: int = 0
    failing: int = 0
    pending: int = 0
    skipped: int = 0

    # 0 for a test file, 1 for one of its cases. Case rows are indented under
    # the file they belong to and are excluded from the closing totals, which
    # would otherwise count every case twice.
    depth: int = 0

    @property
    def tests(self) -> int:
        """Total cases in the row."""
        return self.passing + self.failing + self.pending + self.skipped

    @property
    def ok(self) -> bool:
        """True when nothing in the row failed."""
        return self.failing == 0

    @property
    def outcome(self) -> str:
        """The row's single outcome, worst first.

        A file can hold a mix of outcomes, so this reports the worst one. Case
        rows hold exactly one, which is what lets a case row say *why* it did
        not pass instead of showing a bare tick.
        """
        if self.failing:
            return FAILED
        if self.pending:
            return PENDING
        if self.skipped:
            return SKIPPED
        return PASSED


# ---------- collecting ----------


def outcome_of(report) -> str:
    """Bucket a pytest-style report into one of the four columns.

    ``xfail`` -- an expected failure -- is Cypress's *pending*: the case is
    known to fail, so it is not counted against the run. pytest marks both a
    genuine xfail and an unexpected xpass with ``wasxfail``.
    """
    if getattr(report, "wasxfail", None) is not None:
        return PENDING
    outcome = getattr(report, "outcome", "")
    if outcome == "passed":
        return PASSED
    if outcome in ("failed", "error"):
        return FAILED
    return SKIPPED


def _bump(spec: SpecResult, outcome: str, delta: int) -> None:
    if outcome == PASSED:
        spec.passing += delta
    elif outcome == FAILED:
        spec.failing += delta
    elif outcome == PENDING:
        spec.pending += delta
    else:
        spec.skipped += delta


def collect(reports, *, by: str = "spec") -> list[SpecResult]:
    """Group pytest-style reports into rows, one :class:`SpecResult` each.

    ``by="spec"`` (default) gives one row per test file; ``by="case"`` gives one
    row per test case, named after its nodeid.

    Each nodeid is counted **once**: pytest can emit several reports for the
    same test (setup/call/teardown), and a test that errors while tearing down
    after passing would otherwise be counted twice. The worst outcome wins.

    Durations come from the ``call`` phase only, so the session-scoped login
    fixture is not charged to whichever spec happens to run first.
    """
    by_name: dict[str, SpecResult] = {}
    counted: dict[str, str] = {}  # nodeid -> outcome already counted

    for report in reports:
        nodeid = getattr(report, "nodeid", "") or ""
        if not nodeid:
            continue

        name = nodeid if by == "case" else nodeid.split("::", 1)[0]
        spec = by_name.get(name)
        if spec is None:
            spec = by_name[name] = SpecResult(name=name)

        if getattr(report, "when", "call") == "call":
            spec.duration += float(getattr(report, "duration", 0.0) or 0.0)

        outcome = outcome_of(report)
        previous = counted.get(nodeid)
        if previous is None:
            counted[nodeid] = outcome
            _bump(spec, outcome, 1)
        elif _RANK[outcome] > _RANK[previous]:
            _bump(spec, previous, -1)
            _bump(spec, outcome, 1)
            counted[nodeid] = outcome

    return sorted(by_name.values(), key=lambda s: s.name)


def _reports_from_stats(stats: dict) -> list:
    """Every report in a ``terminalreporter.stats`` mapping, minus the noise."""
    reports = []
    for bucket, bucket_reports in stats.items():
        if bucket in _IGNORED_BUCKETS:
            continue
        reports.extend(bucket_reports or [])
    return reports


def collect_from_stats(stats: dict, *, by: str = "spec") -> list[SpecResult]:
    """Collect straight from a ``terminalreporter.stats`` mapping.

    pytest files reports under one bucket per outcome -- including the separate
    ``xfailed`` / ``xpassed`` buckets it uses for expected failures, which is
    why the buckets are walked generically instead of from a fixed list.
    ``warnings`` and ``deselected`` say nothing about a test's result, and the
    empty key holds passed setup/teardown phases, so all three are skipped.
    """
    return collect(_reports_from_stats(stats), by=by)


# ---------- formatting ----------


def format_duration(seconds: float) -> str:
    """Cypress-style duration: ``41ms`` below a second, ``00:09`` above it."""
    seconds = max(0.0, float(seconds or 0.0))
    if seconds < 1:
        return f"{round(seconds * 1000)}ms"
    minutes, secs = divmod(int(seconds), 60)
    return f"{minutes:02d}:{secs:02d}"


def _count(value: int, dash: str = DASH) -> str:
    return dash if value == 0 else str(value)


@dataclass(frozen=True)
class _Glyphs:
    ok: str
    bad: str
    pending: str
    dash: str
    top_left: str
    top_right: str
    bottom_left: str
    bottom_right: str
    tee_left: str
    tee_right: str
    horizontal: str
    vertical: str


UNICODE_GLYPHS = _Glyphs(
    ok="\u2714",  # ✔
    bad="\u2716",  # ✖
    pending="\u00bb",  # » -- expected to fail
    dash=DASH,  # –  -- also the marker for a skipped case
    top_left="\u250c",  # ┌
    top_right="\u2510",  # ┐
    bottom_left="\u2514",  # └
    bottom_right="\u2518",  # ┘
    tee_left="\u251c",  # ├
    tee_right="\u2524",  # ┤
    horizontal="\u2500",  # ─
    vertical="\u2502",  # │
)

ASCII_GLYPHS = _Glyphs(
    ok="v",
    bad="x",
    pending=">",
    dash="-",
    top_left="+",
    top_right="+",
    bottom_left="+",
    bottom_right="+",
    tee_left="+",
    tee_right="+",
    horizontal="-",
    vertical="|",
)

# The characters a terminal has to be able to encode for the Unicode table.
UNICODE_CHARS = "".join(
    (
        UNICODE_GLYPHS.ok,
        UNICODE_GLYPHS.bad,
        UNICODE_GLYPHS.pending,
        UNICODE_GLYPHS.dash,
        UNICODE_GLYPHS.top_left,
        UNICODE_GLYPHS.top_right,
        UNICODE_GLYPHS.bottom_left,
        UNICODE_GLYPHS.bottom_right,
        UNICODE_GLYPHS.tee_left,
        UNICODE_GLYPHS.tee_right,
        UNICODE_GLYPHS.horizontal,
        UNICODE_GLYPHS.vertical,
    )
)


def supports_unicode(encoding: str | None) -> bool:
    """Whether ``encoding`` can render the box-drawing table (cp1252 cannot)."""
    if not encoding:
        return True
    try:
        UNICODE_CHARS.encode(encoding)
    except (UnicodeEncodeError, LookupError):
        return False
    return True


@dataclass(frozen=True)
class _Palette:
    border: str = ""
    header: str = ""
    spec: str = ""
    duration: str = ""
    tests: str = ""
    passing: str = ""
    failing: str = ""
    pending: str = ""
    skipped: str = ""
    ok: str = ""
    bad: str = ""
    total_ok: str = ""
    total_bad: str = ""

    @property
    def total_marker(self) -> str:
        return self.total_bad or self.total_ok


_RESET = "\x1b[0m"

# Colours follow the Cypress summary: blue passing/skipped counts, cyan
# pending, amber failing, green ✔, red ✖.
COLOR = _Palette(
    border="\x1b[90m",
    header="\x1b[1;90m",
    spec="\x1b[1;37m",
    duration="\x1b[90m",
    tests="\x1b[37m",
    passing="\x1b[94m",
    failing="\x1b[33m",
    pending="\x1b[96m",
    skipped="\x1b[94m",
    ok="\x1b[32m",
    bad="\x1b[31m",
    total_ok="\x1b[1;32m",
    total_bad="\x1b[1;33m",
)

PLAIN = _Palette()


def _paint(text: str, style: str) -> str:
    return f"{style}{text}{_RESET}" if style else text


def _pad(text: str, width: int, align: str) -> str:
    if align == "r":
        return text.rjust(width)
    if align == "c":
        return text.center(width)
    return text.ljust(width)


# Where a row's name may be broken when it is too long for the column: after a
# word, a path segment or a part of a test id, which keeps
# "test_parse_slot_start_returns_none_for_garbage" readable across two lines
# instead of cutting it mid-word. Deliberately not "-": that is what a case id
# is built from, and "[AUTH-TS01-" / "TC01] ..." is unreadable.
_BREAK_AFTER = "/_. "


def _wrap(text: str, width: int) -> list[str]:
    """Wrap a spec path or case name, preferring to break at its separators.

    Falls back to cutting a single over-long token (a long unbroken word has to
    be split somewhere), but never splits a token that would fit on a line of
    its own.
    """
    if width <= 0 or len(text) <= width:
        return [text]

    tokens: list[str] = []
    current = ""
    for char in text:
        current += char
        if char in _BREAK_AFTER:
            tokens.append(current)
            current = ""
    if current:
        tokens.append(current)

    lines: list[str] = []
    line = ""
    for token in tokens:
        if line and len(line) + len(token) > width:
            lines.append(line)
            line = ""
        while len(token) > width:
            lines.append(token[:width])
            token = token[width:]
        line += token
    if line:
        lines.append(line)
    return lines or [text]


def render(
    specs,
    *,
    width: int | None = None,
    color: bool = True,
    unicode: bool = True,
) -> str:
    """Render the spec table as a string (no trailing newline).

    ``specs`` is an iterable of :class:`SpecResult`; an empty run renders as
    ``""``. ``width`` defaults to the terminal width, ``color`` to ANSI output
    and ``unicode`` to box-drawing characters.
    """
    specs = list(specs)
    if not specs:
        return ""

    glyphs = UNICODE_GLYPHS if unicode else ASCII_GLYPHS
    palette = COLOR if color else PLAIN

    if width is None:
        width = shutil.get_terminal_size(fallback=(100, 24)).columns
    spec_width = max(MIN_SPEC_WIDTH, width - _FIXED_WIDTH)
    inner = spec_width + _FIXED_WIDTH - 2  # between the two border characters

    bar = _paint(glyphs.vertical, palette.border)

    def cell(text: str, size: int, align: str, style: str) -> str:
        return _paint(_pad(text, size, align), style)

    def assemble(cells: list[str], separator: str = " ") -> str:
        return f"{bar} {separator.join(cells)} {bar}"

    def rule(left: str, right: str) -> str:
        return _paint(left + glyphs.horizontal * inner + right, palette.border)

    lines = [rule(glyphs.top_left, glyphs.top_right)]

    # Header: the first cell spans the marker + spec columns so "Spec" sits
    # over the ✔/✖ markers, and the column names are divided by vertical bars.
    header = [
        cell(SPEC_HEADER, spec_width + 2, "l", palette.header),
        cell("", DUR_WIDTH, "c", palette.header),
    ]
    header += [
        cell(title, size, "c", palette.header) for _, title, size in COUNT_COLUMNS
    ]
    lines.append(assemble(header, separator=bar))
    lines.append(rule(glyphs.tee_left, glyphs.tee_right))

    for index, spec in enumerate(specs):
        indent = "  " * spec.depth
        chunks = _wrap(spec.name, spec_width - len(indent)) or [spec.name]
        chunks = [indent + chunk for chunk in chunks]
        marker, marker_style = _marker(spec, glyphs, palette)

        for line_no, chunk in enumerate(chunks):
            # A continuation line carries only the wrapped path: the numbers
            # describe the whole row, so they are printed once, alongside the
            # first line.
            first = line_no == 0

            row = [
                cell(marker if first else "", 1, "c", marker_style if first else ""),
                cell(chunk, spec_width, "l", palette.spec),
                cell(
                    format_duration(spec.duration) if first else "",
                    DUR_WIDTH,
                    "r",
                    palette.duration,
                ),
            ]
            row += [
                cell(
                    _count(getattr(spec, attribute), glyphs.dash) if first else "",
                    size,
                    "c",
                    getattr(palette, attribute),
                )
                for attribute, _, size in COUNT_COLUMNS
            ]
            lines.append(assemble(row))

        if index == len(specs) - 1:
            continue

        # Case rows run together under their file; every other boundary gets a
        # rule, so a file and its cases read as one block.
        following = specs[index + 1]
        if spec.depth == 1 and following.depth == 1:
            continue
        lines.append(rule(glyphs.tee_left, glyphs.tee_right))

    lines.append(rule(glyphs.tee_left, glyphs.tee_right))
    lines.append(_totals_row(specs, spec_width, cell, assemble, palette, glyphs))
    lines.append(rule(glyphs.bottom_left, glyphs.bottom_right))

    return "\n".join(lines)


def _marker(spec: SpecResult, glyphs: _Glyphs, palette: _Palette) -> tuple[str, str]:
    """The (glyph, colour) for a row's leading marker.

    A file row only says pass/fail, like Cypress's spec row -- a spec whose
    cases were all skipped still reads as ✔. Case rows are precise about it,
    because "why did this case not pass?" is the whole point of listing them.
    """
    if spec.depth == 0:
        return (glyphs.ok, palette.ok) if spec.ok else (glyphs.bad, palette.bad)

    outcome = spec.outcome
    if outcome == FAILED:
        return glyphs.bad, palette.bad
    if outcome == PENDING:
        return glyphs.pending, palette.pending
    if outcome == SKIPPED:
        return glyphs.dash, palette.duration
    return glyphs.ok, palette.ok


def _totals_row(specs, spec_width, cell, assemble, palette, glyphs) -> str:
    """The closing ``✖ 4 of 6 failed (67%)`` row plus run-wide totals.

    Only file rows are counted: case rows are a breakdown of a file that is
    already in the list, so including them would double every number.
    """
    specs = [spec for spec in specs if spec.depth == 0]
    failed = [s for s in specs if not s.ok]
    total = len(specs)

    if failed:
        percent = round(len(failed) * 100 / total)
        label = f"{len(failed)} of {total} failed ({percent}%)"
        marker, style = glyphs.bad, palette.total_bad
    else:
        label = f"{total} of {total} passed (100%)"
        marker, style = glyphs.ok, palette.total_ok

    def total_of(attribute: str) -> int:
        return sum(getattr(spec, attribute) for spec in specs)

    row = [
        cell(marker, 1, "c", style),
        cell(label, spec_width, "l", style),
        cell(format_duration(total_of("duration")), DUR_WIDTH, "r", palette.duration),
    ]
    row += [
        cell(_count(total_of(attribute), glyphs.dash), size, "c", getattr(palette, attribute))
        for attribute, _, size in COUNT_COLUMNS
    ]
    return assemble(row)


# ---------- the run as it happens ----------


def case_label(report) -> str:
    """How a case is named on screen: ``[AUTH-TS01-TC01] Sign in ...``.

    The ``tc_*`` attributes are the ones ``tests/conftest.py`` hangs on every
    report. A case carrying no QA metadata keeps its nodeid, which is the only
    thing left to call it.
    """
    tc_id = getattr(report, "tc_raw_id", "") or "NO-ID"
    nodeid = getattr(report, "nodeid", "") or ""
    description = getattr(report, "tc_desc", "") or ""
    if tc_id == "NO-ID":
        return description or nodeid
    return f"[{tc_id}] {description or nodeid}"


def spec_title(report) -> str:
    """The heading a case is listed under: its ``tc_module`` title.

    Grouping by module rather than by file is what lets one screen read as the
    app does -- "Auth / Sign In" rather than "tests/test_sign_in.py". An
    untagged case (``unit/``, the processing suites) falls back to its file, so
    a report with no QA metadata still lands under something.
    """
    nodeid = getattr(report, "nodeid", "") or ""
    return getattr(report, "tc_title", "") or nodeid.split("::", 1)[0]


#: The count attributes of a SpecResult, in the order the table shows them.
_COUNT_ATTRIBUTES = tuple(attribute for attribute, _, _ in COUNT_COLUMNS[1:])


def group_rows(reports) -> list[SpecResult]:
    """One spec row carrying a group's totals, with its cases under it.

    The cases stay in the order they ran: :func:`collect` sorts by name, and a
    name here is ``[ID] description``, whose alphabetical order is neither the
    run order nor one a reader expects.
    """
    reports = list(reports)
    if not reports:
        return []

    first_seen: dict[str, int] = {}
    labels: dict[str, str] = {}
    for position, report in enumerate(reports):
        nodeid = getattr(report, "nodeid", "") or ""
        first_seen.setdefault(nodeid, position)
        labels.setdefault(nodeid, case_label(report))

    spec = SpecResult(name=spec_title(reports[0]))
    cases = sorted(
        collect(reports, by="case"), key=lambda case: first_seen.get(case.name, 0)
    )
    for case in cases:
        case.depth = 1
        spec.duration += case.duration
        for attribute in _COUNT_ATTRIBUTES:
            setattr(spec, attribute, getattr(spec, attribute) + getattr(case, attribute))
        case.name = labels.get(case.name, case.name)
    return [spec, *cases]


class LiveLog:
    """The run as it happens, in ``cypress run``'s shape.

    A heading per spec, a line per case as it settles, and that spec's table
    once the run moves on to the next spec::

        Auth / Sign In
            [AUTH-TS01-TC01] Sign in with correct email and password: PASSED
            ...
        ┌───────────────────────────────────────────────────────────────────┐
        │ ✔ Auth / Sign In                     00:23   5   5   –   –   –    │
        ...

    ``write(line, **markup)`` is a terminal reporter's ``write_line`` and
    ``render_table(rows)`` renders a table for this terminal; both are passed
    in so this class, like the rest of the module, needs no pytest to exercise.
    :attr:`specs` collects the spec rows for the closing table of the whole run.
    """

    def __init__(self, write, render_table):
        self._write = write
        self._render_table = render_table
        self._title: str | None = None
        self._reports: list = []
        self.specs: list[SpecResult] = []

    def record(self, report) -> None:
        """Take one pytest report, and print a line when it settles a case."""
        # A retried attempt is not a result: pytest-rerunfailures files the
        # attempt that settled the case under its real outcome (see
        # _IGNORED_BUCKETS), and counting this one would show a retried case
        # twice.
        if getattr(report, "outcome", "") == "rerun":
            return

        title = spec_title(report)
        if title != self._title:
            self.end_spec()
            self._title = title
            self._write("")
            self._write(title, bold=True)
        self._reports.append(report)

        when = getattr(report, "when", "call")
        outcome = outcome_of(report)
        # The phase that decides a case: `call`, or `setup` when the case never
        # got that far (skipped, or a fixture that failed).
        #
        # shortcut: a case that passes and then errors in teardown has already
        # been printed as PASSED, when the tables below count it as a failure.
        # Upgrade the line if that ever stops being rare -- it needs the line
        # held back until teardown, i.e. a case printing one report late.
        if when == "call" or (when == "setup" and outcome != PASSED):
            self._write(
                f"    {case_label(report)}: {outcome.upper()}",
                red=outcome == FAILED,
            )

    def end_spec(self) -> None:
        """Close the current spec with its own table, and keep its totals."""
        if not self._reports:
            self._title = None
            return

        rows = group_rows(self._reports)
        self.specs.append(rows[0])
        self._write("")
        for line in self._render_table(rows).splitlines():
            self._write(line)
        self._title = None
        self._reports = []
