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
.venv\Scripts\python scripts\dev\sync_private_contract.py   # local private mirror of handoff fixtures
```

## Everyday commands (from `backend/`)

| Task | Command |
|---|---|
| Run the API | `uv run uvicorn app.main:app --reload` (http://127.0.0.1:8000, docs at `/docs`) |
| Tests | `uv run pytest` (`-m "not integration"` skips the Postgres/Redis tests) |
| Lint / types | `uv run ruff check .` · `uv run mypy` |
| Regenerate `docs/openapi.json` | `uv run python scripts/export_openapi.py` |
| Full contract suites (local, needs the private mirror) | `uv run python scripts/dev/run_contract_suites.py` (expects 595/279/105/382) |
| Public-repo safety check | `uv run python scripts/check_public_safety.py` |
| Worker (Windows dev) | `uv run celery -A app.workers.celery_app worker -Q maintenance,factory,media --pool=solo` |

## Public repository rules (D-14)

The repository is public. Commit only code, schemas and **synthetic, neutral** test data built in the tests themselves. Handoff fixtures, answer keys, the private grading context, gold/reference lessons, Unit 0 drafts and any unapproved religious content stay in git-ignored `backend/.private/`. The pre-commit hook and CI run `scripts/check_public_safety.py`, which blocks private paths and names, Arabic-script text outside `.public-safety-allow`, and verbatim copies of private handoff files.

## Network note

This machine's TLS inspection uses a root CA that only the Windows certificate store trusts. uv uses it through `%APPDATA%\uv\uv.toml` (`system-certs = true`), and git through the repo-local `http.sslBackend=schannel`.

## Reference specification

`../FINAL_ENGINEERING_HANDOFF/` is the frozen handoff (contract revision 10). Its files are read-only; never edit them. Tools that write output (for example the contract `validate.py`) must run on a disposable copy, with `PYTHONUTF8=1`, and outputs are compared after LF normalization.
