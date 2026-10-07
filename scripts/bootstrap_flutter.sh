#!/usr/bin/env bash
# Sinh thư mục android/ cho mobile_app (cần Flutter SDK + Python 3).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/mobile_app"
TMP="$(mktemp -d)"
flutter create --org com.workflow --project-name workflow_mobile --platforms=android "$TMP"
rm -rf "$APP/android"
cp -R "$TMP/android" "$APP/android"
rm -rf "$TMP"
python3 "$ROOT/scripts/prepare_android.py" "$APP"
cd "$APP"
flutter pub get
printf '\nHoàn tất. Chạy: flutter run (hoặc flutter build apk --release)\n'
