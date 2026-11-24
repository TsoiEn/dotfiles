// ---------- QA terminal summary (playwrightIni, TypeScript) ----------
// The same screen the Python kit prints from pytest, as a Playwright reporter:
// a heading per spec, a line per case as it settles, that spec's own table once
// the spec finishes, and one row per spec at the end of the run.
//
// A spec is a test file, and a case is its describe titles plus its own -- the
// TypeScript suites carry no tc_* metadata, so there is nothing else to call
// them.
//
// PW_QA_ASCII=1 draws the table with "+-|" instead of box characters, for a
// console that cannot show them.

import type {
  FullConfig,
  FullResult,
  Reporter,
  Suite,
  TestCase,
  TestResult,
} from '@playwright/test/reporter';

// ---------- outcomes ----------

type Outcome = 'passed' | 'failed' | 'pending' | 'skipped';

/** Shown in a count column that has nothing in it. */
const DASH = '–'; // en dash, as Cypress uses

/**
 * Which column a settled case lands in.
 *
 * `pending` is Playwright's `test.fail()` and `test.fixme()`: a case that is
 * known not to work, which Cypress calls pending and pytest calls xfail. A
 * `test.fail()` that unexpectedly passes is a failure, as pytest's xpass is.
 */
function outcomeOf(test: TestCase, result: TestResult): Outcome {
  if (test.annotations.some((a) => a.type === 'fixme')) return 'pending';
  if (test.expectedStatus === 'failed') {
    return result.status === 'failed' || result.status === 'timedOut'
      ? 'pending'
      : 'failed';
  }
  if (result.status === 'skipped') return 'skipped';
  return result.status === 'passed' ? 'passed' : 'failed';
}

// ---------- geometry ----------

const SPEC_HEADER = 'Spec';

/** Width of the duration column ("02:21" / "41ms", right-aligned). */
const DUR_WIDTH = 7;

/**
 * [count key, column header, width]. Each width carries one space of padding
 * on either side of the number, so the header's dividers get room to breathe.
 */
const COUNT_COLUMNS: ReadonlyArray<[CountKey, string, number]> = [
  ['tests', 'Tests', 7],
  ['passing', 'Passing', 9],
  ['failing', 'Failing', 9],
  ['pending', 'Pending', 9],
  ['skipped', 'Skipped', 9],
];

/**
 * Everything in a row except the spec text itself: the two borders, the
 * padding, the marker and the duration/count columns with their separators. A
 * row is therefore `specWidth + FIXED_WIDTH` wide.
 */
const FIXED_WIDTH = 62;

/** Never squeeze the spec column below this, even in a very narrow terminal. */
const MIN_SPEC_WIDTH = 28;

type CountKey = 'tests' | 'passing' | 'failing' | 'pending' | 'skipped';

/** One row of the table: a test file, or -- when nested -- one of its cases. */
export interface SpecRow {
  name: string;
  /** Milliseconds, as Playwright reports them. */
  duration: number;
  passing: number;
  failing: number;
  pending: number;
  skipped: number;
  /**
   * 0 for a test file, 1 for one of its cases. Case rows are indented under
   * the file they belong to and are left out of the closing totals, which
   * would otherwise count every case twice.
   */
  depth: 0 | 1;
}

export function emptyRow(name: string, depth: 0 | 1 = 0): SpecRow {
  return { name, duration: 0, passing: 0, failing: 0, pending: 0, skipped: 0, depth };
}

const COLUMN_OF: Record<Outcome, Exclude<CountKey, 'tests'>> = {
  passed: 'passing',
  failed: 'failing',
  pending: 'pending',
  skipped: 'skipped',
};

function countOf(row: SpecRow, key: CountKey): number {
  if (key !== 'tests') return row[key];
  return row.passing + row.failing + row.pending + row.skipped;
}

/** True when nothing in the row failed. */
function rowOk(row: SpecRow): boolean {
  return row.failing === 0;
}

/** The single outcome of a case row, for its marker. */
function rowOutcome(row: SpecRow): Outcome {
  if (row.failing) return 'failed';
  if (row.pending) return 'pending';
  if (row.skipped) return 'skipped';
  return 'passed';
}

// ---------- formatting ----------

