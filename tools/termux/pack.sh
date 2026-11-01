#!/usr/bin/env bash
# يجمع سيرفر بتّه + نسخة الويب (app/build/web_release) بملف واحد للجوال: tools/termux/batta-phone.tar.gz
# شغّله بعد build-web.ps1، وبعدين شغّل سيرفر «phone-download» (منفذ 8092) والجوال ينزله بـ setup.sh
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/tools/termux"
TMP="$(mktemp -d)"
mkdir -p "$TMP/public"
cp -r "$ROOT/server/src" "$ROOT/server/package.json" "$ROOT/server/node_modules" "$TMP/"
cp -r "$ROOT/app/build/web_release/." "$TMP/public/"
rm -f "$TMP/public/batta.apk" # الـ APK كبير وما يحتاجه السيرفر
cp "$OUT/batta.sh" "$TMP/"
tar -czf "$OUT/batta-phone.tar.gz" -C "$TMP" .
rm -rf "$TMP"
echo "packed $(du -h "$OUT/batta-phone.tar.gz" | cut -f1) -> tools/termux/batta-phone.tar.gz"
