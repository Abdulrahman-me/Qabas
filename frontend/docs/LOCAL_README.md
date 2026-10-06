# Qabas

Production Flutter app (`qabas`, `com.rw.qabas`). Start with [docs/PROGRESS.md](docs/PROGRESS.md), then the current phase in [docs/PHASES.md](docs/PHASES.md). Architecture, design and the contract are indexed in [docs/handoff/README.md](docs/handoff/README.md).

The demo spine includes onboarding, Journey/Soft Locks, Discover, the lesson player with generated scenes, grading/retries, completion/streak, Raqeeb, Profile, Settings and About. The physical mid-range Android scene-performance gate remains open in Phase 7. Persistent session resume and the remaining learning/community features arrive in their assigned later phases.

```sh
flutter run --dart-define-from-file=config/mock.json
flutter run -d chrome --dart-define-from-file=config/mock.json
flutter run --dart-define-from-file=config/demo.json
```

Long-press the Profile avatar to open developer tools in debug builds. Switch language, motion, sound, haptics and character casting there; the auth/profile probe exercises the mock API. The gallery uses these same persisted settings. Salah previews cover all four language/track variants; the Unit 0 picker follows the normal prerequisite rules.

Demo onboarding has seven pages. Mock mode enables the optional curiosity page when the current language's bundled question and all six labels are present; Arabic currently skips it because that copy is pending. Mock learner state survives restarts, while the bearer token stays in secure storage. Use “Reset mock database” to start again, “Revoke token” to test session recovery, or “Next HTTP 426” to open the update gate.

Web layouts support narrow and short windows, centred reading content and a navigation rail from 840 px. Native phones use portrait orientation; browser orientation is unrestricted.

`config/hybrid.json` targets a local backend and has no live groups by default. `config/live.json` targets the hosted backend at `https://qabas-zdcz.onrender.com/v1` (every group live). The hosted service sleeps when idle, so the first launch can take up to a minute; splash explains the wait. Its CORS list allows `https://qabas-app.pages.dev`; to run the live web app from another origin (including `flutter run -d chrome` on localhost), add that origin to the backend's `CORS_ALLOWED_ORIGINS`. Production requires live mode and excludes developer tools. Before a production build, remove the marked mock-asset block as specified in [handoff 07 §8](docs/handoff/07_MOCKS_AND_BACKEND_SYNC.md#8-keeping-mocks-out-of-production).

```sh
dart run tool/merge_arb.dart && flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test && sh tool/check_rules.sh
sh tool/test_web.sh
flutter build web --debug --dart-define-from-file=config/mock.json
flutter build ios --config-only --no-codesign --dart-define-from-file=config/mock.json
python3 tool/prepare_ios_plugins.py
flutter test --no-pub integration_test/character_contract_test.dart -d <simulator> --dart-define-from-file=config/mock.json
```

The iOS minimum is 14.0. Run the `--config-only` and preparation commands above after dependency changes, then use `--no-pub` for simulator tests/runs. The preparation script aligns only the generated ephemeral Swift package with Runner’s deployment target. If Xcode reports missing package products, resolve its local graph with `xcodebuild -resolvePackageDependencies -project ios/Runner.xcodeproj -scheme Runner` before retrying. Run Flutter commands sequentially: concurrent commands can regenerate temporary iOS plugin files while Xcode reads them. Flutter updates the generated Swift package's minimum from Runner during native builds; see its [higher deployment-target guidance](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers#how-to-use-a-swift-package-manager-flutter-plugin-that-requires-a-higher-os-version).

To save the simulator screenshots in `build/tour/phase2/`, use the same preparation command, then:

```sh
flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/character_contract_test.dart -d <simulator> --dart-define-from-file=config/mock.json
```

The Phase 3 tour saves English/Arabic onboarding captures, retry, session recovery, curiosity and update-gate captures in `build/tour/phase3/`:

```sh
flutter drive --no-pub --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/phase3_onboarding_test.dart -d <simulator> --dart-define-from-file=config/mock.json
```

Add `--dart-define=PHASE3_TOUR=splash` for the splash/bootstrap gate check or `--dart-define=PHASE3_TOUR=curiosity` for the optional page and update gate. `--keep-app-running` preserves the simulator install and its mock preferences for a subsequent ordinary app launch; Flutter's driver otherwise uninstalls it after testing.

