# Raqeeb text assistant — Phase 16

Raqeeb answers learning questions; it does not review or publish Factory lessons, issue personal rulings,
grade belief, or change learner progress. Revision 10 API §6.8 and backend §7.7/§9 govern its outputs.
Gate 2, immutable lessons/media, blind comparisons and deterministic exercise grading are unchanged.

## Request and recovery

The conversation create/list/get, multipart text-message, assistant polling and feedback endpoints use the
existing contract models. Text is required (1–2,000 characters). Attachments are rejected explicitly until
Phase 17. `ConvCreate.context` is required and nullable in the schema: send `{"context": null}` for no lesson.
Processing responses contain only the five processing fields; private snapshots and traces never leave the API.

Message admission locks user → conversation → message, writes one user/assistant pair and an outbox event
atomically, and uses the existing idempotency service. The DB allows only one processing answer per conversation
and one answer per original message. Logical requests consume the existing 5/minute and 50/day limits; replays do not.
The broker receives message IDs, not questions. `raqeeb` workers acknowledge late; a per-message PostgreSQL
advisory lock plus a lease fences concurrent deliveries. Provider/model calls hold no learner row lock.

The 75-second deadline starts at admission, including queue time. A deadline task and poll/admission checks
terminate expired answers; the periodic 90-second sweeper is a crash fallback. Failed/complete rows are immutable
except feedback; account deletion can purge conversations and their messages. A redelivered unfinished job
reuses committed stage outputs only when framed inputs and prompt digests match. Retrieval checkpoints belong
to that message, not a shared provider cache or semantic memory. Spend records survive stage failures.
A crash between a paid call and checkpoint durability may repeat that call; exactly-once billing is not claimed.

## Pipeline and human boundaries

1. `reading_inputs`: capture text and the accepted conversation snapshot; no attachment/STT processing yet.
2. `classifying`: bilingual safety rules first, then the Phase 11 fast classifier. Exact quotes must bind to
   submitted text. Low-confidence fatwa/sensitive boundaries route protectively.
3. `retrieving`: code chooses the class-specific Phase 9 tools. Provider text and user/history/context data are
   untrusted, never instructions. Sources are bounded to 30,000 characters each and 60,000 in total.
4. `verifying`: the strong verifier checks proposed claims against nominated sources. Unknown source IDs and
   unsupported claims are discarded. Scripture matching and grades are never decided by the model.
5. `writing`: the strong writer drafts contract blocks/citations from supported claims.
6. `adapting`: rewrite paragraph wording only, preserving citation positions; the fast check must confirm the
   same meaning and no new claims, otherwise the original is kept. Code links terms from published glossaries.
7. Guard and `done`: code checks source identity, canonical evidence, grades, citation references and class
   shapes; the fast guard checks generated prose for unsupported facts, personal rulings and ungrounded views.
   One regeneration is allowed, then abstention. Every output also receives a final code guard. Exact policy
   templates and deterministic source cards need no hosted judgment; human-support referrals work offline.

| Class | Tools / output / boundary |
|---|---|
| General knowledge | IslamHouse articles, HadeethEnc, Quran discovery and Mukhtasar tafsir; cited paragraphs, at most one evidence block; no support → specialist |
| Text explanation | Canonical mushaf matching or Quran discovery, Dorar identification; explanation only from Mukhtasar/Sa'di or bound HadeethEnc/Dorar sharh; unidentified text → specialist |
| Verification | Canonical exact/fuzzy discovery then canonical insertion; Dorar verbatim ruling/grader/book; IslamHouse claim support; missing evidence → `needs_specialist` or genuine `not_found` |
| Differing opinions | At least two distinct attributed IslamHouse article/fatwa views, no winner; final specialist referral even when abstaining |
| Personal fatwa | Code-owned alifta.gov.sa referral only; always abstains |
| Doubt/deep creed | Published IslamHouse responses; tafsir for cited verses; inadequate response → specialist |
| Sensitive human | Localized supportive template and trusted-person/local emergency guidance; always abstains; classifier and religious tools bypassed |
| Out of scope | Localized scope explanation; always abstains |

Claim cards cannot become a final authenticity verdict: revision 10 has no claim-verified status. Direct support
may be reported while retaining `needs_specialist`. Unrecognized Dorar rulings retain their verbatim label and
`other`, with specialist escalation. Outages never mean `not_found` or fabricated. An unavailable alternative
lookup does not erase a previously retrieved weak/fabricated ruling. Referrals come from reviewed code-owned
YAML, never a model-generated contact or URL. Human religious review remains necessary.

## Source authority and capabilities

