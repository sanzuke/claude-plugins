---
name: qa-automation
description: SOP QA automation perusahaan — setup Playwright (TypeScript) di repo, menulis test e2e/API yang tidak rapuh, menangani flaky test, dan melaporkan hasil run ke Huly Test Management. WAJIB dipakai setiap kali user minta bikin test otomatis, setup Playwright/e2e/QA di projek, menambah test untuk fitur baru, menulis regression test setelah bug ditemukan, memperbaiki test yang gagal atau flaky, mengubah CI test workflow, atau bertanya "ini perlu ditest nggak". Pakai juga ketika user menyebut test case, test run, test plan, coverage, regresi, smoke test, atau QA. Jangan tunggu user menyebut kata "Playwright" atau "QA" — kalau sedang menulis atau memperbaiki test otomatis, skill ini berlaku.
---

# SOP QA Automation

Tujuan SOP ini: **suite test yang dipercaya orang.** Suite yang sering merah tanpa alasan lebih buruk daripada tidak punya suite sama sekali — orang berhenti membacanya, lalu bug asli lolos di antara kegagalan palsu.

Dua musuh utama: test rapuh (gagal karena UI digeser, bukan karena bug) dan test yang menguji ulang hal yang sudah dijamin lapisan lain.

## Apa yang layak diotomasi

Piramida, dari bawah ke atas — makin ke atas makin mahal dan makin lambat:

| Lapisan | Untuk apa | Porsi wajar |
|---|---|---|
| Unit | logika bisnis murni: perhitungan bunga, aturan diskon, validasi | mayoritas |
| API / integrasi | kontrak endpoint, transaksi DB, otorisasi | sedang |
| E2E (Playwright) | alur yang kalau rusak bikin rugi: login, bayar, simpan/tarik dana, checkout | sedikit tapi rapi |

Litmus test sebelum menulis e2e: **kalau alur ini rusak diam-diam selama seminggu, ada uang atau kepercayaan yang hilang?** Kalau tidak, turunkan ke lapisan API atau unit.

Jangan tulis e2e untuk: validasi form sederhana (cukup unit), styling/layout, konten statis, atau kombinasi parameter yang sudah dites di unit. Jangan bikin test yang isinya mengulang implementasi (`expect(mock).toHaveBeenCalled()` tanpa efek yang bisa diamati user).

## Struktur repo test

```
playwright.config.ts
tests/e2e/
  fixtures.ts            # extend base test, inject page object
  pages/<nama>.page.ts   # page object: locator + aksi, TANPA assertion
  specs/<nama>.spec.ts   # skenario + assertion
docs/qa/checklist.md     # checklist QA per PR (dokumen living)
.github/workflows/e2e.yml
test-results/results.json  # output JSON reporter, dipakai untuk lapor ke Huly
```

Scaffold semuanya dengan:

```bash
bash scripts/scaffold-playwright.sh [target-dir]
```

Script ini idempoten — file yang sudah ada dilewati, tidak pernah ditimpa. Aman dijalankan ulang di repo yang sudah punya test.

## Konvensi yang tidak boleh dilanggar

- **Selector berbasis peran, bukan struktur.** `getByRole`, `getByLabel`, `getByText`. Kalau tidak ada yang stabil, minta developer menambahkan `data-testid` lalu pakai `getByTestId` — jangan pakai CSS berantai (`.card > div:nth-child(3)`) atau XPath.
- **Nol `waitForTimeout`.** Pakai web-first assertion (`await expect(locator).toBeVisible()`) yang otomatis retry, atau `expect.poll` untuk kondisi non-DOM. Hard sleep = flaky yang ditunda.
- **Page object menyimpan locator dan aksi; assertion tinggal di spec.** Kalau page object mulai punya `expect`, skenario jadi tidak terbaca dari spec.
- **Setiap test berdiri sendiri.** Bikin datanya sendiri (lewat API/seed, bukan lewat UI), bersihkan sendiri, dan boleh jalan paralel dalam urutan acak. Test yang butuh test lain jalan duluan akan pecah di CI.
- **Jangan pakai UI untuk setup.** Login lewat API + `storageState`, bukan mengisi form login di setiap test.
- **Judul test = nama test case di Huly, persis sama.** Ini satu-satunya jembatan antara suite dan Test Management (lihat bawah).
- **Satu assertion inti per test.** Boleh beberapa `expect`, tapi satu alasan gagal.

## Alur kerja

### 1. Repo belum punya test otomatis

