# Raqeeb inputs, guarded memory and evaluation

Phase 17 extends Phase 16's existing conversations, worker leases, 75-second admission deadline and immutable
completed messages. It neither publishes lessons nor changes XP, mastery or curriculum progression. The
revision 10 API response shapes and exact idempotent response replay are unchanged.

## Private inputs

Multipart messages accept optional text (2,000 characters), one audio file (10 MiB/60 decoded seconds), up to
three JPEG/PNG/WebP images (8 MiB/40 decoded megapixels each), and one PDF/DOCX (10 MiB). At least one input is
required. Unknown fields, unsupported MIME types, excess counts/sizes and unsafe filenames are rejected before
writing objects. Actual bytes, dimensions, codec, encryption and duration are checked in isolated workers,
not the API event loop. A declared type never repairs or relabels invalid bytes.

Native decoding uses a subprocess with a 10-second per-file deadline and 768 MiB limit (POSIX address-space
limit; Windows job-object memory/process-tree limits). FFmpeg accepts only in-memory pipe/data protocols,
decodes WAV, AAC/M4A, Opus/WebM or MP3 into mono 16-kHz WAV, and rejects audio exceeding 60 seconds. Ordinary
speech then uses the configured Whisper large-v3 compatible STT provider. This is separate from Phase 10's
local Tarteel recitation model and its never-persisted recitation audio.
Non-faststart M4A is demuxed from seekable memory and its verified AAC packets remuxed in memory to pipe-safe
ADTS before FFmpeg conversion. No temporary audio files or file/network protocol permissions are needed.

Images use the Phase 11 fast vision prompt. A bounded JPEG model rendition fits Phase 11's image envelope;
the original private object and its identity remain unchanged. DOCX uses python-docx paragraphs with a
30,000-character bound. It does not invent Word pagination: `pages` is null and `pages_processed` is zero.
PDFs use pdfplumber's first 20 pages; fewer than 200 extracted characters triggers pypdfium2 rendering/OCR of
the first five pages. Encrypted documents and macro DOCX are rejected. The document summary uses the registered
three-sentence prompt. The question is typed text plus transcript; image/document material remains a distinct
untrusted field. Full extracted material is a private checkpoint; the public document contract exposes its
summary, page processing and truncation only. Combined material exceeding the bounded context is rejected.

Every upload has a committed receipt before an immutable private object write. Receipt, byte hash, owner and
message binding are checked again by the worker. User → receipt locks fence writes against account purge.
Admission failure leaves an auditable pending receipt, collected after one hour; replay can safely claim it.
Attachment URLs are private signed URLs lasting at most 15 minutes. Conversation reads refresh them; exact
202 replay deliberately keeps its original response. Completion starts retention, and cleanup removes bytes
while preserving understood-input/history metadata with a null URL. Account purge removes private objects,
receipts, conversations and origin-owned memory, including after backup restoration.

Staging/production uploads require an actually approved `content/raqeeb_input_policy.yaml`: retention, private
storage, disclosure, owner/date/report. STT additionally requires exact approved provider/HTTPS origin/model,
retention and deletion responsibilities. Pending O-03/O-09/P-04 gates send no hosted audio. The 30-day local
test default is a proposal, not production approval. Configure FFmpeg using forward slashes on Windows.

## Guarded memory

Install native pgvector 0.8.3 before migration. A database administrator provisions it outside `public`:

```sql
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;
```

The migration never elevates an application role or silently relocates an existing extension. Runtime roles
receive schema usage; the read-only role cannot mutate the new tables. CI builds the pinned upstream revision;
local validation uses an isolated PostgreSQL cluster and native vector operators/indexes.

Only standalone, attachment-free general-knowledge/text-explanation questions are eligible. Context-pinned
lesson questions and mismatched input/answer languages conservatively use the full pipeline. bge-m3 runs on
CPU in the separate `embeddings` queue using the approved offline model inventory; broker arguments contain
opaque message/memory IDs, never questions/files. Cosine ≥ 0.92 nominates at most three candidates, not answers.
Every cited identity is freshly resolved through Phase 9, including canonical Quran and approved translations;
text, attribution, grade, authority/adapter versions and citation metadata must still match. An outage prevents
reuse; a definite missing/changed source expires it. A fast equivalence check sees the actual question/history
and canonical restatement. Renewed support verification, level adaptation and both model/code guards precede
reuse. Uncertainty or a failed check runs the normal pipeline.

