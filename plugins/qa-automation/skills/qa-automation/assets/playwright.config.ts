import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.E2E_BASE_URL ?? 'http://localhost:3000';
const isCI = Boolean(process.env.CI);

export default defineConfig({
  testDir: './tests/e2e/specs',
  outputDir: './test-results',
  fullyParallel: true,
  // Test dengan .only tidak boleh lolos ke CI.
  forbidOnly: isCI,
  // Retry hanya untuk blip infrastruktur. Test flaky diperbaiki atau dikarantina,
  // bukan ditutupi dengan menaikkan angka ini.
  retries: isCI ? 2 : 0,
  workers: isCI ? 2 : undefined,
  timeout: 30_000,
  expect: { timeout: 5_000 },
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    // Dipakai scripts/huly-report.mjs untuk lapor ke Huly Test Management.
    ['json', { outputFile: 'test-results/results.json' }],
  ],
  use: {
    baseURL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