After the retained-install tour, launch the ordinary app, quit with `q` to stop its process, then run the same command again to verify reopening with the stored token/profile:

```sh
flutter run --no-pub -d <simulator> --dart-define-from-file=config/mock.json
```

The Phase 4 tour checks Journey, Soft Lock entry, Discover, developer progression and track switching in English/Arabic with both motion settings. Captures are saved in `build/tour/phase4/`:

```sh
flutter drive --no-pub --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/phase4_journey_test.dart -d <simulator> --dart-define-from-file=config/mock.json
```

Run Flutter build, test and drive commands sequentially on this workspace; simultaneous commands can regenerate iOS plugin packages while Xcode reads them.

The Phase 5 tour checks Journey → intro → player for 0.1, Discover → 1.1 on both tracks, and both Salah developer variants in each language/motion setting. Captures are saved in `build/tour/phase5/`:

```sh
flutter drive --no-pub --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/phase5_content_test.dart -d <simulator> --dart-define-from-file=config/mock.json
```

Add `--dart-define=PHASE5_TOUR=fidelity` for the focused English comparison, `ar-fidelity` for Arabic with reduced motion, or `final` for both. These tours retain the entry checks and settle every entrance before capture. The Phase 5 entry above records its historical content-preview tour. The current Chrome test server also serves private grading fixtures to the development fake server on localhost; use the Phase 6 tour for the current player.

## Phase 6 exercise verification

The lesson player now submits typed answers through the contract client and the
mock grader, shows warm feedback and misconception cards, retries missed lesson
exercises once, and finishes into the temporary result page. Completion and
journey progression are Phase 8. Recitation keeps the verse and meaning; the
supplied demo audio/checker are unavailable, so use skip followed by Continue.

```sh
flutter test --no-pub test/features/session/exercise_flow_test.dart test/features/session/exercise_responsive_test.dart
sh tool/test_web.sh
flutter build web --debug --no-pub --dart-define-from-file=config/mock.json
flutter build web --debug --no-pub --dart-define-from-file=config/demo.json
python3 tool/prepare_ios_plugins.py
flutter drive --no-pub --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/phase6_exercises_test.dart -d <simulator> --dart-define-from-file=config/mock.json
```

The Phase 6 simulator tour saves captures in `build/tour/phase6/`. It plays
Journey → 0.1, later 0.2/0.12 exercise types, Discover → 1.1 on both tracks,
and Salah from the developer menu in English/Arabic and both motion settings.
Explorer Salah deliberately misses the myth correction and completes its retry;
New Muslim Salah is played correctly. One Unit 0 submission fails offline and
is retried with its draft intact. Add `--dart-define=PHASE6_TOUR=final` for a
focused Salah tour in English with motion and Arabic with reduced motion.

The localhost Chrome asset helper serves development fixtures, including private
keys used only by the fake server in tests. It is not a production asset server.
The old Phase 5 tour records the content-preview milestone; use the Phase 6 tour
for the current player.

## Phase 7 scene verification

The local [qabas_scene package](packages/qabas_scene/README.md) implements the
seven released renderer capabilities and verifies manifests against SceneRef
before painting. Story beats and teaching points update the mounted scene's
state. Reduced motion fixes tracks and particles at the authored still time.
Unsupported or unavailable scenes use the supplied image, then alt fallback.

```sh
(cd packages/qabas_scene && flutter analyze --no-pub && flutter test --no-pub)
flutter test --no-pub test/scenes/
sh tool/test_web.sh
flutter build web --debug --no-pub --dart-define-from-file=config/mock.json
flutter build web --debug --no-pub --dart-define-from-file=config/demo.json
python3 tool/prepare_ios_plugins.py
flutter drive --no-pub --keep-app-running --driver=test_driver/phase7_scenes.dart --target=integration_test/phase7_scenes_test.dart -d <device> --dart-define-from-file=config/mock.json
python3 tool/drive_phase7_scenes.py --device emulator-5554
```

