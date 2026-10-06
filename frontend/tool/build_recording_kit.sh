#!/bin/sh
# Build the private recording release and refresh the root handoff artifact.
set -eu
cd "$(dirname "$0")/.."
df -h /System/Volumes/Data
flutter build apk --release --dart-define-from-file=config/recording.json
python3 tool/check_release_bundle.py build/app/outputs/flutter-apk/app-release.apk --demo
mkdir -p Qabas-Recording
cp build/app/outputs/flutter-apk/app-release.apk Qabas-Recording/Qabas-recording.apk
(cd Qabas-Recording && shasum -a 256 Qabas-recording.apk > SHA256SUMS)
echo 'Recording APK ready in Qabas-Recording/. Keep the recording scripts with it.'
