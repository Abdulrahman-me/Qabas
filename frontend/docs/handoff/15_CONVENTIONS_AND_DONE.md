# 15 — Conventions, checks and definition of done

## 1. Toolchain and dependencies

Flutter 3.44 / Dart 3.12 (the versions the prototype runs on). Add packages with `flutter pub add` so versions resolve against this SDK. Where the prototype already pins a version, start from it.

| Purpose | Package |
|---|---|
| State | `flutter_bloc`, `bloc`, `bloc_concurrency`, `equatable` |
| DI | `get_it` |
| HTTP | `dio` |
| Routing | `go_router` (prototype: ^18.0.2) |
| Models | `json_annotation`; dev: `json_serializable`, `build_runner` |
| Localization | `flutter_localizations` (sdk), `intl` |
| Characters | `rive` (prototype: ^0.14.11) |
| Storage | `flutter_secure_storage` (token), `shared_preferences` (prototype: ^2.5.5; local preferences and resume only) |
| Audio | `audioplayers` (prototype: ^6.8.1, sound effects), `just_audio` (content audio with clips/seek), `record` (voice and recitation) |
| Media and files | `cached_network_image`, `flutter_svg`, `image_picker`, `file_picker` |
| Realtime | `web_socket_channel` |
| Platform | `url_launcher` (prototype: ^6.3.2), `share_plus`, `package_info_plus`, `flutter_timezone`, `uuid` |
| Scene renderer (`packages/qabas_scene`, Phase 7) | `crypto` (SHA-256 of manifests), `path_parsing` (SVG path data → `Path`), Flutter `CustomPainter`; nothing else |
| Logging | `logging` |
| Tests | `flutter_test`, `bloc_test`, `mocktail`, `integration_test`, `flutter_driver` |

Don't add packages beyond this list without a reason in the PR. No LLM, analytics or crash-reporting SDKs in this build.

## 2. Code style