The native tour measures all 20 scenes and plays lesson 0.1 in English/Arabic
with reduced motion on/off. Captures go to `build/tour/phase7/`; measured frame
timings go to `build/phase7/<platform>_frame_timings.json`. The still test saves
all 86 frames and their pixel errors in `build/phase7/`. Run native and browser
Flutter commands sequentially and keep only one simulator/emulator booted.
Use the Python helper for Android; it captures through adb without changing
Flutter's surface. Add `--tour flow` or `--tour benchmark` for a focused repeat.
The equivalent iOS drive command accepts `--dart-define=PHASE7_TOUR=flow` or
`benchmark`. The timing pass measures naturally scheduled frames after warming
the empty app and reports cold manifest-to-first-frame time separately.

## Phase 8 completion verification

The ordinary mock flow is Journey → 0.1 → completion → first-day streak → Journey.
0.1 becomes completed and 0.2 available. Finish 1.1 from Discover on the same day:
both surfaces show completion, with no second streak celebration. Result routes
recover their stored snapshot after restarting the dev/demo app.

```sh
flutter test --no-pub test/features/session/completion_backend_test.dart test/features/session/completion_responsive_test.dart
sh tool/test_web.sh
python3 tool/drive_phase8_completion.py --device <simulator-or-emulator-id>
```

The tour covers English/Arabic, motion/reduced motion, 0.1, Discover 1.1 and a
Salah reference mistake/retry (83% accuracy, 67% Understanding, 100% Applying).
Screenshots go to `build/tour/phase8/`. The Android host helper captures adb's
actual surface because Android 17's integration screenshot conversion stalls
with external Rive textures; iOS uses the normal screenshot callback. Keep one
simulator/emulator booted. Prepare the iOS build configuration before the tour
using the existing instructions above.

If Flutter regenerates the Swift package at iOS 13 during the tour, prepare the
integration target and build it with Xcode before driving the prebuilt app:

```sh
flutter build ios --config-only --debug --no-codesign --no-pub --target=integration_test/phase8_completion_test.dart --dart-define-from-file=config/mock.json
python3 tool/prepare_ios_plugins.py
xcodebuild -project ios/Runner.xcodeproj -scheme Runner -configuration Debug -sdk iphonesimulator -destination id=<simulator-id> -derivedDataPath build/ios -clonedSourcePackagesDirPath ios/Flutter/ephemeral/Packages/SourcePackages CONFIGURATION_BUILD_DIR="$PWD/build/ios/iphonesimulator" build
python3 tool/drive_phase8_completion.py --device <simulator-id> --use-application-binary=build/ios/iphonesimulator/Runner.app
```

The helper stops on a build/launch failure before Flutter can connect to an old
test app. Restore the ordinary app afterward by preparing the `lib/main.dart`
target, rebuilding, and running that app.

## Phase 9 Raqeeb verification

Raqeeb accepts text through the ordinary multipart API client, shows localized
processing stages, and renders the supplied answer blocks, terms, citations,
referrals and suggested lessons. Send retries reuse the key; failed/timeout
answer retries create a new message. The developer menu selects A–H or failed.
The received A–H answer fixtures are Arabic-only in either interface language
(A-43); the client preserves their wording. Voice/document/image uploads and
persistent history belong to Phase 13.

```sh
flutter test --no-pub test/features/raqeeb/
sh tool/test_web.sh
flutter build web --debug --no-pub --dart-define-from-file=config/mock.json
flutter build web --debug --no-pub --dart-define-from-file=config/demo.json
flutter drive --no-pub --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/phase9_raqeeb_test.dart -d <simulator> --dart-define-from-file=config/mock.json
```

The native tour covers both interface languages and motion settings, all nine
outcomes, understood-input rows, rating and failed-answer retry. Captures go to
`build/tour/phase9/`. For the generated Swift package minimum-version issue,
use the Phase 8 preparation/Xcode/prebuilt-app procedure with the Phase 9 target.
For a focused visual recheck, pass `--dart-define=PHASE9_OUTCOMES=B,C` to both
the build preparation and drive commands; the default covers all nine outcomes.
Restore `lib/main.dart` after the tour. Keep one simulator booted and run the
native and Chrome Flutter commands sequentially.

## Phase 10 Profile verification

Profile reads the user, stats, achievements and three glossary preview rows through
BLoC. Settings applies server choices optimistically, switches language instantly
and restores it after a rejected PATCH. Local settings persist on device; reminders
store choices only (A-34). The English curiosity row needs its flag and complete
approved copy; it is absent in Arabic until copy exists. Your words and achievements
open their planned placeholder destinations. About uses the bundled verified Taha
verse, with a full-verse sheet and the review/AI notices.

