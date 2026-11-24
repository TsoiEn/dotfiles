import { defineConfig, devices } from '@playwright/test';
import fs from 'node:fs';

// .env without a dependency, and without overwriting a real environment
// variable -- which is how scripts/runner.sh --env wins over TEST_ENV in .env.
//
// shortcut: KEY=VALUE lines, with optional surrounding quotes; no multi-line
// values and no `export `. Switch to dotenv if a value ever needs more.
for (const line of fs.existsSync('.env') ? fs.readFileSync('.env', 'utf8').split('\n') : []) {
  const match = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/.exec(line);
  if (!match || line.trimStart().startsWith('#')) continue;
  const [, key, raw] = match;
  // An empty value counts as unset, so a filled line wins over the blank key
  // .env.example starts life with -- a .env gets copied from it and appended to.
  if (!process.env[key]) {
    process.env[key] = raw.replace(/^(['"])(.*)\1$/, '$2');
  }
}

// Each environment's address comes from its own key in .env (gitignored), so
// no URL is committed here. staging is PW_STG_, matching the secret names
// DevOps issues.
const BASE_URLS: Record<string, string | undefined> = {
  local: process.env.LOCAL_BASE_URL,
  dev: process.env.DEV_BASE_URL,
  staging: process.env.PW_STG_BASE_URL,
};

const TEST_ENV = process.env.TEST_ENV ?? 'staging';
const baseURL = BASE_URLS[TEST_ENV];
// Said here rather than as "Invalid URL" inside the first page.goto. Not when
// only listing (runner.sh --collect): nothing is opened, so nothing needs an
// address, and a fresh clone should still be able to see what it has.
if (!baseURL && !process.argv.includes('--list')) {
  throw new Error(
    `No base URL for TEST_ENV=${TEST_ENV}. Set its *_BASE_URL in .env (see .env.example).`,
  );
}

export default defineConfig({
  testDir: './tests',
  // Emptied every run, which is why only the last --loop round leaves evidence.
  outputDir: './artifacts',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  reporter: 'list',
  use: {
    baseURL,
    trace: 'retain-on-failure',
    // scripts/runner.sh --no-video sets PW_VIDEO; Playwright has no --video
    // flag of its own.
    video: process.env.PW_VIDEO === 'off' ? 'off' : 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
