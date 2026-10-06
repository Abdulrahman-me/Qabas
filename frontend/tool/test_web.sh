#!/usr/bin/env sh
# File.asset cannot use the Flutter CLI Chrome harness's rootBundle; serve the
# same .riv and development catalog/grading fixtures over HTTP. Material shaders use the
# SDK web compiler and a temporary link into the harness asset directory.
set -eu
python3 tool/prepare_chrome_shaders.py
python3 tool/serve_character_test_assets.py &
character_asset_server_pid=$!
trap 'kill "$character_asset_server_pid" 2>/dev/null || true; python3 tool/prepare_chrome_shaders.py --clean' EXIT INT TERM
if [ "$#" -eq 0 ]; then
  set -- test/app/shell_responsive_test.dart test/design_system/responsive_test.dart test/core/character_web_test.dart test/features/auth/auth_pages_test.dart test/features/onboarding/onboarding_responsive_test.dart test/features/journey/journey_responsive_test.dart test/features/session/session_responsive_test.dart test/features/session/exercise_responsive_test.dart test/features/session/phase12_responsive_test.dart test/features/session/completion_responsive_test.dart test/features/raqeeb/raqeeb_responsive_test.dart test/features/profile/profile_responsive_test.dart test/features/community/phase13_responsive_test.dart test/features/community/phase13_media_responsive_test.dart test/features/reviewer/reviewer_responsive_test.dart test/features/demo/demo_spine_test.dart test/shared/visual_view_test.dart test/scenes/scene_view_test.dart
fi
flutter test --no-pub --platform chrome "$@"
(cd packages/qabas_scene && flutter test --no-pub --platform chrome test/engine_test.dart)
