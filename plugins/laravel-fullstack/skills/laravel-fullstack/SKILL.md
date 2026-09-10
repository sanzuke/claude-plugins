---
name: laravel-fullstack
description: SOP developer PHP fullstack untuk projek Laravel dengan Livewire + Blade + Alpine.js dan test Pest. WAJIB dipakai setiap kali menulis atau mengubah Model/Eloquent, migration, Controller, Livewire component, Blade view, Form Request, Policy, Job/queue, route, atau test Pest/PHPUnit di repo Laravel (composer.json punya laravel/framework). Pakai juga ketika user minta "bikin fitur baru", "bikin CRUD", "kenapa query-nya lambat" (N+1), controller yang gemuk perlu di-refactor, atau saat menulis test untuk Livewire component. Jangan tunggu user menyebut kata "Laravel", "Livewire", atau "Eloquent" — kalau sedang mengerjakan kode di repo Laravel, skill ini berlaku.
---

# SOP Laravel Fullstack

Tujuan SOP ini: **logika bisnis gampang ditemukan dan gampang ditest, state UI tidak bocor ke database, dan tidak ada yang query N+1 tanpa sadar.**

Tiga tempat paling sering jadi tempat sampah kode di projek Laravel: controller yang menggendong validasi+query+logika+response sekaligus, model yang isinya business rule padahal harusnya cuma mapping tabel, dan Blade `@php` block yang diam-diam berisi keputusan bisnis. SOP ini soal membagi tanggung jawab supaya masing-masing gampang ditest sendiri-sendiri.

## Pembagian tanggung jawab — jangan tertukar

| Layer | Isinya | TIDAK boleh isi |
|---|---|---|
| Model (Eloquent) | relasi, cast, scope query, accessor ringan | business rule, side effect (kirim email, panggil API luar) |
| Action (`app/Actions/`) | satu unit logika bisnis, `__invoke()`, dependency lewat constructor | HTTP concern (request/response), rendering |
| Livewire component | state UI + orkestrasi: terima input, panggil Action, kirim balik state ke view | query kompleks langsung di `render()`, business rule |
| Controller (kalau masih ada route non-Livewire) | terima Request, panggil Action, kembalikan response/redirect | validasi manual di badan method (pakai Form Request), query builder panjang |
| Blade view | tampilan | logika kondisional bisnis (`@if($user->balance > threshold * 1.5)`) — pindahkan ke accessor/Action, Blade cuma manggil |
| Alpine.js | state UI lokal murni (toggle, tab aktif, animasi) | state yang perlu tersinkron ke server — itu punya Livewire |

Litmus test sebelum menaruh kode di Controller/Livewire component: **kalau logika ini dipindah ke Action, apakah masih bisa ditest tanpa HTTP request atau render Livewire?** Kalau tidak bisa, itu tandanya logika masih menempel ke layer transport, bukan logika murni.

## Struktur direktori standar

```
app/
├── Actions/<Domain>/<Verb><Noun>Action.php   # mis. Actions/Auth/ResetPasswordAction.php
├── Livewire/<Domain>/<Nama>.php
├── Models/<Nama>.php
├── Http/Requests/<Nama>Request.php
├── Http/Controllers/ (hanya untuk endpoint non-Livewire: API, webhook)
└── Policies/<Nama>Policy.php
resources/views/livewire/<domain>/<kebab-nama>.blade.php
database/migrations/  # append-only setelah migrate di staging/produksi
tests/
├── Feature/<Domain>/<Nama>Test.php   # HTTP + Livewire::test()
└── Unit/Actions/<Nama>ActionTest.php # Action ditest tanpa Livewire/HTTP
```

Scaffold satu fitur (Action + Livewire component + view + Form Request + test) sekaligus:

```bash
bash scripts/scaffold-livewire-feature.sh <NamaFitur>
# contoh: bash scripts/scaffold-livewire-feature.sh ResetPassword
#     atau: bash scripts/scaffold-livewire-feature.sh reset-password
```

Berbeda dari scaffolder SOP dokumentasi (`sop-projek-baru`) yang menyalin template statis, script ini men-generate kode dengan nama fitur disubstitusi ke tiap file — jadi outputnya baru tiap dipanggil, bukan template kosong. Tetap idempoten: file yang sudah ada dilewati, tidak ditimpa.

## Konvensi per layer

