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

`backend/.env` holds local credentials and is git-ignored. Service code and dependencies arrive in Phase 1.

## Reference specification

`../FINAL_ENGINEERING_HANDOFF/` is the frozen handoff (contract revision 10). Its files are read-only; never edit them. Tools that write output (for example the contract `validate.py`) must run on a disposable copy, with `PYTHONUTF8=1`, and outputs are compared after LF normalization.