Memory contains only the depersonalised canonical question, checked pre-adaptation core, source digests and
evidence. An additional privacy check refuses personal details. It stores `origin_user_id` for purge, not model
input. Source/policy/prompt/model/inventory changes and TTL expire derived rows. TTL is bounded by both the
configured conservative 30-day ceiling and every contributing authority's confirmed cache terms. Pending
terms cache nothing (D-91), including the mushaf until its own terms are represented and approved. Synthetic
cache permissions exist only in explicitly constructed dev/test gateways. Hits and insertion/outbox effects
commit inside the existing fenced completion transaction; duplicate tasks cannot count twice. Embedding
delivery is idempotent and cannot resurrect expired/deleted rows. Missing optional embedding/cache capability
does not weaken the normal answer pipeline.

Workers:

```powershell
uv run celery -A app.workers.celery_app worker -Q raqeeb --pool=solo --prefetch-multiplier=1
uv run celery -A app.workers.celery_app worker -Q embeddings --pool=solo --prefetch-multiplier=1
```

Use the existing maintenance worker/beat for private cleanup and outbox delivery. CPU/model sizing remains
measured O-03 work; there are no runtime model downloads or lexical approximations to vector similarity.

## Private benchmark workflow

The public engine is `bench/run.py`; real sets and reports belong in git-ignored
`backend/.private/eval/raqeeb/`. No private gold, references, adversarial material or reviewer labels are
committed. Public tests generate small neutral synthetic cases and never claim release-quality acceptance.

The private root contains `questions.jsonl` (60–80 bilingual cases/all eight classes), `adversarial.jsonl`
(at least 20), `warm.jsonl` (disjoint IDs and input digests), attachments, and `manifest.json` with schema
`qabas.raqeeb_dataset/1`, status `approved`, specialist/date/licence/report, provider-processing approval and
the exact three dataset digests. Each JSONL case has the handoff's id/language/question/attachments/class,
abstention/referral expectations, gold points and refs. Explicit extensions describe `history` (up to three
prior questions), `expected_error`, `must_not_reuse`, and coverage `tags`. Tags must cover conflicting/missing
sources, weak/fabricated hadith, inexact Quran, every input mode, embedded instructions, near duplicates,
dependent follow-ups and corrupt/encrypted/oversized files. Near-duplicate/follow-up adversarial cases must
explicitly forbid reuse. The unverified IslamicFaithQA supplement is not fetched or substituted for held-out
specialist gold; its licence/suitability remains O-03.

Live execution requires a dedicated **`qabas_bench_*` database**, fixed synthetic learner profiles in that
isolated database, explicitly reviewed private data and provider configuration. It never empties production
memory: each cold/warm experiment has its own UUID namespace. Raqeeb uses its actual admission/worker pipeline;
the baseline uses the same configured strong model, a minimal registered prompt and no religious tools/gold.
Both systems receive the disjoint warm-up inputs; only Raqeeb has a semantic memory to populate. Native
file/speech input capabilities are available to both. Baseline/model judging uses Phase 11 Message
Batches, strict schemas, policy checks, untrusted-data framing and recorded spend. Hash-only batch IDs are
checkpointed before polling, and results are correlated independently of delivery order. Ambiguous submission
requires operator reconciliation instead of automatic duplicate billing. Schema failures receive one corrective
batch. Refusal, truncation, outages, absent results and budgets never become perfect scores. Batch prices remain
unpriced until O-03 confirms them; no discount or STT price is fabricated.

```powershell
uv run python -m bench.run run --dataset .private/eval/raqeeb --run-id <UUID> --budget-tokens 6000000
uv run python -m bench.run finalize --dataset .private/eval/raqeeb --run-id <UUID> --labels <private-labels.json>
```