**Model**
- Selalu deklarasikan `$fillable` atau `$guarded` eksplisit — jangan andalkan default Eloquent. Mass assignment tanpa ini adalah lubang keamanan, bukan cuma gaya penulisan.
- Cast tipe data (`$casts`) untuk `date`, `boolean`, `array`/JSON, enum — jangan parse manual di tempat pemakaian.
- Scope query (`scopeActive`, dst.) untuk kondisi yang dipakai berulang. Kalau sebuah query builder chain dipakai di lebih dari satu tempat, itu kandidat scope.
- Relasi didefinisikan sekali di model; jangan tulis ulang join manual di Action yang bisa pakai relasi yang sudah ada.

**Migration**
- **Append-only setelah dijalankan di staging/produksi** — pola yang sama dengan ADR: jangan edit migration lama, buat migration baru untuk mengubah skema. Migration lama boleh diedit HANYA kalau belum pernah di-migrate di environment manapun selain lokal sendiri.
- Selalu isi `down()` yang benar-benar bisa membalikkan `up()`, kecuali memang sengaja destruktif (beri komentar kenapa).
- Kolom foreign key pakai `foreignId(...)->constrained()->cascadeOnDelete()` (atau `restrictOnDelete()` sesuai kebutuhan bisnis) — jangan biarkan default tanpa mikir kebijakan delete-nya.

**Action**
- Satu Action = satu operasi bisnis, dipanggil lewat `__invoke()`. Dependency (Model lain, service pihak ketiga, Mailer) masuk lewat constructor, bukan `new` di dalam method — supaya bisa di-mock saat test kalau perlu.
- Action tidak tahu soal HTTP atau Livewire. Return value-nya data/DTO/Model, bukan `RedirectResponse` atau `$this->dispatch()`.
- Kalau Action butuh transaksi DB, bungkus dengan `DB::transaction()` di dalam Action itu sendiri — jangan biarkan pemanggilnya (Livewire component) yang urus transaksi.

**Livewire component**
- Public property = state yang perlu tersinkron ke browser. Kalau sebuah nilai bisa dihitung dari public property lain, jadikan **computed property** (`#[Computed]` / method `getXProperty`), jangan public property terpisah yang bisa jadi tidak sinkron.
- Validasi pakai `rules()` di component untuk validasi sederhana, atau Form Request kalau logic validasinya kompleks/dipakai ulang. Jangan validasi manual dengan if-else.
- **Authorize di `mount()` atau sebelum aksi berbahaya** (`updating`, method yang mengubah data) — Livewire component adalah endpoint publik yang bisa dipanggil langsung lewat request AJAX, bukan cuma lewat tampilan yang terlihat. Tidak ada authorization check di component == tidak ada authorization sama sekali.
- `wire:model.live` untuk input yang perlu reaktif instan (search-as-you-type ke halaman lain), tapi kalau itu memicu query DB tiap keystroke, tambahkan `.debounce.300ms`. `wire:model` (tanpa `.live`) untuk form biasa yang cukup sync saat submit.
- Query di `render()` harus ringan (query yang sudah pasti kepakai). Query berat/kondisional taruh di computed property supaya Livewire bisa cache dalam satu request lifecycle.

**Blade & Alpine**
- Ekstrak markup berulang jadi Blade component (`resources/views/components/`), bukan `@include` dengan banyak variabel yang saling bergantung.
- `x-data` di Alpine untuk state UI lokal murni: dropdown terbuka/tutup, tab aktif, preview sebelum submit. Begitu state itu perlu dikirim ke server, itu domain Livewire — jangan duplikasi variabel yang sama di `x-data` dan `public property` Livewire; sinkronkan lewat `$wire.entangle()` kalau memang harus dua-duanya.
- Jangan taruh keputusan bisnis di `@php ... @endphp`. Kalau ada kondisi lebih dari perbandingan sederhana, itu harusnya accessor di Model atau computed property di Livewire.

**Form Request**
- `authorize()` wajib diisi eksplisit sesuai kebutuhan (pakai Policy/Gate), bukan `return true;` asal supaya validasi jalan.
- Pesan error custom (`messages()`) dalam Bahasa Indonesia kalau UI-nya Bahasa Indonesia — konsistensi bahasa end-to-end.

**Job / Queue**
- Job harus idempoten — aman dijalankan dua kali kalau retry oleh queue worker (cek dulu apakah efeknya sudah terjadi sebelum eksekusi ulang).
- Implementasikan `failed(Throwable $e)` untuk job yang efeknya penting (pembayaran, notifikasi krusial) — jangan biarkan kegagalan silent di background.

## Anti-pattern yang wajib ditolak