- `analysis_options.yaml`: `include: package:flutter_lints/flutter.yaml`, plus `prefer_const_constructors`, `prefer_final_locals`, `prefer_single_quotes`, `avoid_print`, `unawaited_futures`, `cancel_subscriptions`, `close_sinks`, `avoid_dynamic_calls`, `directives_ordering`, `always_declare_return_types`. Exclude `**/*.g.dart` and `lib/l10n/gen/**`.
- Formatting: `dart format` with page width 140 (the prototype's width), set in `analysis_options.yaml` (`formatter: page_width: 140`).
- Imports: `package:qabas/...` everywhere (no `../` climbing across folders).
- Files are `snake_case.dart`, one public class per file except small sealed families (events, states, unions).
- Names: `XBloc` / `XEvent` / `XState`; events are past tense (`NodeTapped`); use cases are verb phrases (`GetJourney`, `SubmitAnswer`); `XRepository` (domain interface) and `XRepositoryImpl` (data); `XRemoteDataSource`, `XLocalDataSource`; `XDto`; mappers as extensions (`extension JourneyDtoMapper on JourneyDto { Journey toEntity() }`).
- Comments explain *why* (a contract rule, a prototype measurement), not what. Reference the contract section (`// API §6.5.1: recite completes on Continue`) where behaviour comes from the contract.
- No `print`. Use `Logger('feature')`. Never log tokens, `ws_url`, learner text, transcripts, answers or attachment URLs.
- Async hygiene: `await` or explicitly `unawaited(...)`; cancel subscriptions in `close`/`dispose`; check `mounted` after `await` in widgets; no `BuildContext` across async gaps.
- Swallow errors only where the design says so (sound effects, character loading, fire-and-forget `opened`), always with a debug log.
- Markers: `// TODO(contract): A-xx` for assumptions (must exist in `docs/API_ASSUMPTIONS.md`); `// TODO(tier-c): …` for deferred work. No anonymous TODOs.

## 3. Rule checks (`tool/check_rules.sh`)

Write this script in Phase 1 (it has been tested with macOS `/bin/sh` and BSD grep on a sample tree) and run it before every hand-off. It's deliberately simple (grep), so write code it can read: string literals never go straight into `Text(...)`, colours never appear as hex outside the design system.

```sh
#!/usr/bin/env sh
# Fails when production code breaks the project's hard rules. Run from the repo root.
set -u
fail=0
# Prototype painters keep their authored literals; developer tools may use English literals.
EXCLUDE='\.g\.dart|/l10n/gen/|/dev_tools/|/painters/|/visuals/builtin/|rules:allow'
WS='[[:space:]]*'

check() { # $1 = description, $2 = extended regex, $3.. = paths
  desc=$1; pat=$2; shift 2
  hits=$(grep -rEn --include='*.dart' "$pat" "$@" 2>/dev/null | grep -Ev "$EXCLUDE")
  if [ -n "$hits" ]; then echo "✗ $desc"; echo "$hits" | head -20; fail=1; fi
}
UI="lib/features lib/shared lib/app"

check 'Hard-coded UI string (use context.l10n)' "(Text|SelectableText)\(${WS}['\"]|(tooltip|semanticsLabel|semanticLabel|label|hintText|message|title):${WS}['\"][^'\"]" $UI lib/core/design_system
check 'Raw colour outside the design system'    "Color\(0x|Colors\.(red|blue|green|amber|orange|grey|black)" $UI
check 'Raw duration outside the design system'  "Duration\((milliseconds|seconds):" $UI
check 'Raw radius outside the design system'    "BorderRadius\.circular\([0-9]" $UI
check 'Font family set in feature code'         "fontFamily:" $UI
check 'Flutter/Dio/JSON/Rive imported in domain' "import 'package:(flutter|dio|json_annotation|rive)/" lib/features/*/domain lib/shared/domain
check 'Dio used outside core/network'           "import 'package:dio/" $UI
check 'Data layer imported by presentation'     "import 'package:qabas/features/[a-z_]+/data/" lib/features/*/presentation
check 'Service locator used in a widget'        "sl<|GetIt\.instance" lib/features/*/presentation/widgets lib/shared/presentation lib/core/design_system
check 'print() in production code'              "^${WS}print\(" lib

# TODOs must be tagged TODO(contract): A-xx or TODO(tier-c)
hits=$(grep -rn --include='*.dart' 'TODO' lib 2>/dev/null | grep -Ev 'TODO\((contract|tier-c)\)' | grep -Ev "$EXCLUDE")
[ -n "$hits" ] && { echo '✗ Untagged TODO'; echo "$hits" | head -10; fail=1; }

# Cross-feature imports: features/<a>/ must not import features/<b>/
for f in lib/features/*/; do
  [ -d "$f" ] || continue
  name=$(basename "$f")
  hits=$(grep -rEn --include='*.dart' "import 'package:qabas/features/" "$f" | grep -v "import 'package:qabas/features/$name/" | grep -Ev "$EXCLUDE")
  [ -n "$hits" ] && { echo "✗ Cross-feature import in $name"; echo "$hits" | head -10; fail=1; }
done

[ $fail -eq 0 ] && echo '✓ rules ok'
exit $fail
```

Painters ported from the prototype keep their authored literals: put them under `presentation/painters/` or `shared/presentation/visuals/builtin/`, which the script excludes. Use `// rules:allow <reason>` on a line only in exceptional cases, and say why.

## 4. Testing expectations

| Layer | What to test | Tooling |
|---|---|---|
| Domain | Use cases, `progress.dart`, `retry_queue.dart`, `teach_params.dart`, answer drafts, cue mapping | `test` + fakes |
| Data | Every mapper against real fixtures; repository error mapping (`ApiException` → `Failure`) | fixtures from `assets/mocks/` |
| Contract | `test/contract/*` ([07](07_MOCKS_AND_BACKEND_SYNC.md) §6) | MANIFEST + extracted examples |
| Presentation | Every BLoC event path including failures and retry; key views in en/ar; state views | `bloc_test`, `mocktail`, widget tests |
| End-to-end | Ported prototype tour (mock mode): onboarding, the full Salah lesson with one deliberate miss, celebrations, every tab, Arabic | `integration_test` + `flutter drive` |
| Characters | Contract test loading each `.riv` on a simulator | `integration_test/character_contract_test.dart` |

Keep tests fast: the mock backend's `fast` latency in tests; no real network in `flutter test`.

## 5. Definition of done

**A feature (screen or flow) is done when all of these hold:**

1. It matches the prototype screen(s) at the same viewport: layout, spacing, typography, colours, wording, icons, transitions, micro-interactions, sounds/haptics and character placement. Intentional differences are listed in the PR.
2. It works in **mock** mode end to end, and in **live/hybrid** mode once its group is available (or a dated note says the backend isn't ready).
3. English (LTR) and Arabic (RTL) both work, with Arabic-Indic digits, correct plurals and unmirrored illustrations.
4. Reduced motion (OS and in-app) is respected; text scale 1.35 doesn't break the layout; semantics labels are present and taps are ≥ 44 px.
5. Loading, empty, error and retry states exist and follow [12](12_STATES_AND_ERRORS.md).
6. All logic lives in BLoCs and use cases; widgets are declarative; no layer or feature boundary is broken (`tool/check_rules.sh` passes).
7. No hard-coded strings; new ARB keys exist in both locales with descriptions; `tool/merge_arb.dart` passes.
8. DTOs decode the relevant fixtures; mappers have tests; BLoCs have `bloc_test` coverage for success, failure and retry.
9. Every assumption is logged in `docs/API_ASSUMPTIONS.md` and marked in code with `TODO(contract)`.
10. `flutter analyze` is clean and `flutter test` passes.
11. Responsive web works at the viewport matrix in [03 §4](03_DESIGN_SYSTEM.md), in both languages with text scale 1.35 and reduced motion on/off. Content stays centred and constrained, controls remain reachable in short windows, and resize retains input/state. `flutter build web` and relevant `flutter test --platform chrome` tests pass. Record browser/device coverage and any limitations in the phase report.

**The app is demo-ready when:** the Tier A spine ([01](01_PRODUCT_AND_SCOPE.md)) plays without a crash in hybrid mode on the demo device, in both languages; the Salah lesson passes the acceptance list in [11](11_SESSION_PLAYER.md) §6; the tour screenshots have been compared side by side with the prototype's; the developer-menu failure toggles (`426`, `401`, `503`, offline) recover gracefully; and the demo script ([14](14_DELIVERY_PLAN.md)) has been rehearsed twice.

## 6. Reporting work

When an agent finishes a task it reports, plainly:

- What changed (files and features) and which tier items it covers.
- **Verified:** what was actually run (commands, device or simulator, mock or live, languages) and observed.
- **Not verified:** what couldn't be checked, and why.
- Prototype comparison: the screenshots compared, and any intentional differences.
- New assumptions (IDs) and any open questions for the owner or the backend engineer.

Don't describe something as working without having run it. If a test fails, say so and include the output.

## 7. Git workflow

- One branch per work package (`wp3-session-player`); small commits with clear messages (`journey: popover and node states`).
- Generated files (`*.g.dart`, `lib/l10n/gen/`, merged ARB in `lib/l10n/arb/`) are committed, so the app builds without running generators.
- Shared files (`core/`, `app/router/routes.dart`, `app/di/injector.dart`, `common_*.arb`) change in their own small commits, announced to the other agents.
- Never commit secrets, tokens, `.env` files or production URLs with credentials.