```sh
flutter test --no-pub test/features/profile/
sh tool/test_web.sh
flutter build web --debug --no-pub --dart-define-from-file=config/mock.json
flutter build web --debug --no-pub --dart-define-from-file=config/demo.json
flutter drive --no-pub --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/phase10_profile_test.dart -d <simulator> --dart-define-from-file=config/mock.json
```

The iPhone tour covers English/Arabic × motion/reduced motion, name editing,
instant locale save/rollback, preferences, copy gating, About and its full verse.
Captures go to `build/tour/phase10/`. For the ephemeral Swift package issue, use
the Phase 8 preparation/Xcode/prebuilt-app procedure with the Phase 10 target;
then restore `lib/main.dart`. Keep one simulator booted and run Flutter commands
sequentially. Web tests resize mounted pages/sheets through the full viewport
matrix with text scale 1.35 and simulated keyboard insets.

## Phase 11 demo fidelity and rehearsal

The production [tour](integration_test/tour_test.dart) preserves the prototype's
Tier A screenshot names. It starts with fresh onboarding as an Explorer, follows
Unit 0 with scenes and a deliberate mistake/retry, checks completion/streak and
updated progress, opens 1.1 from Discover, sends Raqeeb questions, switches the
language through Settings, and plays the Salah reference through the developer
launcher. `TOUR=all` runs four language/motion flows and both languages' failure
checks. `TOUR=spine` or `failures` selects a group; `reference` isolates Profile,
Settings and the Salah reference; `onboarding` isolates the seven-page flow;
`controls` isolates the developer-menu failures; `requests` isolates request
recovery. Groups can be combined, such as
`TOUR=onboarding,controls`. `TOUR_CASE=en_motion`, `en_reduced`, `ar_motion` or
`ar_reduced` selects a capture pass. Use a comma-separated value to select
several passes after an interrupted run.
The native harness uses the documented fast-latency test toggle while retaining
the actual demo configuration, server payloads and production interactions.

```sh
flutter build ios --config-only --debug --no-codesign --no-pub --target=integration_test/tour_test.dart --dart-define-from-file=config/demo.json
python3 tool/prepare_ios_plugins.py
xcodebuild -project ios/Runner.xcodeproj -scheme Runner -configuration Debug -sdk iphonesimulator -destination id=<simulator-id> -derivedDataPath build/ios -clonedSourcePackagesDirPath ios/Flutter/ephemeral/Packages/SourcePackages CONFIGURATION_BUILD_DIR="$PWD/build/ios/iphonesimulator" build
flutter drive --no-pub --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/tour_test.dart -d <simulator-id> --dart-define-from-file=config/demo.json --use-application-binary=build/ios/iphonesimulator/Runner.app
python3 tool/compare_tour.py
flutter test --no-pub test/features/demo/demo_spine_test.dart
sh tool/test_web.sh
flutter build web --debug --no-pub --dart-define-from-file=config/demo.json
```

Pass tour selectors to **both** the config preparation and the drive command;
a prebuilt binary keeps the selectors compiled into it. Captures are under
`build/tour/phase11/`. The comparison tool requires every Tier A capture at the
same pixel viewport; it produces 46 full-size pairs, contact sheets, a manifest
of intentional differences and `build/compare/index.html`. Open full-size pairs
for review; thumbnail contacts only aid navigation. It does not infer visual
approval from a pixel metric. Other language/motion captures can be paired with
`--captures <folder> --output <folder>`; the checked-in baseline is English.
Native captures are also saved immediately under `tmp/qabas_tour/` in the app's
data container, so an interrupted host drive does not lose completed screens.
On a simulator, find that container with
`xcrun simctl get_app_container <simulator-id> com.rw.qabas data` and copy its
`tmp/qabas_tour/phase11/` directory into `build/tour/phase11/` before comparison,
or run `python3 tool/export_native_tour.py --device <simulator-id>`.
If Flutter regenerates its ephemeral Swift plugin wrapper with iOS 13 and Xcode
reports that `file_picker` requires iOS 14, rerun `prepare_ios_plugins.py` and
repeat the Xcode command.

