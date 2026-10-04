# Backend development environment

Native Windows development; no Docker (decision D-03 in [IMPLEMENTATION_PHASES.md](../IMPLEMENTATION_PHASES.md)).

## Toolchain

| Tool | Version | Location / install |
|---|---|---|
| Python | 3.12.10 | Per-user install; run with `py -3.12` (the default `python` on PATH is 3.13, so don't use it for this project) |
| uv | 0.12.23 | `winget install astral-sh.uv` |
| PostgreSQL | 16.14 | Windows service `postgresql-x64-16`, `C:\Program Files\PostgreSQL\16`, port 5432 |
| Redis | 7.4.11 | Native Windows build (`redis-windows/redis-windows`, msys2) in `%LOCALAPPDATA%\Programs\Redis`, config `redis.local.conf` (127.0.0.1:6379) |
| ffmpeg | 9.0.2 | `winget install Gyan.FFmpeg` |
| Node.js | 22.x | Pre-installed; used later for the native Dorar sidecar (Phase 9) |
| pgvector | — | Not yet installed; needed from Phase 17 (decision D-05) |

## First-time setup

```powershell
# 1. Start Redis (needed after every reboot; there's no auto-start)
backend\scripts\dev\start-redis.ps1

# 2. Create the qabas role and qabas_dev / qabas_test databases; writes backend\.env
#    (prompts for the postgres superuser password, which is not stored)
backend\scripts\dev\create-dev-db.ps1

# 3. Verify everything
backend\scripts\dev\check-env.ps1
```

`backend/.env` holds local credentials and is git-ignored.

```powershell
cd backend
uv sync                                                # Python 3.12 venv in backend\.venv (uv.lock)
py -3.12 scripts\dev\install_git_hooks.py              # pre-commit public-safety guard
```

## Everyday commands (from `backend/`)

| Task | Command |
|---|---|
| Run the API | `uv run uvicorn app.main:app --reload` (http://127.0.0.1:8000, docs at `/docs`) |
| Migrate the dev database | `uv run alembic upgrade head` (`uv run alembic downgrade -1` to step back) |
| New migration | `uv run alembic revision --autogenerate -m "..."`, then review it; triggers, grants and data steps are hand-written |
| Models = migrations? | `uv run alembic check` (also a test) |
| Tests | `uv run pytest` (`-m "not integration"` skips the Postgres/Redis tests; DB tests reset and migrate `qabas_test` only) |
| Lint / types | `uv run ruff check .` · `uv run mypy` |
| Regenerate `docs/openapi.json` | `uv run python scripts/export_openapi.py` |
| Full contract suites (also in CI) | `uv run python scripts/dev/run_contract_suites.py` (expects 595/279/105/382) |
| Repository safety check | `uv run python scripts/check_public_safety.py` |
| Refresh private-artifact fingerprints | `py -3.12 scripts/dev/update_private_fingerprints.py` (needs the local handoff) |
| Worker (Windows dev) | `uv run celery -A app.workers.celery_app worker -Q maintenance,factory,media --pool=solo` |
| Scheduler (outbox relay every 5 s, cleanups) | `uv run celery -A app.workers.celery_app beat` |
| Validate the curriculum file | `uv run python scripts/seed.py --check` (no database needed) |
| Seed the curriculum structure | `uv run python scripts/seed.py` (units, lesson slots, concept graph; safe to re-run, refuses destructive changes) |
| Load the contract test curriculum (dev/test DB only) | `uv run python scripts/seed.py --test-curriculum` (publishes the synthetic test lessons through the real pipeline; refused outside dev/test) |
| Create or re-key a reviewer | `uv run python scripts/create_reviewer.py --email reviewer@example.org --name "Reviewer"` (prompts for the password) |
| After restoring a backup | `uv run python scripts/repurge_deleted_users.py` (purges every deleted account again, before reopening traffic) |

## What belongs in the repository (D-19)

The repository is the complete production product and must be cloneable, installable, testable and runnable as-is. There is one product architecture: no demo mode, sample dataset or reduced path.

- **Public:** application code, migrations, the vendored contract with its fixtures and server-side grading context, approved production content and its answer keys (seed/import data), Arabic text, and the tests and fixtures that verify real production behavior.
- **Never sent to clients before submission:** correct answers and grading keys. They stay server-side and the API redacts them; that is enforced in the API, not by hiding files.
- **Private and git-ignored (`backend/.private/`):** hidden/golden evaluation datasets, reviewer reference answers and adversarial cases (`backend/.private/eval/`), unapproved pending religious content until approved, unpublished handoff material, and secrets/credentials.

`scripts/check_public_safety.py` (pre-commit hook and CI) blocks secrets and credential files, secret-looking tokens, the handoff and private paths, hidden-evaluation dataset names, and verbatim copies of fingerprinted private handoff artifacts (`backend/security/private_fingerprints.json`, digests only). It does not flag Arabic text or production content.

## Network note

This machine's TLS inspection uses a root CA that only the Windows certificate store trusts. uv uses it through `%APPDATA%\uv\uv.toml` (`system-certs = true`), and git through the repo-local `http.sslBackend=schannel`.

## Reference specification

`../FINAL_ENGINEERING_HANDOFF/` is the frozen handoff (contract revision 10). Its files are read-only; never edit them. Tools that write output (for example the contract `validate.py`) must run on a disposable copy, with `PYTHONUTF8=1`, and outputs are compared after LF normalization.
