#!/bin/sh
# Publish an existing APK; the website always links to the latest qabas.apk.
set -eu
if [ "$#" -ne 2 ]; then
  echo 'Usage: sh tool/publish_android_release.sh VERSION PATH_TO_APK' >&2
  exit 1
fi
qabas_release_version="$1"
qabas_release_apk="$2"
case "$qabas_release_version" in
  ''|*[!0-9A-Za-z._-]*) echo 'Invalid release version' >&2; exit 1 ;;
esac
[ -f "$qabas_release_apk" ] || { echo 'APK file not found' >&2; exit 1; }
qabas_release_tmp=$(mktemp -d)
trap 'rm -rf "$qabas_release_tmp"' EXIT INT TERM
cp "$qabas_release_apk" "$qabas_release_tmp/qabas.apk"
(cd "$qabas_release_tmp" && shasum -a 256 qabas.apk > SHA256SUMS)
cat > "$qabas_release_tmp/notes.md" <<'NOTES'
Download **qabas.apk** and install it on Android 7.0 or later.

This preview uses bundled sample content and does not connect to a live backend.
SHA-256 checksums are provided in **SHA256SUMS**.
NOTES
gh release create "v$qabas_release_version" \
  "$qabas_release_tmp/qabas.apk" "$qabas_release_tmp/SHA256SUMS" \
  --repo r-abdulwahed/qabas-downloads \
  --title "Qabas for Android · $qabas_release_version" \
  --notes-file "$qabas_release_tmp/notes.md" --latest
