#!/usr/bin/env bash
# Scaffold struktur dokumentasi standar di root repo.
# Aman dipanggil berulang: file yang sudah ada tidak ditimpa.
#
# Pakai: bash scripts/scaffold.sh [target-dir]

set -euo pipefail

TARGET="${1:-.}"
ASSETS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../assets" && pwd)"

if [ ! -d "$ASSETS" ]; then
  echo "Folder assets tidak ditemukan di $ASSETS" >&2
  exit 1
fi

cd "$TARGET"

copy_if_absent() {
  local src="$1" dest="$2"
  if [ -e "$dest" ]; then
    echo "  lewat  $dest (sudah ada)"
  else
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "  buat   $dest"
  fi
}

echo "Scaffold dokumentasi di $(pwd)"

mkdir -p docs/adr docs/domain docs/runbook

copy_if_absent "$ASSETS/adr-template.md"    "docs/adr/TEMPLATE.md"
copy_if_absent "$ASSETS/business-flow.md"   "docs/domain/business-flow.md"
copy_if_absent "$ASSETS/glossary.md"        "docs/domain/glossary.md"
copy_if_absent "$ASSETS/CHANGELOG.md"       "CHANGELOG.md"

if [ ! -e docs/runbook/deploy.md ]; then
  mkdir -p docs/runbook
  printf '# Runbook Deploy\n\n> Dokumen living. Langkah deploy, rollback, dan siapa yang dihubungi saat gagal.\n\n## Prasyarat\n\n## Langkah deploy\n\n## Rollback\n\n## Kalau gagal\n' > docs/runbook/deploy.md
  echo "  buat   docs/runbook/deploy.md"
else
  echo "  lewat  docs/runbook/deploy.md (sudah ada)"
fi

echo
echo "Selesai. Langkah berikutnya:"
echo "  1. Isi docs/domain/glossary.md bersama stakeholder"
echo "  2. Tulis docs/adr/0001-<slug>.md untuk keputusan stack awal"
echo "  3. Jalankan /init, lalu rapikan CLAUDE.md pakai assets/CLAUDE.md.template"