/** Cypress-style duration: `41ms` below a second, `00:09` above it. */
export function formatDuration(ms: number): string {
  const value = Math.max(0, Number(ms) || 0);
  if (value < 1000) return `${Math.round(value)}ms`;
  const total = Math.floor(value / 1000);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(Math.floor(total / 60))}:${pad(total % 60)}`;
}

interface Glyphs {
  ok: string;
  bad: string;
  pending: string;
  dash: string;
  topLeft: string;
  topRight: string;
  bottomLeft: string;
  bottomRight: string;
  teeLeft: string;
  teeRight: string;
  horizontal: string;
  vertical: string;
}

const UNICODE_GLYPHS: Glyphs = {
  ok: '✔', // ✔
  bad: '✖', // ✖
  pending: '»', // » -- known not to work
  dash: DASH, // –  -- also the marker for a skipped case
  topLeft: '┌',
  topRight: '┐',
  bottomLeft: '└',
  bottomRight: '┘',
  teeLeft: '├',
  teeRight: '┤',
  horizontal: '─',
  vertical: '│',
};

const ASCII_GLYPHS: Glyphs = {
  ok: 'v',
  bad: 'x',
  pending: '>',
  dash: '-',
  topLeft: '+',
  topRight: '+',
  bottomLeft: '+',
  bottomRight: '+',
  teeLeft: '+',
  teeRight: '+',
  horizontal: '-',
  vertical: '|',
};

type Palette = Record<
  | 'border'
  | 'header'
  | 'spec'
  | 'duration'
  | CountKey
  | 'ok'
  | 'bad'
  | 'totalOk'
  | 'totalBad',
  string
>;

const RESET = '\x1b[0m';

/**
 * Colours follow the Cypress summary: blue passing/skipped counts, cyan
 * pending, amber failing, green ✔, red ✖.
 */
const COLOR: Palette = {
  border: '\x1b[90m',
  header: '\x1b[1;90m',
  spec: '\x1b[1;37m',
  duration: '\x1b[90m',
  tests: '\x1b[37m',
  passing: '\x1b[94m',
  failing: '\x1b[33m',
  pending: '\x1b[96m',
  skipped: '\x1b[94m',
  ok: '\x1b[32m',
  bad: '\x1b[31m',
  totalOk: '\x1b[1;32m',
  totalBad: '\x1b[1;33m',
};

const PLAIN: Palette = Object.fromEntries(
  Object.keys(COLOR).map((key) => [key, '']),
) as Palette;

function paint(text: string, style: string): string {
  return style ? `${style}${text}${RESET}` : text;
}

function pad(text: string, width: number, align: 'l' | 'c' | 'r'): string {
  if (text.length >= width) return text;
  const room = width - text.length;
  if (align === 'r') return ' '.repeat(room) + text;
  if (align === 'l') return text + ' '.repeat(room);
  const left = Math.floor(room / 2);
  return ' '.repeat(left) + text + ' '.repeat(room - left);
}

/**
 * Where a row's name may be broken when it is too long for the column: after a
 * word, a path segment or a ` › ` between describe titles. Deliberately not
 * "-", which is what a spec file name is built from.
 */
const BREAK_AFTER = '/_. ›';

/**
 * Wrap a spec path or case name, preferring to break at its separators.
 *
 * Cuts a single over-long token (a long unbroken word has to be split
 * somewhere), but never splits a token that would fit on a line of its own.
 */
export function wrap(text: string, width: number): string[] {
  if (width <= 0 || text.length <= width) return [text];

  const tokens: string[] = [];
  let current = '';
  for (const char of text) {
    current += char;
    if (BREAK_AFTER.includes(char)) {
      tokens.push(current);
      current = '';
    }
  }
  if (current) tokens.push(current);

  const lines: string[] = [];
  let line = '';
  for (let token of tokens) {
    if (line && line.length + token.length > width) {
      lines.push(line);
      line = '';
    }
    while (token.length > width) {
      lines.push(token.slice(0, width));
      token = token.slice(width);
    }
    line += token;
  }
  if (line) lines.push(line);
  return lines.length ? lines : [text];
}

export interface RenderOptions {
  width?: number;
  color?: boolean;
  unicode?: boolean;
}

/**
 * Render the spec table as a string (no trailing newline); an empty run
 * renders as `""`.
 */
export function render(rows: SpecRow[], options: RenderOptions = {}): string {
  if (!rows.length) return '';

  const glyphs = options.unicode === false ? ASCII_GLYPHS : UNICODE_GLYPHS;
  const palette = options.color === false ? PLAIN : COLOR;
  const width = options.width ?? process.stdout.columns ?? 100;
  const specWidth = Math.max(MIN_SPEC_WIDTH, width - FIXED_WIDTH);
  const inner = specWidth + FIXED_WIDTH - 2; // between the two border characters

  const bar = paint(glyphs.vertical, palette.border);
  const cell = (text: string, size: number, align: 'l' | 'c' | 'r', style: string) =>
    paint(pad(text, size, align), style);
  const assemble = (cells: string[], separator = ' ') =>
    `${bar} ${cells.join(separator)} ${bar}`;
  const rule = (left: string, right: string) =>
    paint(left + glyphs.horizontal.repeat(inner) + right, palette.border);
  const count = (value: number) => (value === 0 ? glyphs.dash : String(value));

  const lines = [rule(glyphs.topLeft, glyphs.topRight)];

  // Header: the first cell spans the marker + spec columns so "Spec" sits over
  // the ✔/✖ markers, and the column names are divided by vertical bars.
  lines.push(
    assemble(
      [
        cell(SPEC_HEADER, specWidth + 2, 'l', palette.header),
        cell('', DUR_WIDTH, 'c', palette.header),
        ...COUNT_COLUMNS.map(([, title, size]) => cell(title, size, 'c', palette.header)),
      ],
      bar,
    ),
  );
  lines.push(rule(glyphs.teeLeft, glyphs.teeRight));

  rows.forEach((row, index) => {
    const indent = '  '.repeat(row.depth);
    const chunks = wrap(row.name, specWidth - indent.length).map((c) => indent + c);
    const [marker, markerStyle] = markerFor(row, glyphs, palette);

    chunks.forEach((chunk, lineNo) => {
      // A continuation line carries only the wrapped name: the numbers
      // describe the whole row, so they are printed once, on the first line.
      const first = lineNo === 0;
      lines.push(
        assemble([
          cell(first ? marker : '', 1, 'c', first ? markerStyle : ''),
          cell(chunk, specWidth, 'l', palette.spec),
          cell(
            first ? formatDuration(row.duration) : '',
            DUR_WIDTH,
            'r',
            palette.duration,
          ),
          ...COUNT_COLUMNS.map(([key, , size]) =>
            cell(first ? count(countOf(row, key)) : '', size, 'c', palette[key]),
          ),
        ]),
      );
    });

    if (index === rows.length - 1) return;
    // Case rows run together under their file; every other boundary gets a
    // rule, so a file and its cases read as one block.
    if (row.depth === 1 && rows[index + 1].depth === 1) return;
    lines.push(rule(glyphs.teeLeft, glyphs.teeRight));
  });

  lines.push(rule(glyphs.teeLeft, glyphs.teeRight));
  lines.push(totalsRow(rows, specWidth, cell, assemble, palette, glyphs, count));
  lines.push(rule(glyphs.bottomLeft, glyphs.bottomRight));

  return lines.join('\n');
}

/**
 * The (glyph, colour) for a row's leading marker.
 *
 * A file row only says pass/fail, like Cypress's spec row -- a spec whose
 * cases were all skipped still reads as ✔. Case rows are precise about it,
 * because "why did this case not pass?" is the whole point of listing them.
 */
function markerFor(row: SpecRow, glyphs: Glyphs, palette: Palette): [string, string] {
  if (row.depth === 0) {
    return rowOk(row) ? [glyphs.ok, palette.ok] : [glyphs.bad, palette.bad];
  }
  switch (rowOutcome(row)) {
    case 'failed':
      return [glyphs.bad, palette.bad];
    case 'pending':
      return [glyphs.pending, palette.pending];
    case 'skipped':
      return [glyphs.dash, palette.duration];
    default:
      return [glyphs.ok, palette.ok];
  }
}

/**
 * The closing `✖ 4 of 6 failed (67%)` row plus run-wide totals.
 *
 * Only file rows are counted: case rows are a breakdown of a file that is
 * already in the list, so including them would double every number.
 */
function totalsRow(
  rows: SpecRow[],
  specWidth: number,
  cell: (text: string, size: number, align: 'l' | 'c' | 'r', style: string) => string,
  assemble: (cells: string[], separator?: string) => string,
  palette: Palette,
  glyphs: Glyphs,
  count: (value: number) => string,
): string {
  const files = rows.filter((row) => row.depth === 0);
  const failed = files.filter((row) => !rowOk(row));
  const total = files.length;

  const label = failed.length
    ? `${failed.length} of ${total} failed (${Math.round((failed.length * 100) / total)}%)`
    : `${total} of ${total} passed (100%)`;
  const [marker, style] = failed.length
    ? [glyphs.bad, palette.totalBad]
    : [glyphs.ok, palette.totalOk];
  const totalOf = (key: CountKey) =>
    files.reduce((sum, row) => sum + countOf(row, key), 0);

  return assemble([
    cell(marker, 1, 'c', style),
    cell(label, specWidth, 'l', style),
    cell(
      formatDuration(files.reduce((sum, row) => sum + row.duration, 0)),
      DUR_WIDTH,
      'r',
      palette.duration,
    ),
    ...COUNT_COLUMNS.map(([key, , size]) =>
      cell(count(totalOf(key)), size, 'c', palette[key]),
    ),
  ]);
}

// ---------- the run as it happens ----------

/**
 * Playwright's reporter in `cypress run`'s shape.
 *
 * Unlike pytest, Playwright runs spec files in parallel, so a spec cannot be
 * closed when the heading changes: each spec is closed when the last of its
 * cases settles, and the heading is reprinted whenever the run jumps back to a
 * spec whose last line is no longer on screen.
 */
export default class QASummaryReporter implements Reporter {
  private readonly remaining = new Map<string, number>();
  private readonly cases = new Map<string, SpecRow[]>();
  private readonly specs: SpecRow[] = [];
  private heading: string | null = null;
  private color = Boolean(process.stdout.isTTY) && !process.env.NO_COLOR;
  private unicode = process.env.PW_QA_ASCII !== '1';

  printsToStdio(): boolean {
    return true;
  }

  onBegin(config: FullConfig, suite: Suite): void {
    if (process.env.FORCE_COLOR && process.env.FORCE_COLOR !== '0') this.color = true;
    // How many cases each spec owes, so a spec can be closed the moment its
    // last one settles however the workers interleave.
    for (const test of suite.allTests()) {
      const spec = specOf(test);
      this.remaining.set(spec, (this.remaining.get(spec) ?? 0) + 1);
    }
  }

  onTestEnd(test: TestCase, result: TestResult): void {
    // An attempt that will be retried is not a result: the attempt that
    // settles the case is reported too, and counting this one would show a
    // retried case twice.
    if (
      result.retry < test.retries &&
      result.status !== 'passed' &&
      result.status !== 'skipped'
    ) {
      this.write(`    ${caseLabel(test)}: RETRYING`, COLOR.failing);
      return;
    }

    const spec = specOf(test);
    const outcome = outcomeOf(test, result);
    const retried = result.retry > 0;

    if (this.heading !== spec) {
      this.write('');
      this.write(spec, COLOR.spec);
      this.heading = spec;
    }
    this.write(
      `    ${caseLabel(test)}: ${outcome.toUpperCase()}${retried ? ' (flaky)' : ''}`,
      outcome === 'failed' ? COLOR.bad : '',
    );
    // Why it failed, which no other reporter is left to print: this one
    // replaces `list`, whose job that was. Right under the line rather than in
    // a section at the end, because that is where the eye already is.
    if (outcome === 'failed') {
      for (const error of result.errors) {
        for (const line of [error.message, error.snippet].filter(Boolean).join('\n').split('\n')) {
          this.write(`      ${line}`);
        }
      }
    }

    const row = emptyRow(caseLabel(test), 1);
    row.duration = result.duration;
    row[COLUMN_OF[outcome]] += 1;
    const cases = this.cases.get(spec) ?? [];
    cases.push(row);
    this.cases.set(spec, cases);

    const left = (this.remaining.get(spec) ?? 1) - 1;
    this.remaining.set(spec, left);
    if (left <= 0) this.endSpec(spec);
  }

  onEnd(_result: FullResult): void {
    // Anything still open: an interrupted run, or a spec whose cases were
    // filtered out after onBegin counted them.
    for (const spec of [...this.cases.keys()]) this.endSpec(spec);
    if (!this.specs.length) {
      // No other reporter is left to say the selection matched nothing, which
      // otherwise looks like a suite that passed in silence.
      this.write('');
      this.write('No tests ran.', COLOR.failing);
      return;
    }

    this.write('');
    this.write(`${'='.repeat(20)} QA test summary ${'='.repeat(20)}`, COLOR.header);
    this.write(this.table(this.specs));
  }

  /** Close a spec with its own table, and keep its totals for the run's. */
  private endSpec(spec: string): void {
    const cases = this.cases.get(spec);
    this.cases.delete(spec);
    if (!cases?.length) return;

    const row = emptyRow(spec);
    for (const one of cases) {
      row.duration += one.duration;
      for (const key of ['passing', 'failing', 'pending', 'skipped'] as const) {
        row[key] += one[key];
      }
    }
    this.specs.push(row);

    this.write('');
    this.write(this.table([row, ...cases]));
    this.heading = null;
  }

  private table(rows: SpecRow[]): string {
    return render(rows, { color: this.color, unicode: this.unicode });
  }

  private write(line: string, style = ''): void {
    process.stdout.write(`${this.color && style ? paint(line, style) : line}\n`);
  }
}

/**
 * The spec a case belongs to: its file, as the file suite spells it.
 *
 * shortcut: two projects running the same file share a row, since the project
 * name is left out. Add `test.parent.project()?.name` here when a suite runs
 * more than the one chromium project the kit sets up.
 */
function specOf(test: TestCase): string {
  for (let suite: Suite | undefined = test.parent; suite; suite = suite.parent) {
    if (suite.type === 'file') return suite.title;
  }
  return test.location.file;
}

/** How a case is named on screen: its describe titles, then its own. */
function caseLabel(test: TestCase): string {
  const titles: string[] = [test.title];
  for (let suite: Suite | undefined = test.parent; suite; suite = suite.parent) {
    if (suite.type === 'file') break;
    if (suite.title) titles.unshift(suite.title);
  }
  return titles.join(' › ');
}
