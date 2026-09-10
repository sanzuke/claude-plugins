#!/usr/bin/env bash
set -euo pipefail

# Generate satu vertical slice fitur Laravel: Action + Livewire component + Blade
# view + Form Request + test Pest (Feature + Unit). Berbeda dari scaffolder
# sop-projek-baru/qa-automation yang menyalin template statis apa adanya — script
# ini mensubstitusi nama fitur ke tiap file, jadi isinya baru tiap dipanggil.
# Tetap idempoten: file yang sudah ada dilewati, tidak pernah ditimpa.
#
# Usage: bash scaffold-livewire-feature.sh <NamaFitur> [target-dir]
#   Nama boleh StudlyCase, camelCase, kebab-case, atau snake_case — dinormalisasi
#   otomatis. Contoh: ResetPassword, reset-password, reset_password semua valid.

if [ $# -lt 1 ]; then
  echo "Usage: $0 <NamaFitur> [target-dir]" >&2
  exit 1
fi

RAW_NAME="$1"
TARGET="${2:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="$SCRIPT_DIR/../assets"

[ -d "$ASSETS" ] || { echo "assets/ tidak ditemukan di $ASSETS" >&2; exit 1; }
[ -d "$TARGET" ] || { echo "target dir tidak ada: $TARGET" >&2; exit 1; }
[ -f "$TARGET/artisan" ] || echo "peringatan: $TARGET/artisan tidak ditemukan — yakin ini root project Laravel?" >&2

# Pecah StudlyCase/camelCase/kebab-case/snake_case jadi kata-kata lowercase.
words=$(echo "$RAW_NAME" \
  | sed -E 's/([a-z0-9])([A-Z])/\1 \2/g' \
  | sed -E 's/[-_]+/ /g' \
  | tr '[:upper:]' '[:lower:]')

IFS=' ' read -ra WORDS <<< "$words"
if [ "${#WORDS[@]}" -eq 0 ]; then
  echo "Nama fitur tidak valid: $RAW_NAME" >&2
  exit 1
fi

studly=""
kebab=""
snake=""
for i in "${!WORDS[@]}"; do
  w="${WORDS[$i]}"
  studly+="${w^}"
  sep=$([ "$i" -eq 0 ] && echo "" || echo "-")
  kebab+="${sep}${w}"
  sep=$([ "$i" -eq 0 ] && echo "" || echo "_")
  snake+="${sep}${w}"
done
camel="${studly,}"

echo "Scaffold fitur Laravel: $studly (camel=$camel kebab=$kebab) di $(cd "$TARGET" && pwd)"

render() {
  local src="$1" dest="$2"
  if [ -e "$dest" ]; then
    echo "  lewat  $dest (sudah ada)"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  sed -e "s/__STUDLY__/${studly}/g" \
      -e "s/__CAMEL__/${camel}/g" \
      -e "s/__KEBAB__/${kebab}/g" \
      -e "s/__SNAKE__/${snake}/g" \
      "$src" > "$dest"
  echo "  buat   $dest"
}

cd "$TARGET"

render "$ASSETS/action.php.tmpl"             "app/Actions/${studly}Action.php"
render "$ASSETS/livewire-component.php.tmpl" "app/Livewire/${studly}.php"
render "$ASSETS/livewire-view.blade.php.tmpl" "resources/views/livewire/${kebab}.blade.php"
render "$ASSETS/form-request.php.tmpl"       "app/Http/Requests/${studly}Request.php"
render "$ASSETS/feature-test.php.tmpl"       "tests/Feature/${studly}Test.php"
render "$ASSETS/action-test.php.tmpl"        "tests/Unit/Actions/${studly}ActionTest.php"

echo
echo "Selesai. Langkah berikutnya:"
echo "  1. Isi logika bisnis di app/Actions/${studly}Action.php, test-kan tanpa HTTP dulu"
echo "     (hapus ->todo() di tests/Unit/Actions/${studly}ActionTest.php setelah diisi)"
echo "  2. Isi authorize() di app/Http/Requests/${studly}Request.php dan mount() di component"
echo "  3. Tambah route:"
echo "       Route::get('/${kebab}', \\App\\Livewire\\${studly}::class)->name('${kebab}');"
echo "  4. php artisan test --filter=${studly}"