| Component | Role |
|---|---|
| Digest-pinned King Fahd Hafs v3.0 mushaf | Canonical Quran authority; never typed/generated; contract provider remains `quran_com` with true authority in `raw.parts` (D-89) |
| Quran Foundation | Search identity/capability only; provider scripture is ignored and the canonical verse is re-read |
| QuranEnc | Only specialist-approved translations (D-93); no model scripture translation |
| Dorar | Verbatim hadith ruling from search/get/alternate; sharh supplies explanation, never a grade |
| HadeethEnc | Hadith/explanation authority; an explanation is bound to the same Arabic hadith |
| IslamHouse | Published article/fatwa authority; book metadata alone cannot answer creed/disagreement questions |
| Tafsir Center | Mukhtasar first, Sa'di fallback for explanation |
| Islamic-content association MCP | Discovery capability only: confirmed tool mapping → record IDs → authority-provider get; separate provenance part, not citable content |

All existing O-03 live/cache gates stand. Association schemas/tool mappings remain pending; REST search is not
invented for HadeethEnc or IslamHouse. Cited records are persisted with original digests/provenance in the final
transaction. Changed source text/attribution aborts the whole answer. Raqeeb and Gate 2 acquire shared source
rows in `(provider, provider_record_id)` order. Existing registry IDs are adopted without modifying answer text.

## Context, recommendations and models

Conversation language/track and context are captured once. An active lesson supplies its exact served snapshot,
even after a new publication or a track/language change. Otherwise context follows normal published lesson
access. Exercises in model context contain references only, with no answer keys. The classifier/writer receive
the last six messages, not the full history. No learner/conversation/message ID is sent to a model.
Term links use published glossary cards and existing learner term states; no term promotions or mastery writes.
Titles use the registered fast prompt (at most six words); title/recommendation failure cannot invalidate an answer.

Every hosted call uses `app/llm/`, locked prompts, strict schemas, existing model policy, budget and usage ledger.
The six prompts are `raqeeb_classify`, `raqeeb_verify`, `raqeeb_write`, `raqeeb_rewrite`,
`raqeeb_rewrite_check`, and `raqeeb_guard`; `conversation_title` is reused. O-03 model approvals remain pending.
Staging/production hosted learner-question processing additionally requires an approved
`content/raqeeb_data_policy.yaml` with actual provider retention, deletion responsibilities, learner disclosure,
owner/date/report (O-09/P-04). No provider retention period is guessed from proposed attachment retention.
Question/history/checkpoints are private conversation data, purged with the account; logs contain metadata only.

Recommendations use local CPU `BAAI/bge-m3`, cosine ≥ 0.6 and at most two current published lessons of the
learner's track; normal lesson access still applies. There is no lexical approximation or runtime download.
The optional `embeddings` group supplies Sentence Transformers. An installed model directory must contain
`qabas-model.yaml`: fixed `model: BAAI/bge-m3`, approved status, revision, licence, approver/date/report, and
`files` mapping every relative file path to SHA-256. Inventory/digests are checked before loading offline,
without remote code. Native model acceptance is O-03; it was not installed/live-tested in Phase 16.
Phase 17 can reuse this provider for its embeddings worker and guarded memory.

## Benchmark, metrics and operations

`benchmark_runs` and `app/raqeeb/benchmark.py` resolve F-145 now; Phase 17 still owns `bench/run.py`, the judge,
private datasets, cold/warm guarded-memory evaluation and P-05 release thresholds. The public repository contains
only neutral synthetic fixtures. Real sets belong in git-ignored `backend/.private/eval/` (D-19).
Stored runs are append-only and replay-safe by ID/digest, with aggregate results plus dataset/report digests,
versions, model identities, bilingual counts, manual review/agreement, latency/cost and false-memory-reuse count.
Real runs require 60–80 questions, all eight classes, both languages, ≥20 adversarial cases and ≥20 manual
reviews, comparing the same strong baseline model. These composition checks do not establish release quality.

Existing `/admin/metrics` reads the latest authoritative nonsynthetic run; rebuilding/replaying events cannot
double-count it. Synthetic rows are allowed only in dev/test and excluded from this projection. Until a real
private run is recorded, the benchmark remains `null`. No private benchmark or production approval was invented.

Run `uv run celery -A app.workers.celery_app worker -Q raqeeb --pool=solo` alongside the existing outbox relay,
maintenance worker and beat. Configure `RAQEEB_BUDGET_TOKENS` (default 30,000), approved policy paths and source
adapters. For optional recommendations: `uv sync --group embeddings`, then set `RAQEEB_EMBEDDING_MODEL_DIR` to
the approved offline directory. Paid/provider calls are absent from CI. O-03, O-09/P-04, D-93 and P-05 remain
open; O-02/O-05/O-13/O-06/O-12 and real lesson publication blockers are unchanged.

Sentence Transformers' [local-only model API](https://sbert.net/docs/package_reference/sentence_transformer/model.html)
and the [bge-m3 model repository](https://huggingface.co/BAAI/bge-m3/tree/main) describe the optional native runtime.
