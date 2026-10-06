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

Development mock fixtures (including grading answer keys), mock configurations, documentation, `AGENTS.md`, `CLAUDE.md`, tests and source tools are included in the source repository so fresh clones can run development checks. Use a private source repository. Recording kits, local assistant settings, credentials and generated exports remain excluded from Git.

For Claude cloud review, configure the cloud environment with Flutter 3.44.2 (Dart 3.12.2) and Chrome for web tests. Read `CLAUDE.md` and `docs/PROGRESS.md` before making changes. The prototype source referenced by those rules lives outside this repository and must be supplied separately for visual changes; prototype screenshots are included in `docs/prototype/`.

The current `pubspec.yaml` declares local mock assets. Before building a production release from a fresh clone, remove its marked mock-asset block. Validate the resulting release with `tool/check_release_bundle.sh`.

Keep credentials outside version control. Store runtime access tokens using the app's secure storage.
