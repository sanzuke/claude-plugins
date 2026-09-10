---
name: sop-projek-baru
description: SOP standar perusahaan untuk struktur dokumentasi projek — scaffold docs/adr, docs/domain, CHANGELOG, dan CLAUDE.md di repo baru, lalu menjaganya tetap hidup seiring projek berkembang. WAJIB dipakai setiap kali memulai repo atau projek baru, menjalankan git init, membuat struktur folder awal, atau saat ada keputusan arsitektur/teknologi yang diambil (pilih framework, ganti library, ubah alur bisnis, ubah skema database, ganti pola auth atau payment). Pakai juga ketika user bertanya "kenapa dulu kita pilih X", ketika repo lama belum punya dokumentasi terstruktur, dan ketika naik versi mayor. Jangan tunggu user menyebut kata "ADR", "dokumentasi", atau "SOP" — kalau sebuah keputusan teknis sedang diambil atau projek baru sedang dibuat, skill ini berlaku.
---

# SOP Dokumentasi Projek

Tujuan SOP ini: **alasan di balik keputusan tidak hilang saat projek naik versi atau ganti orang.**

Kode menjelaskan *apa* yang dilakukan sistem. Yang tidak bisa disimpulkan dari kode adalah *kenapa* — kenapa pakai queue padahal sync lebih sederhana, kenapa aturan diskon dibuat begitu, kenapa endpoint ini sengaja tidak di-cache. Itu yang paling sering hilang, dan paling mahal saat orang baru masuk atau saat kamu sendiri kembali ke projek itu enam bulan kemudian.

## Dua jenis dokumen — jangan tertukar

Ini kunci seluruh SOP. Kesalahan paling umum adalah memperlakukan dokumen *living* seperti *append-only* (bikin `flow-v1.md`, `flow-v2.md`), lalu tidak ada yang tahu mana yang masih berlaku.

| | Append-only | Living |
|---|---|---|
| Contoh | ADR, CHANGELOG | alur bisnis, glossary, runbook |
| Cara ubah | tidak pernah diedit; bikin entri baru | diedit di tempat |
| Kalau usang | tandai `Superseded by ADR-XXXX` | timpa saja |
| Riwayat | terbaca dari rantai dokumen | terbaca dari `git log -p` |

Untuk dokumen living, jangan simpan versi manual. Git sudah menyimpannya: `git log -p docs/domain/business-flow.md`.

## Struktur standar

```
docs/
├── adr/
│   ├── 0001-<slug-keputusan>.md
│   └── 0002-<slug-keputusan>.md
├── domain/
│   ├── business-flow.md      # alur bisnis end-to-end
│   └── glossary.md           # istilah domain + padanan di kode
└── runbook/
    └── deploy.md
CHANGELOG.md
CLAUDE.md                     # peta, bukan gudang
```

Template untuk tiap file ada di `assets/`. Salin, jangan tulis ulang dari nol.

## Alur kerja

### Saat projek baru dibuat

1. Jalankan `scripts/scaffold.sh` dari root repo. Script ini membuat struktur di atas dari template dan berhenti kalau `docs/` sudah ada, jadi aman dipanggil dua kali.
2. Isi `docs/domain/glossary.md` bersama user. Ini langkah yang paling sering dilewat dan paling menyakitkan kalau dilewat — istilah domain yang tidak sama antara stakeholder dan kode adalah sumber bug yang tidak kelihatan. Tanyakan istilah-istilah yang dipakai user, dan catat padanannya di kode.
3. Tulis ADR-0001 untuk keputusan stack awal. Bahkan kalau pilihannya terasa "ya sudah jelas" — justru yang terasa jelas hari ini yang paling sulit dijelaskan setahun lagi.
4. Jalankan `/init` untuk generate CLAUDE.md, lalu rapikan pakai `assets/CLAUDE.md.template` sebagai acuan bagian dokumentasinya.