1. Jalankan `scripts/scaffold-playwright.sh`.
2. Pasang dependensi di repo target: `npm i -D @playwright/test && npx playwright install --with-deps chromium`.
3. Tambahkan skrip ke `package.json`: `"test:e2e": "playwright test"`, `"test:e2e:ui": "playwright test --ui"`.
4. Tulis **satu** test untuk alur paling kritis (biasanya login atau transaksi utama), pastikan hijau lokal dan di CI, baru tambah yang lain. Jangan scaffold 20 test sekaligus sebelum satu pun jalan di CI.
5. Set `E2E_BASE_URL` di environment CI.

### 2. Fitur baru

Tulis test setelah perilaku disepakati, sebelum fitur dianggap selesai. Tanya dulu: lapisan mana yang paling murah untuk menangkap regresi ini? Baru turun ke e2e kalau alurnya masuk kriteria di atas.

### 3. Bug ditemukan

Urutan wajib: **reproduksi dulu sebagai test yang merah**, baru perbaiki kodenya, lalu pastikan test itu hijau. Test regresi ini permanen — beri komentar satu baris berisi identifier issue-nya (`// Regresi: PROJ-123`) supaya orang berikutnya tahu kenapa test ini ada.

### 4. Test flaky

Flaky bukan gangguan kecil, itu bug di test (atau bug balapan di aplikasi).

- **Jangan** menaikkan `retries` untuk menutupinya. `retries` di CI hanya untuk blip infrastruktur.
- Karantina: `test.fixme(...)` dengan komentar berisi identifier issue, buat issue-nya, lalu perbaiki dalam sprint yang sama. Test yang dikarantina lebih dari satu sprint dihapus — suite tidak boleh menyimpan zombie.
- Penyebab tersering, cek berurutan: hard sleep, data test dipakai bersama, animasi/toast yang belum selesai, race di aplikasi (ini bug asli — laporkan, jangan tambal di test).

### 5. Menutup sesi kerja

Laporkan hasil run ke Huly (bawah), catat status harian di issue tracker — bukan di file yang di-commit.

## Integrasi Huly Test Management

Batasan yang harus dipahami sebelum mencoba:

- Test case dan test run di Huly punya id acak (`6a9e48ba2246a6f94f3abf77`), bukan kode seperti `QA-12`. Jadi pencocokan dilakukan lewat **nama**: judul test Playwright harus identik dengan nama test case di Huly.
- **Test run tidak bisa dibuat lewat MCP**, dan test case tidak bisa ditambahkan ke run dari sini. Run dibuat di UI Huly beserta daftar case-nya; skill ini hanya mengisi hasilnya. Kalau run belum ada, minta user membuatnya dulu — jangan berpura-pura membuatnya.

Alur pelaporan setelah `playwright test` selesai:

1. Ringkas hasil dari JSON reporter:
   ```bash
   node scripts/huly-report.mjs test-results/results.json
   node scripts/huly-report.mjs test-results/results.json --json   # untuk diproses agent
   ```
2. `huly_list_test_runs` → ambil `testRunId` run yang sedang berjalan (konfirmasi ke user kalau ada lebih dari satu).
3. `huly_list_test_cases` (filter `testProjectName`) → petakan nama test case ke `testCaseId`.
4. Untuk tiap test yang cocok: `huly_set_test_result` dengan `testRunId`, `testCaseId`, `status`, dan `note` berisi ringkasan kegagalan (pesan error baris pertama + nama file spec).
5. Test yang tidak punya pasangan di Huly: laporkan ke user sebagai daftar, jangan diam-diam dilewati. Test case Huly yang tidak punya pasangan otomatis tetap `untested` — itu pekerjaan manual QA, bukan kegagalan.
6. Kalau ada kegagalan yang sudah ada issue-nya, hubungkan dengan `huly_link_issue` (`targetType: "test_result"`, `issueIdentifier: "PROJ-123"`).

Pemetaan status Playwright → Huly:

| Playwright | Huly | Catatan |
|---|---|---|
| `expected` | `passed` | |
| `unexpected` | `failed` | `note` wajib berisi pesan error |
| `flaky` | `passed` | `note` wajib menyebut lulus setelah retry + buat issue |
| `skipped` / `fixme` | `blocked` kalau diblokir bug/dependensi, selain itu `untested` | |

## Yang sengaja TIDAK diotomasi

Tulis di `docs/qa/checklist.md`, jangan dipaksa jadi test: verifikasi visual/estetika, alur yang butuh kartu pembayaran asli atau OTP dari perangkat fisik, uji beban (alat terpisah), dan eksplorasi manual. Menyatakan sesuatu sengaja manual jauh lebih baik daripada test e2e setengah jadi yang di-skip permanen.
