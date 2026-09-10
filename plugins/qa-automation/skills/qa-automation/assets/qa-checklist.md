# Checklist QA

> Dokumen *living*: edit di tempat, riwayat lewat `git log -p docs/qa/checklist.md`.

Terakhir diperbarui: YYYY-MM-DD

## Sebelum PR di-merge

- [ ] Suite e2e hijau di CI (bukan hijau karena test di-skip)
- [ ] Perilaku baru punya test di lapisan termurah yang masih menangkap regresinya
- [ ] Bug yang diperbaiki punya test regresi yang merah sebelum fix
- [ ] Tidak ada `test.only`, `waitForTimeout`, atau selector CSS berantai yang baru
- [ ] Test baru sudah punya test case padanan di Huly dengan **nama yang persis sama**

## Yang sengaja diverifikasi manual

Isi dengan alasannya, supaya tidak ada yang mencoba mengotomasi ulang lalu menyerah setengah jalan.

| Area | Kenapa manual | Siapa yang cek |
|---|---|---|
| Tampilan cetak struk | butuh printer fisik | QA |
| Pembayaran kartu asli | sandbox tidak mencerminkan 3DS bank | QA + Finance |

## Test yang sedang dikarantina

Kosongkan secepat mungkin — karantina lebih dari satu sprint berarti test-nya dihapus.

| Test | Issue | Sejak | Penyebab dugaan |
|---|---|---|---|
| | | | |

## Data test

- Akun/tenant khusus test, jangan pakai data produksi.
- Data dibuat lewat API atau seed script, tidak lewat UI.
- Setiap test membersihkan datanya sendiri supaya bisa jalan paralel.
