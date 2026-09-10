#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="$SCRIPT_DIR/../assets"

[ -d "$ASSETS" ] || { echo "assets/ tidak ditemukan di $ASSETS" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "target dir tidak ada: $TARGET" >&2; exit 1; }

cd "$TARGET"
echo "Scaffold QA automation di $(pwd)"

mkdir -p tests/e2e/specs tests/e2e/pages docs/qa .github/workflows

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

copy_if_absent "$ASSETS/playwright.config.ts" playwright.config.ts
copy_if_absent "$ASSETS/fixtures.ts"          tests/e2e/fixtures.ts
copy_if_absent "$ASSETS/login.page.ts"        tests/e2e/pages/login.page.ts
copy_if_absent "$ASSETS/example.spec.ts"      tests/e2e/specs/login.spec.ts
copy_if_absent "$ASSETS/e2e-workflow.yml"     .github/workflows/e2e.yml
copy_if_absent "$ASSETS/qa-checklist.md"      docs/qa/checklist.md

echo
echo "Selesai. Langkah berikutnya:"
echo "  1. npm i -D @playwright/test && npx playwright install --with-deps chromium"
echo '  2. Tambah skrip package.json: "test:e2e": "playwright test"'
echo "  3. Set E2E_BASE_URL (lokal via env, di CI via repository variable)"
echo "  4. Sesuaikan tests/e2e/specs/login.spec.ts ke alur login asli, pastikan hijau,"
echo "     baru tambah spec berikutnya"
