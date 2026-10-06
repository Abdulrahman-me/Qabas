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
