# Qabas — Instructions for Claude

Qabas (قبس) is an Islamic education platform structured as a monorepo:
1. `backend/`: FastAPI services, PostgreSQL, Celery, Redis, Lesson Factory, Raqeeb AI assistant, duels/challenges.
2. `frontend/`: Production Flutter application for mobile (iOS/Android), Web, and desktop.

---

## 1. Monorepo Navigation

| Subsystem | Directory | Key Documentation | Primary Language / Tooling |
|---|---|---|---|
| **Backend** | `backend/` | `backend/README.md`, `IMPLEMENTATION_PHASES.md` | Python 3.12, `uv`, FastAPI, pytest |
| **Frontend** | `frontend/` | `frontend/AGENTS.md`, `frontend/docs/PHASES.md`, `frontend/docs/PROGRESS.md` | Dart 3.10+, Flutter 3.38+, BLoC |

---

## 2. Backend Commands & Rules

### Commands
Run from `backend/`:
```bash
uv sync                                    # Install dependencies
uv run pytest                              # Run all backend unit & integration tests
uv run pytest tests/test_smoke.py          # Quick smoke test
uv run python scripts/run_api.py           # Start the FastAPI application
```

### Non-Negotiables
- **Specification:** Contract revision 10 is the frozen specification. Never invent undocumented endpoints or alter schema contracts without owner authorization.
- **Progress tracking:** Consult and update `IMPLEMENTATION_PHASES.md` before and after phase work.
- **Security:** Secrets, pepper values, and tokens must never be logged or committed to the repository.

---

## 3. Frontend Commands & Rules

### Commands
Run from `frontend/`:
```bash
dart run tool/merge_arb.dart && flutter gen-l10n         # After editing any ARB fragment
flutter analyze && flutter test                           # Must be clean before completing any task
flutter run --dart-define-from-file=config/mock.json      # Dev mock mode
flutter run --dart-define-from-file=config/competition.json # Competition preview build
sh tool/check_rules.sh                                    # Verify hard-coded strings, raw colors, imports
```

### Running in Claude Cloud (Linux Container)
If running a task in Claude Code Cloud where Flutter is not pre-installed on `$PATH`:
- For static analysis and code edits, inspect Dart files in `frontend/lib/` and verify logic directly.
- To execute Flutter tests in the cloud environment, install Flutter via:
  ```bash
  git clone https://github.com/flutter/flutter.git -b stable /tmp/flutter
  export PATH="/tmp/flutter/bin:$PATH"
  cd frontend && flutter test
  ```

### Non-Negotiables
- **Layers:** `presentation -> domain <- data`. Domain is pure Dart (no Flutter, Dio, JSON, or Rive).
- **State Management:** BLoC pattern exclusively. One BLoC per screen or flow; events in past tense; immutable `Equatable` states.
- **No hard-coded strings:** All user-facing strings must use `context.l10n.<key>` in both English (`en`) and Arabic (`ar`) ARB fragments.
- **Design system:** Use tokens (`QColors`, `QSpace`, `QRadius`, `QMotion`, `QBreakpoints`) instead of raw visual constants.
- **Content policy:** Quran text only via `QText.quran` for `text_uthmani`; faceless depictions only; emerald/clay feedback (never red).
- **Responsive web:** Every screen must support responsive web layout (narrow mobile, tablet, and desktop viewports).
- **Progress tracking:** Consult `frontend/docs/PROGRESS.md` and `frontend/docs/PHASES.md`.

---

## 4. Working on Tasks
When given a task:
1. Identify if it affects `backend/`, `frontend/`, or both.
2. `cd` into the relevant subdirectory (`cd backend` or `cd frontend`) before running tooling.
3. Keep changes scoped, verify with tests, and do not introduce unapproved architectural changes.