### Saat keputusan teknis diambil (di tengah projek)

Ini bagian yang membuat SOP hidup, bukan sekadar ritual hari pertama.

Kalau dalam percakapan muncul keputusan yang memenuhi salah satu dari ini, tawarkan menulis ADR sebelum lanjut ngoding:

- pilihan antara dua teknologi atau pendekatan yang sama-sama masuk akal
- keputusan yang membatalkan atau mengubah keputusan sebelumnya
- keputusan yang akan membingungkan orang lain kalau lihat kodenya tanpa konteks
- trade-off yang disadari dan sengaja diambil ("kita terima lambat di sini demi X")

Yang **tidak** perlu ADR: pilihan yang jelas satu-satunya, detail implementasi, penamaan variabel, hal yang bisa dibaca langsung dari kode.

Kalau keputusan baru membatalkan yang lama: jangan hapus atau edit ADR lama. Buat ADR baru, dan ubah status ADR lama jadi `Superseded by ADR-XXXX`. Rantai inilah yang menjawab "kenapa dulu begitu, kenapa sekarang begini".

### Saat naik versi

1. Perbarui `CHANGELOG.md`.
2. Cek `docs/domain/` — kalau alur bisnis berubah, edit di tempat.
3. Cek ADR yang statusnya `Accepted` — masih berlaku semua? Yang sudah tidak, tandai superseded.

### Saat menutup sesi kerja

Sebelum sesi berakhir, perbarui catatan progres dan dokumentasi yang tersentuh hari itu: apa yang selesai, apa yang pending, keputusan apa yang diambil dan alasannya.

Simpan status harian di issue tracker, **bukan** di file yang di-commit. Dokumen progres harian di git menghasilkan commit noise dan merge conflict di file yang tidak ada hubungannya dengan kode. Git untuk yang durable.

## Apa yang layak ditulis

Buang hal yang bisa disimpulkan sendiri dari codebase — struktur direktori, daftar dependency, overview arsitektur yang tinggal dibaca dari kode. Pertahankan pitfall, alasan di balik keputusan, dan konvensi yang menyimpang dari default tool.

Uji dengan pertanyaan ini: *kalau kalimat ini dihapus, apakah orang lain bisa menemukannya kembali dari kode?* Kalau bisa, jangan ditulis. Kalau tidak bisa, itu justru yang paling berharga.

## Menjaga CLAUDE.md tetap ramping

CLAUDE.md dimuat di setiap sesi, jadi targetkan di bawah 200 baris — file yang lebih panjang makan konteks dan justru menurunkan kepatuhan. Jadikan dia peta yang menunjuk ke `docs/`, bukan tempat menyalin isinya:

```markdown
## Dokumentasi
- Alur bisnis: @docs/domain/business-flow.md
- Istilah domain: @docs/domain/glossary.md
- Keputusan arsitektur: lihat docs/adr/, baca yang statusnya Accepted

Sebelum mengubah <area sensitif>, baca ADR-XXXX.
```

Untuk aturan yang cuma relevan di sebagian codebase, pakai `.claude/rules/` dengan frontmatter `paths` supaya baru masuk konteks saat Claude menyentuh file yang cocok:

```markdown
---
paths:
  - "app/Services/Payment/**/*.php"
---
Baca ADR-0003 sebelum mengubah driver payment gateway.
```

## Untuk repo yang sudah jalan

Jangan coba merekonstruksi seluruh riwayat sekaligus — hasilnya karangan, bukan dokumentasi. Sebagai gantinya:

1. Scaffold strukturnya.
2. Tulis ADR hanya untuk keputusan yang **masih hidup** dan masih membingungkan orang. Tanya user mana saja itu.
3. Beri nomor mundur kalau perlu, dan tulis di Context bahwa ADR ini ditulis belakangan.
4. Sisanya biarkan. ADR berikutnya ditulis saat keputusan berikutnya diambil.
