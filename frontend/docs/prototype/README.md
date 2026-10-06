# Prototype reference

The prototype is the **visual and UX specification** of this app: layout, spacing, typography, colours, wording, motion, sounds and character placement. It is a separate Flutter project and stays **read-only**:

- **Source:** `/Users/aw/Documents/qpr/qabas/` (also named `qabas`, so don't confuse it with this app). It is deliberately not copied here, because its code would be compiled and imported by mistake. Open its files from that path, and run it there with `cd /Users/aw/Documents/qpr/qabas && flutter run`.
- **Screenshots:** `screens/` in this folder. 57 PNGs from its screenshot tour on the iPhone 17 Pro simulator (1206 × 2622 px, English).

| Screens | Prototype source (`/Users/aw/Documents/qpr/qabas/lib/…`) | Phase ([../PHASES.md](../PHASES.md)) |
|---|---|---|
| `01`–`08` onboarding: language, welcome, who (+ selected), familiarity, goal, privacy, ready | `features/onboarding/onboarding_flow.dart` | 3 |
| `09` journey, `10` node popover, `38` journey after a lesson, `57` unit guide | `features/journey/journey_screen.dart`, `journey_widgets.dart` | 4 (guide: 12) |
| `11` lesson intro | `features/lesson/lesson_intro_screen.dart` | 5 |
| `12` hook · `13`–`14` predict · `15`–`17` story · `19` teach (river) · `21` teach (pillars) · `26` teach (day arc) · `33` summary | `features/lesson/steps/*`, `lesson_screen.dart`, `feedback_panel.dart` | 5 |
| `18` find in the scene · `20` myth correction (retry feedback) · `22`–`25` sorting · `27`–`28` day placement · `29` scenario · `30`–`32` recitation · `34`–`35` ordering | `features/lesson/exercises/*`, `steps/recite_view.dart` | 6 |
| `36` lesson complete · `37` streak celebration | `features/lesson/lesson_complete_screen.dart`, `features/streak/streak_screen.dart` | 8 |
| `43`–`46` Raqeeb: welcome, answer, verification, specialist | `features/raqeeb/raqeeb_screen.dart` | 9 (attachments, history: 13) |
| `53` profile · `54` achievements · `55` settings · `56` about | `features/profile/*`, `features/settings/*` | 10 (achievements screen: 13) |
| `39`–`42` review hub and card review (the review hub's deck becomes the Journey's Review card; its words list becomes "Your words" in Profile) | `features/review/*` | 4 (Review card), 10 ("Your words" row), 12 (card review, glossary) |
| `47`–`48` community · `49`–`52` live challenge | `features/community/*` | 13 |

## Regenerating, and Arabic screenshots

These screenshots are English only. The prototype's tour can also capture the Arabic journey and lesson (`ar_*` files):

```sh
cd /Users/aw/Documents/qpr/qabas
rm -rf build/tour
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/tour_test.dart \
  -d <simulator-id> --dart-define=TOUR=arabic          # or all | onboarding | lesson | tabs | misc
cp build/tour/*.png /Users/aw/StudioProjects/qabas/docs/prototype/screens/
```

Building it needs about 1–2 GB of free disk. Check `df -h /System/Volumes/Data` first, and boot only one simulator. Until Arabic screenshots exist, compare Arabic screens against the running prototype switched to Arabic (Settings → Language).
