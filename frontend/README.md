# Qabas

Flutter application for Qabas (`com.rw.qabas`), with English and Arabic support.

## Setup

Install Flutter, then run:

```sh
flutter pub get
dart run tool/merge_arb.dart
flutter gen-l10n
flutter analyze
```

## Configuration

`config/live.json` is a production configuration template. Replace its placeholder API URL with your backend URL before running:

```sh
flutter run --dart-define-from-file=config/live.json
```

Private mock fixtures, grading keys, recording kits, internal documentation, AI assistant files and local credentials are excluded from Git. Demo builds and development tests require separately supplied local files.

The current `pubspec.yaml` declares local mock assets. Before building a production release from a fresh clone, remove its marked mock-asset block. Validate the resulting release with `tool/check_release_bundle.sh`.

Keep credentials outside version control. Store runtime access tokens using the app's secure storage.
