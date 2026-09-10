#!/usr/bin/env node
// Ringkas hasil Playwright JSON reporter jadi baris siap-lapor ke Huly Test Management.
//
//   node huly-report.mjs [test-results/results.json] [--json]
//
// Judul test dipakai apa adanya sebagai kunci pencocokan ke nama test case di Huly
// (Huly memakai id acak, bukan kode seperti QA-12), jadi judul harus persis sama.

import { readFileSync } from 'node:fs';

const args = process.argv.slice(2);
const asJson = args.includes('--json');
const file = args.find((a) => !a.startsWith('--')) ?? 'test-results/results.json';

let report;
try {
  report = JSON.parse(readFileSync(file, 'utf8'));
} catch (err) {
  console.error(`Gagal baca ${file}: ${err.message}`);
  console.error('Jalankan `npx playwright test` dulu, dan pastikan reporter json aktif di playwright.config.ts.');
  process.exit(1);
}

// expected | unexpected | flaky | skipped  ->  status Huly
const HULY_STATUS = {
  expected: 'passed',
  unexpected: 'failed',
  flaky: 'passed',
  skipped: 'untested',
};

const stripAnsi = (s) => s.replace(/\u001B\[[0-9;]*m/g, '');
const firstLine = (s) => stripAnsi(String(s)).split('\n').find((l) => l.trim()) ?? '';

const rows = [];

function walk(suite, ancestors) {
  const path = suite.title ? [...ancestors, suite.title] : ancestors;

  for (const spec of suite.specs ?? []) {
    for (const test of spec.tests ?? []) {
      const status = test.status ?? 'skipped';
      const results = test.results ?? [];
      const last = results[results.length - 1] ?? {};
      const error = last.error?.message ?? last.errors?.[0]?.message;

      const notes = [];
      if (status === 'unexpected' && error) notes.push(firstLine(error));
      if (status === 'flaky') notes.push(`Lulus setelah ${results.length - 1}x retry — buat issue, jangan biarkan.`);
      if (status === 'skipped') notes.push('Di-skip. Pakai status blocked kalau diblokir bug/dependensi.');
      notes.push(`${spec.file ?? suite.file ?? '?'}:${spec.line ?? '?'}`);

      rows.push({
        title: spec.title,
        suite: path.filter((p) => p !== spec.file).join(' > '),
        file: spec.file ?? suite.file ?? '',
        playwrightStatus: status,
        hulyStatus: HULY_STATUS[status] ?? 'untested',
        durationMs: results.reduce((sum, r) => sum + (r.duration ?? 0), 0),
        note: notes.join(' | '),
      });
    }
  }

  for (const child of suite.suites ?? []) walk(child, path);
}

for (const suite of report.suites ?? []) walk(suite, []);

if (rows.length === 0) {
  console.error('Tidak ada test di report. Salah file, atau run-nya kosong.');
  process.exit(1);
}

if (asJson) {
  console.log(JSON.stringify(rows, null, 2));
} else {
  const width = Math.min(70, Math.max(...rows.map((r) => r.title.length)));
  for (const r of rows) {
    console.log(`${r.hulyStatus.padEnd(8)} ${r.title.padEnd(width)}  ${r.note}`);
  }
  const count = (s) => rows.filter((r) => r.hulyStatus === s).length;
  console.log(
    `\n${rows.length} test — passed ${count('passed')}, failed ${count('failed')}, untested ${count('untested')}`,
  );
  console.log('Lapor ke Huly: huly_list_test_runs -> huly_list_test_cases (cocokkan judul) -> huly_set_test_result');
}