The budget must fit the approved dataset; it is not a promised cost ceiling in USD. Warm-up answers are
individually charged/checkpointed before the next case, including spent calls that exceed the budget. Durable private state
resumes unchanged inputs/model/prompt/source/policy identities. Immutable `judged.json` exposes exact outputs
for manual review. Labels bind case/system/cold-or-warm mode and answer SHA-256 to reviewer/date/verdict.
At least 20 judged items and every partial judgment require manual validation. `reviewed.json` preserves those
labels privately. Human release sign-off binds `report_sha256` to the reviewed artifact and `policy_sha256`
to the exact approved release policy, and names an approving owner/date/report/status;
re-running finalization with `--signoff <private-signoff.json>` records the explicit assessment. Neither runner
nor judge enables models, publishes content or replaces final religious/human review.

The strong judge uses medium effort versus the writer's high effort where the selected model declares those
controls (the handoff says "where possible"). Unconfirmed controls remain omitted under Phase 11;
provenance records `not_sent` rather than claiming a requested setting was applied. It reports exactly
`correct|partial|incorrect` and missing points against specialist gold. Independent
Phase 9 re-resolution authenticates citation/evidence/grade bindings; the judge cannot override code findings.
A missing, changed, wrongly bound or currently unavailable authority source cannot pass release verification;
it is reported separately from fabrication rather than hidden within overall accuracy.
A separate strong grounding verifier labels an exhaustive code-owned sentence inventory. Omissions/reordering
fail evaluation; support requires actual per-sentence citation refs and verified source bindings. Semantic
baseline accuracy is measured independently of its missing citations: uncited factual sentences remain unsupported.
The baseline is not required to invent private Raqeeb source IDs or satisfy Raqeeb-only rendering rules;
actual forged citations, wrong evidence and grades are still independently checked for both systems. Reports retain
unrounded rates by class/language, critical failures, error categories, false reuse, latency p50/p95 and known
costs. Private data absent or a warm namespace blocked by cache/model terms means no genuine acceptance claim.

Finalized aggregate results use Phase 16's append-only `benchmark_runs`, unchanged contract metrics and Phase
15's existing admin projection. Re-finalization with identical UUID/results is a no-op; changed reviewed artifacts
are rejected. Synthetic rows never become latest genuine staff metrics; cold/warm times preserve latest-run
ordering. Private questions and reviewer labels never enter the public metrics rows.

Evaluation conversations/files/memory remain in the dedicated benchmark database. To feed the ordinary
application's `/admin/metrics`, privately configure `BENCH_METRICS_DATABASE_URL` and add
`--record-to-metrics` to **finalize**. Only the existing append-only aggregate/provenance rows are transferred,
atomically and replay-safely; no learners, conversations, attachments, questions, gold or reviewer labels are copied.
Credentials never appear as command arguments. Omitting the flag keeps results in the isolated database.
Source, Raqeeb/model-layer and evaluation code hashes are part of resume identity; changing validators cannot
silently resume an older reviewed evaluation or reuse an obsolete memory.

Dependent questions receive each system's own actual prior answers; the private judged report preserves that
context. Prepared baseline transcripts/renditions and batch usage are durable, so recovery does not silently
re-transcribe a submitted request or erase per-answer measurements. Baseline latency is explicitly batch
turnaround, whereas Raqeeb latency is worker completion; these are not interchangeable interactive-service SLAs.

`content/raqeeb_release_policy.yaml` records **pending P-05 proposals**: zero fabricated verses/grades,
100% protective abstention/referral, ≤2% unsupported factual sentences, ≥90% accuracy, ≥80% manual agreement,
and zero false adversarial memory reuse. Critical cases cannot hide in an average. Actual release requires the
private coverage, manual checks, approved thresholds, O-03/O-09/P-04/P-05 and human sign-off. Language, cost and
latency measurements are reported; numerical targets are not invented and may be added by approved policy.
Mandatory protective abstention/referral applies to ordinary and adversarial cases independently of judge scores.