The failure group exercises the actual developer menu's 503/429, unknown-visual fallback, Offline, Revoke
token and 426 controls, plus offline lesson loading/answer/finish, Raqeeb send
retry, cached Profile recovery and failed Settings language rollback. A 426
keeps the update gate blocking until the client is updated; it must not be
bypassed by retrying bootstrap. Restore `lib/main.dart` using the same native
preparation/build procedure after the tour. Keep only one simulator booted.

## Phase 12 learning verification

Card review starts from Journey's due deck; quick review uses its secondary
button. Profile's **Your words** opens the glossary. The lesson intro's book
button opens the reader without starting a session. In the hidden developer
menu (long-press the Profile avatar), select the all-types practice lesson,
open the supplied unit guide, or enable the contract test curriculum. That
curriculum uses its supplied opaque lesson and assessment IDs in both languages
and tracks. Demo units keep their supplied `has_guide: false` flags.

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
sh tool/check_rules.sh
sh tool/test_web.sh
flutter build web --debug --no-pub --dart-define-from-file=config/mock.json
flutter build web --debug --no-pub --dart-define-from-file=config/demo.json
```

The Phase 12 native tour plays all 16 practice blocks, cards, quick review,
glossary, guide, reader, pretest and unit test in English/Arabic with motion
and reduced motion. It uses the actual demo configuration and the documented
fast-latency toggle. The same simulator preparation described above applies:

```sh
flutter build ios --config-only --debug --no-codesign --no-pub --target=integration_test/phase12_learning_test.dart --dart-define-from-file=config/demo.json
python3 tool/prepare_ios_plugins.py
xcodebuild -project ios/Runner.xcodeproj -scheme Runner -configuration Debug -sdk iphonesimulator -destination id=<simulator-id> -derivedDataPath build/ios -clonedSourcePackagesDirPath ios/Flutter/ephemeral/Packages/SourcePackages CONFIGURATION_BUILD_DIR="$PWD/build/ios/iphonesimulator" build
flutter drive --no-pub --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/phase12_learning_test.dart -d <simulator-id> --dart-define-from-file=config/demo.json --use-application-binary=build/ios/iphonesimulator/Runner.app
python3 tool/export_native_tour.py --device <simulator-id> --phase phase12 --output build/tour/phase12
python3 tool/compare_learning.py
```

Optional `PHASE12_CASE=en_motion,en_reduced,ar_motion,ar_reduced` selects passes;
`PHASE12_GROUP=reference` skips the practice lesson while retaining every other
flow. Pass selectors to both preparation and drive because the binary pins them.
The comparison makes four uncropped, same-viewport pairs for screens 40–42 and
57, plus a contact and per-screen manifest. Review the full-size pairs; fixture
content, rewards and omitted interval/reviewer fields intentionally differ.

For an actual process-kill check, prepare and build
`integration_test/phase12_resume_test.dart` using the same commands, then run:

```sh
python3 tool/verify_resume.py --device <simulator-id>
python3 tool/export_native_tour.py --device <simulator-id> --phase phase12 --output build/tour/phase12
```

The host waits for the incorrect feedback checkpoint to reach disk, terminates
the process with `simctl`, then cold-launches the installed app and attaches
the driver without reinstalling. Recovery must preserve the
session, answer, original evaluation, predictions and retry identity, then finish
with exactly one recorded retry. A final native map view verifies geographic
pin centre taps. The seed driver's interruption is expected;
the restore log and host script determine success. Restore `lib/main.dart`
with the ordinary demo native preparation/build after testing. Run native preparation, build and drive commands sequentially so the
ephemeral iOS configuration stays pinned to the intended target. Keep only
one simulator booted.

## Phase 13 community and media verification

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded --concurrency=2
sh tool/check_rules.sh
sh tool/test_web.sh
flutter build web --debug --no-pub --dart-define-from-file=config/mock.json
flutter build web --debug --no-pub --dart-define-from-file=config/demo.json
```

For a focused browser rerun, use `sh tool/test_web.sh test/features/community/phase13_responsive_test.dart test/features/community/phase13_media_responsive_test.dart`; the helper also runs the scene-engine checks.

