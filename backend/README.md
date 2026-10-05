# Backend development environment

Native Windows development; no Docker (decision D-03 in [IMPLEMENTATION_PHASES.md](../IMPLEMENTATION_PHASES.md)).

## Toolchain

| Tool | Version | Location / install |
|---|---|---|
| Python | 3.12.10 | Per-user install; run with `py -3.12` (the default `python` on PATH is 3.13, so don't use it for this project) |
| uv | 0.12.23 | `winget install astral-sh.uv` |
| PostgreSQL | 16.14 | Windows service `postgresql-x64-16`, `C:\Program Files\PostgreSQL\16`, port 5432 |
| Redis | 7.4.11 | Native Windows build (`redis-windows/redis-windows`, msys2) in `%LOCALAPPDATA%\Programs\Redis`, config `redis.local.conf` (127.0.0.1:6379) |
| ffmpeg | 9.0.2 | `winget install Gyan.FFmpeg` (tooling only; the asr worker decodes with PyAV's bundled FFmpeg libraries) |
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
| Recitation worker (Windows dev) | `uv sync --group asr`, then `uv run celery -A app.workers.celery_app worker -Q asr --pool=solo --prefetch-multiplier=1` (see Recitation below) |
| Scheduler (outbox relay every 5 s, cleanups) | `uv run celery -A app.workers.celery_app beat` |
| Validate the curriculum file | `uv run python scripts/seed.py --check` (no database needed) |
| Seed the curriculum structure | `uv run python scripts/seed.py` (units, lesson slots, concept graph; safe to re-run, refuses destructive changes) |
| Load the contract test curriculum (dev/test/staging DB only) | `uv run python scripts/seed.py --test-curriculum` (publishes the synthetic test lessons through the real pipeline; refused in production, D-84) |
| Create or re-key a reviewer | `uv run python scripts/create_reviewer.py --email reviewer@example.org --name "Reviewer"` (prompts for the password) |
| Before `alembic upgrade` past 0003 on a database with old active sessions | `uv run python scripts/abandon_legacy_sessions.py` lists them; add `--confirm` to abandon them (migration 0004 refuses to run otherwise) |
| After restoring a backup | `uv run python scripts/repurge_deleted_users.py` (purges every deleted account again, before reopening traffic) |

## What belongs in the repository (D-19)

The repository is the complete production product and must be cloneable, installable, testable and runnable as-is. There is one product architecture: no demo mode, sample dataset or reduced path.

- **Public:** application code, migrations, the vendored contract with its fixtures and server-side grading context, approved production content and its answer keys (seed/import data), Arabic text, and the tests and fixtures that verify real production behavior.
- **Never sent to clients before submission:** correct answers and grading keys. They stay server-side and the API redacts them; that is enforced in the API, not by hiding files.
- **Private and git-ignored (`backend/.private/`):** hidden/golden evaluation datasets, reviewer reference answers and adversarial cases (`backend/.private/eval/`), unapproved pending religious content until approved, unpublished handoff material, and secrets/credentials.

`scripts/check_public_safety.py` (pre-commit hook and CI) blocks secrets and credential files, secret-looking tokens, the handoff and private paths, hidden-evaluation dataset names, and verbatim copies of fingerprinted private handoff artifacts (`backend/security/private_fingerprints.json`, digests only). It does not flag Arabic text or production content.

## Phase 7 learning completion

Session finish commits the result, completion facts, FSRS schedules, term exposure/promotions, activity,
XP and quest rewards together. Results replay unchanged, including changed or malformed retry bodies.
The fixed XP amounts also drive published lesson XP. Repeating learning remains available; canonical
lesson/pretest/unit-pass/recitation rewards and the perfect bonus are one-time grants. Review XP requires
scheduled due work and is capped once per learner local day across both modes (D-67 in the tracker).

Migration 0003 adds private immutable start snapshots and answer transition audit, cross-session reward
uniqueness, exact cumulative daily duration and bigint session duration. It preserves historical XP and
issued evaluations; the earliest historical recitation grant claims that exercise's future reward.
An active record created before these start snapshots existed cannot safely reconstruct its historical
mastery start. Its finish is rejected as an integrity error; use an explicitly reviewed snapshot migration
with authoritative historical data before deploying over such records. Do not approximate, reset,
auto-abandon or rewrite served public content. Already finished records continue to replay.

The durable `session.finished` outbox records are retained for the achievement/league/metrics consumers
added in later phases. No reported finish effect depends on a worker. `/me/stats` has `league: null` until
Phase 18 implements league assignment. The normative quest pool already includes `win_challenge`, whose
activity arrives with challenges in Phases 19–20.

## Real content: gold lessons (Phase 8)

Real lessons reach learners only through one path: **convert → import (unpublished) → specialist approval of the
exact content digest, which publishes** (factory §13.6–13.7). There is no demo path and no shortcut.

| Step | Command |
|---|---|
| Convert the Unit 0 authoring drafts | `uv run python scripts/import_gold.py convert unit0 --source <UNIT_0_CONTENT/lessons> --report unit0-report.json` |
| Convert the Salah reference export | `uv run python scripts/import_gold.py convert salah --source <reply8/reference_export> [--completion <completion.json>]` |
| Import gold files (unpublished) | `uv run python scripts/import_gold.py import <gold.json>...` |
| Show a stored version and its digest | `uv run python scripts/review_gold.py show --lesson les_u3_l2` |
| Approve and publish (Gate 2-equivalent) | `uv run python scripts/review_gold.py approve --lesson … --version … --digest … --reviewer <email>` (prompts the reviewer's own password) |
| Reject | `uv run python scripts/review_gold.py reject --lesson … --version … --digest … --reviewer <email> --reason "…"` |

`convert` writes a gold file only for a lesson with no blockers; the report lists every blocker and who resolves it
(the reasoning-tool mapping in `content/mappings/reasoning_tools.yaml`, concept registration in
`content/curriculum.yaml`, verified sources, published scene media, the Salah completion record). Pending,
unapproved gold files go to the git-ignored `backend/.private/content/gold/` (the default `--out`); approved
lessons are committed under `content/gold/` and imported the same way. Today every Unit 0 lesson and the
Salah reference are correctly blocked (see `IMPLEMENTATION_PHASES.md`, Phase 8).

## Verified sources (Phase 9)

The source layer keeps religious authority separate from technical capabilities. The canonical Arabic Quran
comes from the digest-pinned King Fahd Hafs v3.0 dataset; Quran Foundation supplies discovery/audio/timings,
and specialist-selected QuranEnc records supply translations. See [SOURCE_POLICY.md](docs/SOURCE_POLICY.md)
for the full topic matrix, supported operations, provenance and pending provider approvals.

Install the local mushaf with `uv run python scripts/fetch_mushaf.py`; where the system CA is required,
download the pinned archive using the system-trusted client and pass `--archive <file>`. The script verifies
both digests. The dataset stays git-ignored; it is never silently repaired or bundled into production content.
Tests use neutral synthetic text, and optional local canonical-data checks run only when the dataset is installed.

The Unit 0 conversion command resolves Arabic Quran placeholders from that local dataset. Once the specialist
approves an English QuranEnc key **and version** in `content/sources/translations.yaml`, it retrieves those records
through the adapter and prepares one shared verified bundle for both languages. An outage, Arabic mismatch,
changed version or pending selection remains an explicit blocker. Gold files retain typed `source_records`
snapshots; imports verify scripture/ranges and persist sources with the unpublished lesson atomically.

Provider HTTP calls use 5 s connect / 15 s read, two jittered retries and a five-failure/60-second breaker.
All provider live/cache approvals are pending under O-03: production refuses live calls and no lookup cache
is used. Native Dorar uses the pinned checkout, a cache-disable preload, its original rate limit and a minimal
child environment. `uv run python scripts/dorar_sidecar.py install` refuses an existing destination;
`uv run python scripts/dorar_sidecar.py run` starts the checked local process. Actual native process network
isolation must be provisioned before deployment approval. Node 22 is required locally and explicitly set in CI.

Quran Foundation OAuth and its current Search API are mock-tested; public v4 content formats, QuranEnc,
HadeethEnc, IslamHouse and Dorar use recorded responses. Tafsir stdio runs against a fake MCP server in CI;
its actual package/tool/response mapping remains pending. `TAFSIR_MCP_COMMAND` is a JSON argv array,
not a shell command. Nothing in the tests requires live provider credentials.

HadeethEnc/IslamHouse REST text search is explicitly unsupported pending the association MCP schemas.
Hadith collection-number bindings, source-based teaching claims, licensed reciter audio, curriculum approvals
and scene media are still human/provider dependencies. This phase publishes no unfinished religious content.

## Recitation checks (Phase 10)

`POST /v1/recitation/checks` checks one recitation of a verse or word segment (API §6.6). The API process validates
the upload (size, signature, the reference against the canonical mushaf), admits it to the bounded `asr` pool and
waits at most `ASR_TIMEOUT_SECONDS`; decoding and speech recognition run only in the `asr` worker. Audio is never
written to disk, stored or logged, and the transcript lives a few seconds in Redis. Only the check result is kept.

| Step | Command |
|---|---|
| Install the worker dependencies | `uv sync --group asr` (faster-whisper, CTranslate2, PyAV; the API does not need them) |
| Convert and pin the model (once per environment) | in a separate tooling venv with `ctranslate2==4.8.2`, `transformers<5`, `torch` (CPU) and `truststore`: `python scripts/convert_recitation_model.py [--system-ca]` → `var/models/whisper-base-ar-quran-ct2/` with `qabas-model.json` (file digests; the worker refuses altered files) |
| Install the canonical mushaf | `uv run python scripts/fetch_mushaf.py` (expected words always come from it) |
| Run the worker | `uv run celery -A app.workers.celery_app worker -Q asr --pool=solo --prefetch-multiplier=1` (Linux: `--concurrency=<physical cores>`) |
| Local clip set (real model) | `uv run python scripts/recitation_clip_set.py [--system-ca]` then `uv run pytest tests/recitation/test_clip_set.py -s` (reciter clips stay in git-ignored `var/`, O-06) |

CI has neither the model nor the clips: it covers the same pipeline with generated audio and an in-process engine.

## Model calls (Phase 11)

`app/llm/` is the one way Qabas calls a language model (agent catalog §17, AD-27): a registered prompt
(`app/llm/prompts/<id>.md`, versioned and pinned in `LOCK.json`), its strict JSON schema (`app/llm/json_schemas/`),
framed untrusted data, structured output validated against the schema and the contract, one corrective retry, and a
usage record per attempt (model, prompt version and digest, effort, tokens) charged to a token budget.

| Task | Command |
|---|---|
| After editing a prompt (raise its `version` first) | `uv run python scripts/lock_prompts.py` |
| Bilingual model validation (O-03; live calls, needs `ANTHROPIC_API_KEY`) | `uv run python scripts/evaluate_models.py --systems opus=claude-opus-5-5,haiku=claude-haiku-4-5` (cases default to the private `.private/eval/llm/cases.jsonl`; report in `var/llm-eval/`) |
| Compare declared model capabilities with the Models API | `uv run python scripts/evaluate_models.py --capabilities claude-opus-5-5 claude-haiku-4-5` |

Tests and CI never call a model: they use `app/llm/fake.py` (an SDK-shaped fake and a deterministic client).

## Lesson Factory (Phase 12)

`app/factory/` drafts one lesson for one curriculum slot: `plan` → Gate 1 → `decompose` → `retrieve` →
`verify_evidence` → `write` → `exercises` → `glossary` → `localize` → `visuals` → `scene_author` → `scene_render` →
`narration` → `qa` → Gate 2 (factory §13.1). Each stage is an idempotent task on the `factory`/`media` queues keyed
by (run, stage, attempt); models only *draft* (through `app/llm`),
code executes source requests through the Phase 9 layer, inserts verified Qur'an/hadith text, composes the contract
blocks and runs every content validator. Every accepted artifact records its inputs/output digests, the prompt
versions and models that produced it, and each paid call's tokens (`factory_runs.artifacts`, `.cost`).

| Task | Command |
|---|---|
| After changing a factory output model | `uv run python scripts/export_llm_schemas.py` (CI runs `--check` through the tests) |
| Run the factory/media worker (Windows dev) | `uv run celery -A app.workers.celery_app worker -Q factory,media --pool=solo` |

A run stops with an explicit blocker instead of working around a human decision: `concepts_unregistered` (O-12),
`sources_not_configured` (O-03), `no_supported_claims`, `translation_unselected` (D-93), or missing approved media
inputs. [Media policy](docs/MEDIA_POLICY.md) explains the Phase 14 pipeline, private review assets, immutable
promotion, exact-content review, fake-only CI and outstanding real-art/renderer/licensing dependencies. Runs
never write lessons, exercises, terms or sources before Gate 2 approval.

## Reviewer console and publication (Phase 13)

Reviewers sign in with `POST /v1/auth/reviewer` and use `/v1/admin/factory/runs` (create, list, read) and
`…/{run_id}/gate1|gate2` (API §6.11). A decision must echo the run's current `review_digest` (the contract's
`review.py` digest of the stored plan, or of the draft plus QA report); a changed draft is `409 review_stale`, a run
not at the gate `409 run_not_at_gate`. Gate 2 `approve` applies the paired Arabic/English sentence edits and exercise
removals, re-runs every publication gate and publishes in the same transaction, or returns `400 validation_error`
with the blocking issues and changes nothing. `request_changes` sends the run back to `write` with the reason;
`reject` is final. Gold lessons publish through the same approval rule with `scripts/review_gold.py`.

## Metrics and blind tests (Phase 15)

`GET /v1/admin/metrics` reports learning pre/post, misconception and completion figures (from per-learner facts the
`session.finished` outbox subscriber keeps current; synthetic, bot and deleted users excluded) and factory figures
(published runs, generation and review minutes, blind-test results). `GET /v1/admin/blind-test/next` and
`POST /v1/admin/blind-test/{pair_id}` run the blind comparison of a gold and a generated lesson.

| Task | Command |
|---|---|
| Pair a published gold lesson with a published generated one | `uv run python scripts/create_blind_pair.py --gold <lesson_id> --generated <lesson_id>` |
| Backfill learning-metric facts | `uv run python scripts/create_blind_pair.py --refresh-metrics` |

## Raqeeb text assistant (Phase 16)

`/v1/raqeeb` now supports learner-owned conversations, text admission (`202`), polling and feedback. The eight
class strategies use the existing model/source layers, with protective referrals, source-bound verification,
level adaptation and guarded answers. A 75-second admission deadline, durable outbox and 90-second crash
sweeper keep requests terminal and replay-safe. It cannot publish lessons, issue personal rulings or change XP.

See [Raqeeb policy](docs/RAQEEB_POLICY.md) for exact source roles, worker commands, private-data/model gates,
offline recommendation setup, and benchmark persistence. Phase 17 owns attachments, guarded memory and the
private benchmark runner; no synthetic benchmark appears as release quality in staff metrics.

## Staging environment

Staging is a non-production environment for frontend integration (`APP_ENV=staging`): the same code, migrations and
native services as production, plus the contract's synthetic test curriculum (`scripts/seed.py
--test-curriculum`, allowed in dev, test and staging and refused in production, D-84). Approved real content is
imported and published there through the same gold path. Staging needs real secrets (`AUTH_TOKEN_PEPPER`,
`STORAGE_SIGNING_KEY`) like production; it does not use the dev-only fallbacks. Provisioning the staging host is
an operations dependency.

## Network note

This machine's TLS inspection uses a root CA that only the Windows certificate store trusts. uv uses it through `%APPDATA%\uv\uv.toml` (`system-certs = true`), and git through the repo-local `http.sslBackend=schannel`.

## Reference specification

`../FINAL_ENGINEERING_HANDOFF/` is the frozen handoff (contract revision 10). Its files are read-only; never edit them. Tools that write output (for example the contract `validate.py`) must run on a disposable copy, with `PYTHONUTF8=1`, and outputs are compared after LF normalization.
