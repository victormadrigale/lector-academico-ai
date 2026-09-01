#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter no está instalado. Instala Flutter estable y vuelve a ejecutar este script." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

flutter create \
  --platforms=android \
  --org com.lectoracademico \
  --project-name lector_academico_ai \
  "$TMP_DIR/bootstrap"

rm -rf android
cp -R "$TMP_DIR/bootstrap/android" ./android
python3 tool/patch_android.py
flutter pub get

echo "Android preparado. Ejecuta: flutter build apk --release"