- **N+1 query** — kalau me-loop relasi di Blade/Livewire tanpa eager load (`with()`/`load()`), itu N+1. Tambahkan `Model::preventLazyLoading(!app()->isProduction())` di `AppServiceProvider::boot()` kalau projek belum punya, supaya lazy loading yang tidak sengaja langsung ketahuan di lokal/test, bukan baru ketahuan pas produksi lambat.
- **`env()` dipakai di luar file `config/`** — env value harus dibaca lewat `config('nama.key')` di kode aplikasi, supaya bisa di-cache (`config:cache`) dan konsisten di semua environment.
- **Raw query dengan string concatenation** — selalu parameter binding (`DB::select($sql, $bindings)` atau query builder/Eloquent). String concatenation ke SQL adalah SQL injection, bukan "cepat aja dulu".
- **Controller/Livewire component yang manggil model lain secara langsung untuk logika lintas-domain** — kalau sebuah aksi menyentuh lebih dari satu Model dengan business rule di antaranya, itu tanda harus jadi Action, bukan ditulis inline.
- **Mengedit migration yang sudah jalan di staging/produksi** — buat migration baru. Riwayat migration adalah riwayat skema; mengedit yang lama membuat migrate environment lain gagal atau silent drift.
- **Livewire component tanpa authorization check** untuk aksi yang mengubah data milik user lain (mis. admin action) — anggap tiap public method di component sebagai endpoint yang bisa dipanggil siapa saja yang tahu component ID-nya.

## Alur kerja

### Fitur baru (CRUD atau alur multi-langkah)

1. Kalau ini keputusan arsitektur (pilih paket baru, ubah pola auth, ubah alur bisnis) — tulis ADR dulu lewat skill `sop-projek-baru` sebelum lanjut.
2. `bash scripts/scaffold-livewire-feature.sh <NamaFitur>` untuk kerangka Action + Livewire component + view + Form Request + test.
3. Isi Action dengan logika bisnis inti, test-kan **tanpa** HTTP/Livewire (`tests/Unit/Actions/`).
4. Sambungkan Livewire component ke Action, isi `rules()`/Form Request, tambahkan authorization check.
5. Daftarkan route (`Route::get(...)->name(...)` atau langsung dipakai sebagai full-page component) — script scaffold mencetak potongan route yang perlu ditambahkan manual.
6. Test Feature dengan `Livewire::test(Nama::class)` untuk interaksi component (lihat contoh test hasil scaffold).

### Controller/model gemuk yang perlu direfactor

Tarik logika bisnis ke Action baru, sisakan Controller/Livewire component sebagai orkestrator tipis (terima input → panggil Action → balikin response/state). Pindahkan satu tanggung jawab per commit supaya gampang direview, jangan refactor semuanya sekaligus dalam satu PR besar.

### Query lambat / N+1 ditemukan

1. Aktifkan `Model::preventLazyLoading()` di lokal kalau belum, supaya semua titik N+1 kelihatan sekaligus lewat exception, bukan satu-satu.
2. Ganti akses relasi jadi eager load (`with(['relasi.subRelasi'])`) di titik query awal, bukan di titik pemakaian.
3. Kalau butuh agregasi lintas banyak baris, pertimbangkan query builder dengan `select`/`groupBy` daripada load semua model lalu hitung di PHP.

## Testing dengan Pest

- **Feature test**: HTTP flow penuh (`$this->get()->assertOk()`, `actingAs($user)`) atau `Livewire::test(Nama::class)->set(...)->call(...)->assertSet(...)`. Ini yang membuktikan Action, validasi, dan authorization benar-benar tersambung.
- **Unit test**: Action ditest langsung sebagai class PHP biasa, tanpa `RefreshDatabase` kalau tidak menyentuh DB, atau dengan factory kalau perlu data.
- Selalu pakai **factory** (`Nama::factory()->create()`) untuk data test, jangan `DB::table()->insert()` manual — factory ikut berubah kalau schema berubah, insert manual tidak.
- `RefreshDatabase` trait di setiap test yang menyentuh DB supaya test tidak saling bocor state.
- Nama test pakai kalimat deskriptif (`it('menolak reset password dengan OTP kedaluwarsa', function () { ... })`), bukan `test_reset_password_1`.
- Kalau projek juga punya lapisan e2e (Playwright), itu domain skill `qa-automation` — Pest untuk Feature/Unit di dalam boundary Laravel, e2e untuk alur lintas-browser yang menyentuh JS.

## Yang sengaja TIDAK dipaksa jadi Action

Operasi CRUD trivial satu baris (`Model::create($validated)` tanpa side effect atau business rule) boleh langsung di Livewire component/Controller — membungkusnya jadi Action cuma menambah indirection tanpa manfaat. Litmus test-nya sama seperti di atas: kalau tidak ada logika untuk ditest terpisah, tidak perlu layer terpisah.
