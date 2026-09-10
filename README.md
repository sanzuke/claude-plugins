# Claude Plugins — Internal

Marketplace plugin internal. Semua tim menambahkan marketplace ini sekali, lalu
install plugin yang dibutuhkan.

## Untuk pengguna

```bash
claude plugin marketplace add sanzuke/claude-plugins
claude plugin install sop-projek-baru@qti-plugins
claude plugin install qa-automation@qti-plugins
claude plugin install laravel-fullstack@qti-plugins
```

Kalau install summary menyebut `Run /reload-plugins to activate.`, jalankan itu.

Skill dari plugin di-namespace dengan nama plugin:

```
/sop-projek-baru:sop-projek-baru
/qa-automation:qa-automation
/laravel-fullstack:laravel-fullstack
```

## Plugin yang tersedia

| Plugin | Isinya |
|---|---|
| `sop-projek-baru` | SOP dokumentasi projek: scaffold `docs/adr`, `docs/domain`, `docs/runbook`, `CHANGELOG.md`, dan menjaga ADR tetap hidup seiring projek berkembang. |
| `qa-automation` | SOP QA automation: scaffold Playwright (TypeScript) + workflow CI, konvensi test anti-rapuh, kebijakan flaky test, dan pelaporan hasil run ke Huly Test Management. |
| `laravel-fullstack` | SOP developer PHP fullstack Laravel (Livewire + Blade + Alpine + Pest): konvensi Eloquent/Action/Livewire, anti-pattern yang wajib dihindari, dan scaffold vertical-slice fitur baru. |

Ketiga skill aktif otomatis dari konteks percakapan — perintah slash di atas hanya
cadangan manual.

## Supaya terpasang otomatis untuk tim

Salin isi `contoh-settings-repo-projek/.claude/settings.json` ke `.claude/settings.json`
di repo projek kalian, lalu commit. Claude Code menambahkan marketplace ini untuk
anggota tim begitu mereka mem-*trust* folder projeknya, tanpa prompt terpisah.

## Menambah plugin baru

1. Buat folder di `plugins/<nama-plugin>/` dengan `.claude-plugin/plugin.json`
   dan folder komponen (`skills/`, `commands/`, `agents/`, `hooks/`).
2. Tambahkan entri ke array `plugins` di `.claude-plugin/marketplace.json`.
   Minimal butuh `name` dan `source`.
3. Validasi: `claude plugin validate .` dari root repo ini.
4. Uji lokal sebelum push: `claude plugin marketplace add ./claude-plugins`
5. Commit dan push. Pengguna refresh dengan `claude plugin marketplace update`.

## Soal versi — baca sebelum rilis

Plugin di repo ini **sengaja tidak menyetel `version`**.

Kalau `version` disetel di `plugin.json` atau di entri marketplace, plugin ter-*pin*
ke string itu: pengguna baru dapat update kalau string-nya berubah. Push commit baru
tanpa menaikkan versi = pengguna tetap memakai salinan cache-nya, tanpa peringatan.

Dengan `version` dikosongkan pada source berbasis git, Claude Code memakai commit SHA
sebagai versi, jadi setiap commit baru otomatis jadi update. Ini yang paling cocok
untuk plugin internal yang masih aktif dikembangkan.

Kalau nanti mau versioning eksplisit, setel `version` **di satu tempat saja**.
Kalau disetel di `plugin.json` dan di entri marketplace sekaligus, nilai `plugin.json`
selalu menang tanpa peringatan — manifest yang basi bisa menutupi versi yang kamu
setel di `marketplace.json`.

## Rename atau hapus plugin

`name` adalah identitas permanen — dipakai di `enabledPlugins` dan perintah install
pengguna. Mengubahnya merusak semua instalasi yang sudah ada.

- Mau ganti label di UI saja? Setel `displayName`, biarkan `name` tetap.
- Harus ganti `name`, atau menghapus plugin? Tambahkan entri di `renames`
  (`"nama-lama": "nama-baru"`, atau `"nama-lama": null` kalau dihapus) supaya
  pengguna lama termigrasi otomatis, bukan kena error `plugin-not-found`.

Perlakukan `renames` sebagai riwayat append-only: jangan edit entri lama, tambahkan
entri baru. Claude Code mengikuti rantainya.

## Kalau repo ini private

Perintah manual (`install`, `marketplace update`) pakai git credential helper kamu
yang sudah ada, jadi jalan normal.

Yang perlu diperhatikan adalah auto-update di background: secara default, refresh
background menonaktifkan credential helper untuk `git pull`-nya, jadi tidak bisa
autentikasi ke repo private lewat HTTPS. Remote SSH tidak terpengaruh selama key-nya
ada di `ssh-agent`. Kalau pull gagal, Claude Code jatuh ke re-clone dari nol, yang
bisa timeout di repo besar.

Dua hal yang bikin ini stabil:

```bash
export CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1
gh auth setup-git
```

Yang pertama menahan clone lama saat pull gagal, jadi plugin tetap jalan dari state
terakhir. Yang kedua bikin fallback re-clone bisa autentikasi tanpa prompt.

## Catatan lain

- Nama marketplace harus kebab-case dan unik per pengguna. Beberapa nama dicadangkan
  untuk Anthropic (`anthropic-plugins`, `claude-plugins-official`, dan lainnya)
  serta nama yang menyerupainya.
- Jangan taruh folder `bin/` di level atas plugin kalau nanti mau distribusi lewat
  Organization settings — plugin dengan `bin/` top-level ditolak. Taruh executable
  di `scripts/`, referensikan sebagai `${CLAUDE_PLUGIN_ROOT}/scripts/<nama>`.
- Plugin disalin ke cache saat install, jadi jangan referensikan file di luar folder
  plugin (`../shared-utils`) — file itu tidak ikut tersalin.