The Phase 13 native tour uses the actual demo configuration and the fast-latency
test toggle. Each English/Arabic, motion/reduced pass visits Community,
achievements, a four-player group (including a socket reconnect), a complete
seven-question bot duel, the streak calendar and Raqeeb photo upload/history.
The native upload uses a fixture capture adapter: physical pickers and acoustic
recording require a device check. Demo recitation remains unavailable/skip;
synthetic check outcomes are available only in development mock controls.

Keep the simulator foregrounded during the integration tour, then run the
preparation/build/drive commands sequentially:

```sh
flutter build ios --config-only --debug --no-codesign --no-pub --target=integration_test/phase13_community_test.dart --dart-define-from-file=config/demo.json
python3 tool/prepare_ios_plugins.py
xcodebuild -project ios/Runner.xcodeproj -scheme Runner -configuration Debug -sdk iphonesimulator -destination id=<simulator-id> -derivedDataPath build/ios -clonedSourcePackagesDirPath ios/Flutter/ephemeral/Packages/SourcePackages CONFIGURATION_BUILD_DIR="$PWD/build/ios/iphonesimulator" build
flutter drive --no-pub --keep-app-running --driver=test_driver/integration_test.dart --target=integration_test/phase13_community_test.dart -d <simulator-id> --dart-define-from-file=config/demo.json --use-application-binary=build/ios/iphonesimulator/Runner.app
python3 tool/export_native_tour.py --device <simulator-id> --phase phase13 --output build/tour/phase13
python3 tool/compare_community.py
python3 tool/compare_community.py --captures build/tour/phase13/community/ar_reduced --output build/phase13/comparison_ar
```

Optional `PHASE13_CASE=en_motion`, `en_reduced`, `ar_motion` or `ar_reduced`
selects one pass; pin it in both preparation and drive. Add
`--dart-define=PHASE13_COMMUNITY_ONLY=true` to both commands to refresh only
Community screens 47/48 in all four combinations. Use
`--dart-define=PHASE13_GROUP_ONLY=true` instead to capture Community,
achievements and a complete group match, ending at its results. The comparison produces
seven uncropped, same-viewport pairs for screens 47–52 and 54. Fixture member,
option and achievement counts intentionally differ from prototype sample data.
Restore the ordinary `lib/main.dart` demo binary after the tour. The declared
iOS minimum remains 14 for the installed `file_picker` dependency.

## Phase 14 reviewer console

Run with `config/mock.json` or `config/demo.json`, then open `/reviewer/login`
on web or choose Reviewer console in the developer menu. The local mock identity
is `reviewer@qabas.app` / `qabas-review`. Five failed attempts lock it for fifteen
minutes; the mock reviewer session expires after twelve hours. Signing out restores
guest bootstrap. These credentials are for the local mock handler only.

The two supplied Gate 2 runs retain their real QA blockers. Approve stays disabled;
use Request changes or Reject to exercise decisions. `run_42` starts at Gate 1.
The developer toggle “Next gate: stale review” changes the digest once, reloads the
run, and requires explicit re-review. Regeneration retains the placeholder.

```sh
flutter test test/features/reviewer/reviewer_flow_test.dart test/features/reviewer/reviewer_responsive_test.dart
sh tool/test_web.sh test/features/reviewer/reviewer_responsive_test.dart
flutter build ios --config-only --debug --no-codesign --no-pub --target=integration_test/phase14_reviewer_test.dart --dart-define-from-file=config/demo.json
python3 tool/prepare_ios_plugins.py
xcodebuild -project ios/Runner.xcodeproj -scheme Runner -configuration Debug -sdk iphonesimulator -destination id=<simulator-id> -derivedDataPath build/ios -clonedSourcePackagesDirPath ios/Flutter/ephemeral/Packages/SourcePackages CONFIGURATION_BUILD_DIR="$PWD/build/ios/iphonesimulator" build
flutter drive --no-pub --keep-app-running --dart-define-from-file=config/demo.json --driver=test_driver/integration_test.dart --target=integration_test/phase14_reviewer_test.dart -d <simulator-id> --use-application-binary=build/ios/iphonesimulator/Runner.app
```

Reviewer previews reuse the shared lesson renderers with local interactions and
read-only content inspection. They do not open learner sessions or submit grades.
Generated reviewer models/DTOs and request encoders can be refreshed with
`python3 tool/phase14/generate_models.py`, then `dart run build_runner build --delete-conflicting-outputs`,
`dart fix --apply` and `dart format lib/features/reviewer`.
