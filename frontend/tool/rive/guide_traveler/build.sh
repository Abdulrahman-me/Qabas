#!/bin/sh
# Regenerates the companion scene and copies the runtime file into the Flutter app.
set -e
cd "$(dirname "$0")"
python3 generate.py
rive . --verify
rive inspect . --summary | python3 -c "import json,sys; p=json.load(sys.stdin)['problems']; print('problems:', p or 'none'); sys.exit(1 if any(x['severity']=='error' for x in p) else 0)"
rive . --once
mkdir -p ../../../assets/characters/guide_traveler
cp build/companion.riv ../../../assets/characters/guide_traveler/guide_traveler.riv
echo "→ assets/characters/guide_traveler/guide_traveler.riv ($(wc -c < build/companion.riv) bytes)"
