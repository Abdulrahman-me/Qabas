# API requirements and canonical public contract

**Purpose:** own endpoint methods/paths, request/response fields, enums, error envelopes, multipart limits, polling, shared objects, exercise answer/details shapes and WebSocket events. Both teams implement this contract.

**Baseline:** contract **revision 10 candidate** = effective reply8 / revision 9 (including the verified revision 8 helper/export repairs) plus the final-engineering-review changes in [CHANGES.md](contract_revision10/CHANGES.md). The canonical machine inputs are [models](contract_revision10/contract/qabas_contract.py), [custom-exported schema](contract_revision10/contract/qabas_contract.schema.json), [dispatch map](contract_revision10/contract/dispatch_map.json), [contextual rules](contract_revision10/contract/contextual.py), [reviewer gate digest](contract_revision10/contract/review.py), [scene schema](contract_revision10/contract/scene.schema.json) with its [normative renderer semantics](../07_ANIMATION/SCENE_RENDERER_SEMANTICS.md), and [category-art registry](contract_revision10/contract/exercise_art_registry.json). Use all of these; JSON Schema alone cannot validate served IDs/private grading/context. The received revision 9 delivery stays unchanged under `10_REFERENCE` for audit; do not generate code from it.

## Mandatory integration rules

- All nullable response fields are present with null when inapplicable; no `exclude_none`. The only partial request body is `PATCH /me` (`MePatch`). IDs are opaque. No private grading/misconception key enters learner content or a public CDN.
- Generate/check complete OpenAPI and Dart DTOs against the custom export (99 roots: every request and response body used by an endpoint, plus nested Exercise/ReviewerExercise payload, server WsEvent and client WsClientMessage data discriminators). Unmodified Pydantic schema export retains generic dictionaries and is not the agreed production DTO source. The delivered six Dart display DTOs are isolated reference adapters, not a complete Session/client.
- Recorded `(session_id, exercise_id, is_retry)` identities replay the stored mode-permitted response before validating a changed answer body. Fresh attempts require served-context validation, authoritative deadlines/ownership and a database transaction. `POST /sessions/{id}/finish` replays the stored `SessionResult` the same way.
- Every HTTP request carries the contract identity headers in §3.2 (WebSocket upgrades authenticate with the ticket in `ws_url` instead). Non-idempotent creates that are expensive or user-visible require an `Idempotency-Key` (§3.2).
- Reviewer gate decisions echo `FactoryRun.review_digest`; a stale digest is rejected (`409 review_stale`), so approval always refers to the exact plan/draft the reviewer saw.
- Canonical Arabic, secondary labels, category artwork and order presentation are display data, never grading inputs. Preserve captured/authored public arrays on resume. Use typed stored glossary in factory/reviewer projections.
- Simulated/test fields `_mock_*`, native answer-bearing exports, synthetic media and unpublished gold are not production learner fields or approved content. Reference candidates have unavailable audio and publication blockers.
- Public changes require synchronized requirements, models/export/OpenAPI/Dart/fixtures/context checks plus version-aware migration. No team independently adds public paths/fields/enums.

The numbered sections below retain original contract section identifiers for existing references. [The section map](SECTION_REFERENCE_MAP.md) locates UI/mock/reference sections moved into dedicated documents. Inherited introductory counts/claims in examples do not imply runtime completion; [the evidence register](../09_VALIDATION/EVIDENCE_REGISTER.md) records actual verification.

## 3. Conventions

### 3.1 Base URLs
| Env | REST | WebSocket |
|---|---|---|
| Local | `http://localhost:8000/v1` | `ws://localhost:8000/v1/ws` |
| Deployed | `https://<API_HOST>/v1` | `wss://<API_HOST>/v1/ws` |

Configure via `--dart-define=API_BASE_URL=... --dart-define=API_MODE=mock|live`. Clients never build WebSocket URLs themselves: they connect to `Duel.ws_url` exactly as returned by a REST response (§8). Deployed environments use TLS only.

### 3.2 Headers
- `Authorization: Bearer <access_token>` on every request except `POST /auth/guest` and `POST /auth/reviewer`. Never put the access token in a URL.
- `Content-Type: application/json` except multipart endpoints (Raqeeb messages, recitation checks).
- `Accept-Language: ar|en` is optional; if omitted, the backend uses the profile language. Content (lessons, answers, cards) is returned in that language. A session's content language is fixed when the session is created; `GET /sessions/{id}` always returns the stored snapshot, whatever the current header or profile language.
- **Contract identity (rev 10):** every request sends `Qabas-Contract: 10` and `Qabas-Client: <android|ios|web>/<app semantic version>`; every response sends `Qabas-Contract: <server revision>`. Within `/v1` the server only makes additive, backwards-compatible changes for clients at or above its minimum supported revision. A client below that minimum receives `426 client_outdated` (`details.min_contract`, `details.min_app_version`) and shows a blocking update screen. Breaking wire changes require a new revision with a migration plan ([data model](../02_ARCHITECTURE/DATA_MODEL_AND_VERSIONING.md)); pinned sessions keep their served snapshot shape.
- **`Idempotency-Key: <UUIDv4>` (rev 10):** required on `POST /raqeeb/conversations/{id}/messages` and `POST /recitation/checks`; accepted on every other `POST` that creates a resource (`/raqeeb/conversations`, `/friends/invites`, `/duels`, `/admin/factory/runs`). The server stores key → response per user for 24 h. A retry with the same key and the same body returns the stored response (same status); the same key with a different body returns `409 idempotency_conflict`. Generate one key per user action and reuse it for automatic retries of that action. Answers and finish do not need it: their identity is the attempt/session (§6.5).
- Web builds: the API's CORS policy allows only the deployed app origins, allows the `Authorization`, `Content-Type`, `Accept-Language`, `Qabas-Contract`, `Qabas-Client` and `Idempotency-Key` request headers, and exposes `Qabas-Contract`. Credentials are bearer headers, never cookies. Browsers cannot add headers to WebSocket upgrades, which is one more reason the socket uses the `ws_url` ticket.

### 3.3 Formats
- IDs are opaque strings with prefixes: `usr_`, `unit_`, `les_`, `blk_`, `ex_`, `con_`, `term_`, `mis_`, `src_`, `ses_`, `conv_`, `msg_`, `att_`, `rchk_`, `duel_`, `run_`, `pair_`, `sen_`, `clm_`, `scn_`, `inv_`. Never parse them.
- Timestamps are ISO-8601 UTC strings: `2026-10-04T09:15:00Z`.
- Durations are integers in **milliseconds** with an `_ms` suffix.
- Percentages are integers 0–100. Mastery is a float 0.0–1.0.
- Absent optional fields are sent as `null`, never omitted.

### 3.4 Errors
Any non-2xx response has this body:
```json
{
  "error": {
    "code": "validation_error",
    "message": "daily_goal_minutes must be one of 5, 10, 15, 20",
    "details": { "field": "daily_goal_minutes" }
  }
}
```

| HTTP | `code` values | UI handling |
|---|---|---|
| 400 | `validation_error` | Show message inline. |
| 401 | `unauthorized` | Learner: delete the stored token. Guest progress cannot be recovered without the token, so show the localized "session ended" notice, then call `POST /auth/guest` and start onboarding (S2). Never loop S1 → 401 → S1. Reviewer: go to R1. |
| 403 | `forbidden` | Reviewer routes accessed by a learner; a resource owned by another user; a challenge the caller is not a player of. |
| 404 | `not_found` | Generic not-found state. `GET /leagues/current` before the learner's first XP of the week returns 404 with `details.reason = "no_league_this_week"` (S13 empty state). |
| 409 | `nothing_to_review`, `out_of_order`, `retry_not_allowed`, `session_finished`, `session_not_active`, `recitation_check_mismatch`, `duel_not_joinable`, `invite_invalid`, `already_friends`, `run_not_at_gate`, `review_stale`, `idempotency_conflict`, `answer_in_progress`, `prerequisite_unmet` | Refresh the resource and show the message. `review_stale`: reload the run and review again. `prerequisite_unmet` (curriculum amendment): show the Soft Lock from `details.prerequisite_lesson_ids` / `details.start_with_lesson_id` (§6.5). |
| 413 | `payload_too_large` | Show limit (see §3.7). |
| 415 | `unsupported_media_type` | Show accepted types. |
| 426 | `client_outdated` | Blocking update screen (§3.2). |
| 429 | `rate_limited` | Retry after `details.retry_after_ms` (limits: [backend §5.1](../05_BACKEND/BACKEND_HANDOFF.md)). |
| 500 | `internal_error` | Retry button. |
| 503 | `upstream_unavailable` | "Sources are temporarily unavailable, try again shortly." Also used when recitation checking is at capacity (`details.retry_after_ms`). |

`ErrorBody.code` stays a string on the wire so older clients tolerate new codes; they fall back to the HTTP-status row. Adding a code is still a contract change recorded in `contract_revision10/CHANGES.md` and this table.

### 3.5 Pagination
List endpoints accept `?cursor=<opaque>&limit=<int, default 20, max 50>` and return `{ "items": [...], "next_cursor": "..." | null }`.

### 3.6 Rich text (`Span[]`)
All learner-facing text that may contain terms, citations, or emphasis is an array of spans. Render inline, in order.

| `type` | Fields | Render |
|---|---|---|
| `text` | `text` | Plain text. |
| `strong` | `text` | Bold. |
| `term` | `text`, `term_id` | If the term's state (from the enclosing payload's `terms` map) is `new` or `learning`, draw a **dotted underline**; tap opens the Term card (S8). If `mastered`, render as plain text. |
| `citation` | `ref` (int) | Superscript `[ref]`; tap scrolls to/opens the matching entry in the enclosing `citations` list. |

```json
[
  { "type": "text", "text": "يؤمن المسلمون بأن الله واحد، وهذا هو " },
  { "type": "term", "text": "التوحيد", "term_id": "term_tawhid" },
  { "type": "text", "text": "." },
  { "type": "citation", "ref": 1 }
]
```

### 3.7 Upload limits
| Upload | Types | Limit |
|---|---|---|
| Raqeeb text | — | 2,000 characters |
| Raqeeb voice | `audio/mp4` (m4a/AAC), `audio/webm` (Opus), `audio/wav`, `audio/mpeg` | 60 s, 10 MB |
| Raqeeb images | `image/jpeg`, `image/png`, `image/webp` | up to 3, 8 MB each |
| Raqeeb document | `application/pdf`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document` | 1 file, 10 MB (first 20 pages processed) |
| Recitation | same audio types as voice | 30 s, 5 MB |

Validate on the client before sending; the backend enforces the same limits. The backend also checks the file signature (magic bytes) and decoded duration/page count rather than trusting the declared MIME type or filename, rejects encrypted/macro-enabled documents, and caps decoded image dimensions (≤ 40 megapixels) before any processing.

**Privacy of uploads:** learner uploads are private. Raqeeb attachments are stored in a private bucket and `Attachment.url` is a short-lived signed URL (≤ 15 min) that only the owner receives; re-fetch the conversation to refresh an expired URL. Recitation audio is processed transiently and never stored or returned (only the check result is persisted). Learner uploads never go to the public content CDN.

### 3.8 Media and visuals

Two different things can appear where a picture is shown, and they are never confused:

| Representation | What it is | Delivery |
|---|---|---|
| **Built-in visual** (`Visual.kind = "builtin"`) | A scene implemented in Flutter code (e.g., the house and river, the office with the wall clock, the day arc, the pillars). | Compiled into the app. **Nothing is downloaded.** The API sends only a registered key, version, and params (§5.5b–§5.5c). Never executable code or per-frame instructions. |
| **Generated scene** (`Visual.kind = "scene"`) | An agent-authored animated illustration: a versioned declarative manifest (layers, vector shapes, optional referenced artwork, named states, bounded animation tracks). | Download the `.scene.json` manifest (`application/json`) and its referenced assets from the CDN; the bundled scene renderer interprets them locally. Immutable per version; cached by `scene_id` + `version` + `sha256` (§5.5e). |
| **Downloaded image** (`Visual.kind = "image"`) | A static raster illustration or map generated and audited by the backend. | Absolute CDN URL with explicit `mime_type`, `width`, `height` (§5.5a). |

**File formats**
| Asset | Formats | `mime_type` | Notes |
|---|---|---|---|
| Generated illustrations and maps | WebP (preferred); PNG and JPEG supported | `image/webp`, `image/png`, `image/jpeg` | The server sends the matching HTTP `Content-Type`. **The client never infers the type from the URL suffix**; it uses `mime_type`. |
| Calligraphy medallions (`Overlay`) | SVG | `image/svg+xml` | Rendered with an SVG renderer, composited by Flutter. |
| Scene manifests | JSON (`.scene.json`, schema `qabas.scene/1`) | `application/json` | Verified against `scene.sha256` before use. |
| Scene assets | SVG (static, no scripts/text) or WebP/PNG/JPEG | per asset in the manifest | Listed with size and `sha256`; limits in `contract/scene_capabilities.json`. |
| Reciter audio, story narration, term pronunciation | MP3 | `audio/mpeg` | `audio.url`, `narration_audio_url`, `pronunciation_audio_url`. |

**Sizing:** generated scene illustrations are produced at 1600×1000 (16:10); maps at 1600×1200 (4:3). The client always lays an image out with the aspect ratio `width / height` from the payload (no cropping that would move pins or overlays). Built-in visuals use the proportion defined for **that use** in §5.5d (the same renderer is drawn at different proportions in different places).

**Fallbacks (lesson must stay readable and usable):**
1. Built-in visual with an unknown `key` or unsupported `version` → render `fallback_image` if non-null; otherwise a neutral placeholder panel showing `alt`.
2. Downloaded image fails to load → neutral placeholder panel showing `alt`, with a small retry action.
3. The block's text, evidence, and buttons are always rendered regardless of visual failures.
4. Scene with an unsupported capability, a manifest/asset download or checksum failure, or an unknown `schema_version` → render `fallback_image` (always present for scenes, same proportion as the scene's view box); if that fails too → placeholder with `alt`.
5. `map_place` hotspots on a fallback are usable only because of two guarantees enforced at publish: (a) graded targets are **static** — every pin is bound to a scene anchor whose layer cannot move by state or animation beyond small decorative limits (§5.5e), and (b) the fallback is rendered **at the exercise's authored state** (`fallback_params == params`). If the scene and its fallback both fail, or a client can't confirm these (unknown schema), the exercise offers "Continue" and submits `{ "unavailable": true }` (§7.12). A matching proportion alone is never treated as sufficient.

Cache downloaded images with a network image cache.

**Delivery and caching:** published content media (images, scene manifests/assets, fallbacks, medallions, reciter/narration/pronunciation audio) lives on the public content CDN under immutable, versioned paths with `Cache-Control: public, max-age=31536000, immutable` and the exact `Content-Type`. Replacing media always publishes a new path; nothing is overwritten in place, so cached copies and pinned sessions stay valid. Reviewer-only previews and draft media are served from private storage through signed URLs. Clients verify `sha256` wherever the payload declares one and treat a mismatch as a download failure (fallback rules above).

---

## 4. Enums

| Enum | Values |
|---|---|
| `Track` | `explorer`, `new_muslim` (Explorer starts at Unit 0, New Muslim at Unit 1; Units 1–10 are shared) |
| `TrackChoice` (onboarding only) | `explorer`, `new_muslim`, `undisclosed` (backend maps `undisclosed` → `explorer`) |
| `Language` | `ar`, `en` |
| `Role` | `learner`, `reviewer` |
| `UnitState` | `locked`, `available`, `in_progress`, `completed`, `skipped` (§6.3) |
| `LessonState` | `locked` (unmet mandatory prerequisite → `soft_lock`), `available`, `in_progress`, `completed` (§6.3) |
| `LessonType` | `concept`, `story`, `practice` |
| `SessionKind` | `lesson`, `review`, `pretest`, `unit_test` |
| `FeedbackMode` | `immediate` (lesson, review), `none` (pretest), `end` (unit_test) |
| `SessionStatus` | `active`, `finished`, `abandoned` |
| `BlockType` | `paragraph`, `evidence`, `visual`, `callout`, `hook`, `story`, `teach`, `predict`, `exercise` |
| `VisualKind` | `builtin`, `image`, `scene` |
| `VisualKey` (built-in registry) | `river_house`, `workplace`, `day_arc`, `pillars` |
| `CategorizePresentation` | `buckets`, `day_arc` |
| `DayPhase` | `dawn`, `midday`, `afternoon`, `sunset`, `night` |
| `TeachStyle` | `standard`, `summary` |
| `ScoringLayer` | `understand`, `apply`, `remember` (nullable inside `Exercise.scoring`; response keys are `understanding`, `applying`, `remembering`) |
| `FramingKind` | `myth` |
| `MapPresentation` | `hotspots`, `map_pins` |
| `DisplayRole` | `content`, `activity` (nullable on `Source`) |
| `Familiarity` | `none`, `some`, `good` |
| `DailyGoalMinutes` | `5`, `10`, `15`, `20` |
| `ReviewMode` | `cards` (untimed, self-rated flashcards), `quick` (timed, mixed types) |
| `ChallengePreset` | `duel` (2 players, 7 questions, 15 s), `group` (2–4 players, 3 questions, 10 s) |
| `QuestKind` | `earn_xp`, `complete_lessons`, `perfect_lesson`, `complete_review`, `win_challenge`, `recite_verse` |
| `ExerciseType` | `multiple_choice`, `true_false_reason`, `match_pairs`, `flashcard`, `fill_blank`, `categorize`, `spot_error`, `which_evidence`, `order_steps`, `scenario`, `timeline_order`, `map_place`, `recite_verse`, `verse_meaning`, `true_false` (duels only) |
| `TermState` | `new`, `learning`, `mastered` |
| `TermLevel` | `basic`, `intermediate` |
| `SourceKind` | `quran`, `hadith`, `tafsir`, `article`, `book`, `fatwa` |
| `SourceProvider` | `tafsir_center`, `quran_com`, `hadeethenc`, `quranenc`, `islamhouse`, `dorar` |
| `NextStepType` | `pretest`, `lesson`, `review`, `unit_test`, `journey_complete` |
| `NextStepReason` | `new_unit_pretest`, `due_reviews`, `next_lesson`, `unit_ready_for_test`, `all_done` |
| `QuestionClass` | `general_knowledge`, `text_explanation`, `verification`, `differing_opinions`, `personal_fatwa`, `doubt_or_deep_creed`, `sensitive_human`, `out_of_scope` |
| `MessageStatus` | `received` (user msg), `processing`, `completed`, `failed` |
| `RaqeebStage` | `received`, `reading_inputs`, `classifying`, `retrieving`, `verifying`, `writing`, `adapting`, `done` |
| `AnswerBlockType` | `paragraph`, `evidence`, `verification`, `differing_views`, `referral` |
| `VerificationStatus` | `quran_exact`, `quran_inexact`, `hadith_graded`, `not_found`, `needs_specialist` |
| `HadithGradeCategory` | `authentic`, `acceptable`, `weak`, `fabricated`, `other` |
| `ReferralType` | `fatwa_authority`, `specialist`, `human_support` |
| `RecitationStatus` | `evaluated`, `unclear` |
| `RecitationWordResult` | `correct`, `missing`, `substituted`, `extra` |
| `DuelStatus` | `pending`, `ready`, `in_progress`, `finished`, `expired`, `declined` |
| `DuelMode` | `live`, `async` |
| `OpponentType` | `bot`, `friend`, `friends` |
| `RunStatus` | `running`, `awaiting_gate1`, `awaiting_gate2`, `published`, `rejected`, `failed` |
| `RunStage` | `plan`, `decompose`, `retrieve`, `verify_evidence`, `write`, `exercises`, `glossary`, `localize` (curriculum amendment: Arabic → English localization), `visuals`, `scene_author`, `scene_render`, `narration`, `qa` |
| `QASeverity` | `blocker`, `warning`, `info` |
| `QAKind` | `unsupported_sentence`, `fatwa_like`, `reading_level`, `consistency`, `sensitive`, `image_policy`, `validation` (rev 10: deterministic code-validator finding), `pedagogy`, `belief_grading`, `circular_reasoning`, `localization` (curriculum amendment; severities in factory §13.5), `scholarly_review` (pre-generation audit: the Evidence Verifier's semantic flags on scriptural support) |
| `ReasoningTool` (`LessonPlan.reasoning_tools[].tool`, `ReasoningSupport.tool`) | `observation`, `inference`, `testimony`, `historical_evidence`, `causal_reasoning`, `comparison` (an empty list means none is needed) |
| `SentenceRole` (`Draft.sentence_map[].role`) | `claim`, `framing`, `hypothetical`, `instruction`, `question` |
| `ClaimBasis` (`Claim.basis`) | `source` (scriptural or other verified source support), `reasoning` (reasoning support understandable without first accepting scripture's authority) |
| `MessageErrorCode` (failed Raqeeb message) | `upstream_unavailable`, `internal_error`, `input_unreadable` (rev 10: corrupt/unreadable attachment detected after acceptance) |
| `StageRunStatus` (`FactoryRun.stages[].status`) | `pending`, `running`, `done`, `failed`, `skipped` (rev 10: scene stages are `skipped` when no scene was chosen) |

Localized labels for all enums live in the Flutter l10n files (`ar`, `en`); the backend never sends enum labels except where a `label` field is explicitly present.

---

## 5. Shared objects

### 5.1 `User`
```json
{
  "user_id": "usr_7f3k2a",
  "display_name": "مسافر ٤٧",
  "role": "learner",
  "language": "ar",
  "track": "explorer",
  "daily_goal_minutes": 10,
  "timezone": "Asia/Riyadh",
  "onboarding_completed": true, "avatar_key": "traveler_03", "familiarity": "some", "private_profile": true, "goal_anchor": "who_was_muhammad",
  "created_at": "2026-10-04T09:00:00Z"
}
```
`display_name` is auto-generated at guest creation and editable. `goal_anchor` (nullable) is the onboarding curiosity choice (§6.1), a key of the `goal_anchors` registry; it selects the onboarding bridge only and is never used to order the curriculum, recommend lessons, adapt content or infer anything about the learner's religion. No field records the learner's religion or worldview. `avatar_key` selects one of the prototype's bundled faceless traveler avatars (keys from the Flutter avatar set; unknown key → default avatar); no photos or avatar uploads exist. `familiarity` (nullable) is stored from onboarding and not used by adaptation yet. `private_profile` (default `true`) hides the learner's XP and streak from friends and shows them to other league members only as an anonymous name and default avatar.

### 5.2 `Source`
Used in lesson `sources`, Raqeeb `citations`, verification cards, and the reviewer evidence panel.
```json
{
  "source_id": "src_q_112_1_4",
  "kind": "quran",
  "provider": "quran_com",
  "title": "سورة الإخلاص",
  "reference": "الإخلاص: 1–4",
  "excerpt": "قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ",
  "url": "https://quran.com/112",
  "displayed": true, "display_role": "content"
}
```
`displayed=true` means this source is shown as evidence somewhere in the lesson; `display_role` says where: `content` (an `evidence` block, `teach.evidence`, or a story `quote`) or `activity` (the verified source an activity introduces itself, e.g., the Quran segment of a `recite_verse`). `display_role` is `null` exactly when `displayed=false`. Budget rules in §6.5.3. The sources drawer lists all sources; displayed ones first. The lesson intro's source count = number of displayed sources (`Session.source_count`).

### 5.3 `Evidence`
A displayable proof text. Exactly one of `quran` / `hadith` is non-null.

**Quran evidence** (with reciter audio; `words` timings may be `null` → play the whole clip, no word highlighting):
```json
{
  "evidence_id": "src_q_112_1_4",
  "kind": "quran",
  "quran": {
    "surah": 112,
    "surah_name": "الإخلاص",
    "ayah_start": 1,
    "ayah_end": 4, "segment": null,
    "text_uthmani": "قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ",
    "translation": "قل: هو الله الواحد، الذي يُقصد في الحوائج، لم يلد ولم يولد، ولا مثيل له.",
    "translation_source": "المختصر في التفسير — مركز تفسير",
    "audio": {
      "reciter": "مشاري راشد العفاسي",
      "url": "https://cdn.example.com/quran/afasy/112001-112004.mp3",
      "words": [
        { "ayah": 1, "position": 1, "text": "قُلْ", "start_ms": 0, "end_ms": 520 },
        { "ayah": 1, "position": 2, "text": "هُوَ", "start_ms": 520, "end_ms": 900 },
        { "ayah": 1, "position": 3, "text": "اللَّهُ", "start_ms": 900, "end_ms": 1650 },
        { "ayah": 1, "position": 4, "text": "أَحَدٌ", "start_ms": 1650, "end_ms": 2900 }
      ]
    }
  },
  "hadith": null
}
```
*(Fixture note: `words` is abbreviated to ayah 1; the real payload covers every word in the range.)*

**Hadith evidence:**
```json
{
  "evidence_id": "src_h_niyyat",
  "kind": "hadith",
  "quran": null,
  "hadith": {
    "text_ar": "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى",
    "translation": "Actions are only by intentions, and every person will have only what they intended.",
    "narrator": "عمر بن الخطاب رضي الله عنه",
    "collections": ["صحيح البخاري (1)", "صحيح مسلم (1907)"],
    "grade_label": "صحيح",
    "grade_category": "authentic",
    "grade_source": "متفق عليه", "excerpt": false
  }
}
```
`translation` is `null` when the content language is `ar`.
`segment` is `null` for whole ayat. For part of a single ayah it is `{ "word_start": 14, "word_end": 20 }` (1-based word positions within the ayah, inclusive; `ayah_start = ayah_end`), and `text_uthmani` contains exactly those words. Displayed text, audio clip, expected recitation words, and the recitation checker all use the same segment.
`excerpt` is `true` when `text_ar` is a verbatim, contiguous part of a longer hadith (e.g., a story quote split across beats). `collections`, `grade_label`, and `grade_category` always describe the full hadith. Hadith evidence shown to learners is always graded `authentic` or `acceptable`, except inside Raqeeb verification cards.

### 5.4 `TermCard`
```json
{
  "term_id": "term_tawhid",
  "text": "التوحيد",
  "transliteration": "Tawhid",
  "state": "new",
  "level": "basic",
  "definition": [
    {
      "type": "text",
      "text": "الإيمان بأن الله واحد لا شريك له، وأنه وحده من يستحق العبادة."
    }
  ],
  "example": [
    {
      "type": "text",
      "text": "سورة الإخلاص تلخّص معنى التوحيد في أربع آيات قصيرة."
    }
  ],
  "pronunciation_audio_url": "https://cdn.example.com/terms/term_tawhid.mp3",
  "source_id": "src_q_112_1_4",
  "lesson_id": "les_u2_l1",
  "lesson_title": "من هو الله؟",
  "arabic": null
}
```
The backend picks `level` for the current learner. `text` is the localized heading; `transliteration` and `arabic` are separate display values. `arabic` is a required nullable field containing the canonical Arabic word, including its authored diacritics. Render a non-null value as in `TermSheet`: explicit RTL, `QFonts.arabicDisplay` (Amiri), size 34, height 1.3. Null omits that word; never reconstruct it from the heading, transliteration, or an app dictionary. Show definition, example, source reference (if any), and "Learn more" → lesson. Session, glossary and Raqeeb TermCards share this shape. The example above uses null because this historical specimen supplies no separately approved canonical Arabic display.

### 5.5 `Overlay` (image compositing)
Images never contain generated Arabic text or depictions of prophets or companions. When a prophet or companion is referenced in a scene, the backend sends a **calligraphy medallion** overlay (an SVG asset) that the client draws on top of the image.
```json
{
  "type": "medallion",
  "asset_url": "https://cdn.example.com/medallions/ibrahim.svg",
  "label": "إبراهيم عليه السلام",
  "anchor": "top_start",
  "size_pct": 22
}
```
`anchor`: `top_start` | `top_end` | `center` | `bottom_start` | `bottom_end` (start/end follow reading direction). `size_pct` = medallion width as % of the visual's width. Overlays can be attached to any `Visual` (built-in or image).

### 5.5a `Image`
A downloaded raster file.
```json
{
  "url": "https://cdn.example.com/scenes/u7_l4_s1_night_sky.webp",
  "mime_type": "image/webp",
  "width": 1600,
  "height": 1000
}
```
`mime_type` ∈ `image/webp`, `image/png`, `image/jpeg`. `width`/`height` are pixels and define the aspect ratio used for layout and for pin coordinates.

### 5.5b `Visual`
The single descriptor for anything pictured in a lesson block or illustrated exercise. All fields are always present; fields that don't apply to the `kind` are `null`.

| Field | `kind = builtin` | `kind = image` | `kind = scene` |
|---|---|---|---|
| `kind` | `"builtin"` | `"image"` | `"scene"` |
| `key` | registered `VisualKey` | `null` | `null` |
| `version` | integer ≥ 1 | `null` | `null` (the scene version is in `scene`) |
| `params` | object (may be `{}`), validated per registry | `null` | object (may be `{}`): initial values of the scene's declared states |
| `image` | `null` | `Image` | `null` |
| `scene` | `null` | `null` | `SceneRef` (§5.5e) |
| `fallback_image` | `Image` or `null` | `null` | `Image`, **required**, same proportion as the scene view box |
| `fallback_params` | `null` | `null` | object, **required**: the declared state the fallback was rendered at (normally equal to `params`; **must** equal `params` in a `map_place`) |
| `alt` | string (always non-empty, localized) | string | string |
| `overlays` | `Overlay[]` (often `[]`) | `Overlay[]` | `Overlay[]` (positioned in the scene's box) |

Built-in example — selects the bundled house-and-river scene at beat 3:
```json
{
  "kind": "builtin",
  "key": "river_house",
  "version": 1,
  "params": { "beat": 3 },
  "image": null,
  "scene": null, "fallback_image": null, "fallback_params": null,
  "alt": "بيت أمامه نهر جارٍ، وفوقه خمسة أضواء",
  "overlays": []
}
```
Downloaded image example:
```json
{
  "kind": "image",
  "key": null,
  "version": null,
  "params": null,
  "image": { "url": "https://cdn.example.com/scenes/u7_l4_s1_night_sky.webp", "mime_type": "image/webp", "width": 1600, "height": 1000 },
  "scene": null, "fallback_image": null, "fallback_params": null,
  "alt": "سماء ليل صافية فيها كوكب لامع فوق صحراء",
  "overlays": [
    { "type": "medallion", "asset_url": "https://cdn.example.com/medallions/ibrahim.svg", "label": "إبراهيم عليه السلام", "anchor": "top_start", "size_pct": 22 }
  ]
}
```
Rules:
- The backend sends only the **authored/initial** state in `params`. Flutter owns continuous motion and any state changes caused by local actions (§5.6, §7.6).
- Built-in scenes, images, maps, and pins are **not mirrored** in RTL; only surrounding UI follows reading direction. **Exception — `pillars`:** in Arabic, the pillars renderer is flipped (as `TeachView` does in the prototype) or uses an equivalent column mapping, so each pillar stays above its localized label in reading order and the highlighted column stays above its label.
- With reduced motion enabled, a built-in scene renders a readable static frame for its current params, and state changes apply without animated transitions.

### 5.5c Built-in visual registry (version 1)
Flutter must implement every entry; the backend accepts only these keys, versions, and params. Adding a key or version requires a Flutter implementation first, then a contract update. Reuse the prototype painters in `qabas/lib/widgets/scenes.dart`, including their loop timings.

| `key` | `version` | `params` | Meaning of states | Loop | Prototype implementation |
|---|---|---|---|---|---|
| `river_house` | 1 | `{ "beat": 0..3 }` (required) | `0` establishing view: house, palms, flowing river · `1` the river as the focus of the parable (places and light only — **no people are drawn**) · `2` clean-light sparkles on the water · `3` five prayer lights | 5 s | `RiverHouseScene(beat:)` |
| `workplace` | 1 | `{}` | Office with an illustrative wall clock near 12:10 with a moving second hand, and steam from a cup. Not tied to the user's real clock or location. | 60 s | `WorkplaceScene` |
| `day_arc` | 1 | `{ "highlight": -1..4 }` (required) | `-1` no moment highlighted · `0..4` = `dawn`, `midday`, `afternoon`, `sunset`, `night` (sky and sun follow the highlight) | 8 s | `DayArcScene` + `PhaseIcon` |
| `pillars` | 1 | `{ "highlight": 0..4 }` (required) | Highlighted pillar in canonical order: `0` testimony of faith · `1` prayer · `2` zakat · `3` fasting · `4` Hajj. Flutter renders the **five localized labels** under the columns (bundled l10n strings, not API content) and emphasizes the highlighted label. RTL rule in §5.5b. | 4 s | `PillarsScene(highlight:)` |

### 5.5d Scene proportions by use
A built-in renderer scales its geometry to its box, so the proportion (width ÷ height) is defined **per use**, not per key. These values are taken from the prototype widgets and are frozen; pins on built-in scenes are authored in the box of their use.

| Use | Key(s) | Width ÷ height | Prototype widget |
|---|---|---:|---|
| `hook.visual` | any built-in | **1.75** | `hook_view.dart` |
| `story` beat `visual` | any built-in | **1.5** | `story_view.dart` |
| `teach.visual` | `river_house`, `pillars` | **1.9** | `teach_view.dart` |
| `teach.visual` | `workplace` | **1.9** | — (no prototype use; contract default) |
| `teach.visual` | `day_arc` | **2.1** | `teach_view.dart` |
| `map_place` with `presentation: hotspots` | any built-in | **1.15** | `discover_view.dart` |
| `categorize` with `presentation: day_arc` (the arc above the slots) | `day_arc` (implicit) | **2.8** | `timeline_view.dart` |
| `visual` block, `predict.visual` | any built-in | **1.75** | — (no prototype use; contract default = hook proportion) |
| any use | `kind: image` | `image.width ÷ image.height` | — |
| any use | `kind: scene` | `scene.view_box.width ÷ height` (the factory authors the view box for the use it targets) | — |

A new use or a new key must add a row here (and in the backend registry) before content can use it.

### 5.5e Generated animated scenes (`kind: scene`)
Agent-authored lesson scenes are **data, not code**: a versioned `.scene.json` manifest (schema `qabas.scene/1`, `contract/scene.schema.json`) interpreted by the bundled Flutter renderer `packages/qabas_scene`. The manifest declares a view box, palette (hex or app theme tokens), optional static assets, **named state inputs**, layers (group, rect, ellipse, SVG-subset path, placed asset, bounded sparkle field) with transforms, clipping, **state rules** (property values + transition when a state condition holds) and **bounded keyframe tracks** (translate, rotation, scale, opacity; easing; loop none/repeat/ping-pong; optional `active_when` condition), named **anchors**, a reduced-motion still time, and deterministic preview frames/states. It never contains code, scripts, text glyphs, scripture, or labels — those are Flutter UI overlays.

`SceneRef` (inside `Visual.scene`):
| Field | Type | Notes |
|---|---|---|
| `scene_id` | string | stable id (`scn_…`) |
| `version` | int ≥ 1 | immutable content version; a change publishes a new version |
| `schema_version` | `"qabas.scene/1"` | manifest schema |
| `url` | string | absolute CDN URL of the manifest (`…/scene.json`) |
| `mime_type` | `"application/json"` | always explicit |
| `sha256` | hex string | checksum of the manifest bytes; verify before use |
| `view_box` | `{ width, height }` | the coordinate space of this occurrence: pins (`x_pct`/`y_pct`), anchors, and overlays use it; no implicit cropping; never mirrored in RTL |
| `required_capabilities` | string[] | capability ids from `contract/scene_capabilities.json` |

Example (the test lesson in `fixtures/`; manifest `fixtures/scenes/scn_test_desert_well.v2.scene.json`):
```json
{
  "kind": "scene",
  "key": null,
  "version": null,
  "params": {"beat": 0, "focus": -1},
  "image": null,
  "scene": {
    "scene_id": "scn_test_desert_well",
    "version": 2,
    "schema_version": "qabas.scene/1",
    "url": "https://cdn.example.com/scenes/scn_test_desert_well/v2/scene.json",
    "mime_type": "application/json",
    "sha256": "145f9fd45a554b9e5c77e2b796ba4814fd85d46d72a9b1a91543b3a155e0d7e7",
    "view_box": {"width": 1600, "height": 1000},
    "required_capabilities": [
      "scene/1",
      "shape.rect/1",
      "shape.ellipse/1",
      "shape.path/1",
      "paint.gradient/1",
      "track/1",
      "anchors/1",
      "fx.sparkles/1"
    ]
  },
  "fallback_image": {
    "url": "https://cdn.example.com/scenes/scn_test_desert_well/v2/fallback_b0_f-1.webp",
    "mime_type": "image/webp",
    "width": 1600,
    "height": 1000
  }, "fallback_params": {"beat": 0, "focus": -1},
  "alt": "صحراء ليلاً فيها بئر ونخلة وخيمة",
  "overlays": []
}
```
Rendering rules:
- **Fallbacks:** `fallback_params` records the declared state the fallback image shows. Backends render one fallback per distinct authored state that needs it (e.g., each exercise's state).
- **States:** `Visual.params` gives initial values for the manifest's declared states (validated: names, types, ranges; missing → manifest default). Story beats and `TeachPoint.visual_params` change them exactly as for built-in scenes (§5.6): consecutive beats with the same `scene_id`+`version` keep one mounted renderer and transition via the manifest's `state_rules`. Local interactions (e.g., selecting a hotspot) may set declared states immediately; correctness still comes only from the server evaluation.
- **Motion:** tracks run on the local animation clock; no network per frame. With reduced motion, render the still at `reduced_motion.still_time_ms` for the current state and apply state changes without transitions.
- **Capabilities:** the client compares `required_capabilities` with its own released registry. If any is missing (older app), render `fallback_image` — never a partial scene. A capability can be used by published content only after it is `released` in the registry and shipped in the app.
- **Limits and performance:** manifest ≤ 256 KB, ≤ 60 layers, ≤ 120 tracks, ≤ 12 keyframes per track, ≤ 6,000 path commands, ≤ 8 assets (≤ 1 MB each, ≤ 2 MB total), ≤ 6 states; target 60 fps with ≤ 8 ms frame build+raster on the reference mid-range devices and ≤ 150 ms decode to first frame (`contract/scene_capabilities.json`).
- **Caching:** cache manifests and assets by `scene_id`/`version`/`sha256`; active sessions keep the version they were served.
- **Hotspots/anchors:** manifest anchors are **static view-box points** (`anchor_id`, `layer_id`, `x`, `y`, `radius`). An anchored layer and its ancestors may not change position, rotation, or scale by state or track; its descendants may move only within the decorative limits in `scene_capabilities.json` (≤ 2 % translate, ≤ 10° rotation, scale 0.9–1.1). `map_place` pins on a scene each carry `anchor_id` and must lie inside that anchor's radius. Flutter draws the pin layer in the same view-box box as the scene, so pins stay aligned at any size; anchors do not follow transforms because the anchored objects cannot move. Correct-answer mappings stay in the private exercise key.
- **Interactions:** `map_place.interaction` (§7.12) maps a selected pin to declared state values (e.g., selecting the palm sets `focus: 1`), optionally resets on deselect, and may apply one state change **after** evaluation per outcome. Flutter applies these locally; it never infers bindings from ids, labels, or text.
- **Previews:** the reviewer console and the backend's preview tool use the same renderer package, so frames, state previews, and reduced-motion stills match what learners see.

### 5.6 `Block`
`Sentence` = `{ "sentence_id": string, "spans": Span[], "source_ids": string[] }`. Long-press any sentence to show a mini sheet with its sources (filter the session's `sources` by `source_ids`).

Common block fields: `block_id`, `type`. Type-specific fields:

| `type` | Fields |
|---|---|
| `paragraph` | `sentences: Sentence[]` |
| `evidence` | `evidence: Evidence`, `caption: Span[] \| null` |
| `visual` | `visual: Visual`, `caption: Span[] \| null` |
| `callout` | `variant: "tip" \| "note"`, `spans: Span[]` |
| `hook` | `situation: Span[]`, `question: Span[]`, `visual: Visual`, `cta: string \| null` |
| `story` | `label: string` (e.g., "قصة" / "Story", or "موقف" / "Scenario"), `title: string \| null`, `provenance: Provenance \| null`, `beats: StoryBeat[]` (≥ 1), `origin: { title: string, source_ids: string[], show_card: bool } \| null` (null = teaching scenario) |
| `teach` | `eyebrow: string \| null`, `title: Span[]`, `style: TeachStyle`, `visual: Visual \| null`, `evidence: Evidence \| null`, `points: TeachPoint[]` (≥ 1) |
| `predict` | `prompt: Span[]`, `options: [{ option_id, spans: Span[] }]` (2–4), `reveal: Span[]`, `visual: Visual \| null` |
| `exercise` | `exercise: Exercise` |

`StoryBeat` = `{ "beat_id", "beat_index", "narration": Sentence[], "narration_audio_url": string | null, "quote": Evidence | null, "quote_meaning": Span[] | null, "visual": Visual }`
`Provenance` = `{ "source_id", "provider": SourceProvider, "reference": string, "grade_label": string | null }` — the story's main source, shown as the grade / reference / provider tags on **every** beat, including beats without a quote.
`TeachPoint` = `{ "point_id", "sentence": Sentence, "visual_params": object | null }`

**Presentation rules** (explicit — never infer a layout from ids or text; the prototype widgets named below are the visual baseline):
- **`hook`** (`hook_view.dart`) — real-life opening: `visual` (proportion §5.5d), the `situation`, then the `question` emphasized as the curiosity prompt. CTA text = `cta` or the bundled default ("لنكتشف" / "Let's find out").
- **`predict`** (`choice_view.dart` + `feedback_panel.dart`) — an **ungraded** prediction: before Check, tapping an option gives it the **selected** state while the other options stay **idle**; after **Check**, the selected option takes the neutral "guess" state, the others become **dimmed**, and the neutral gold feedback panel ("فكرة جميلة" / "Nice thinking") shows `reveal`; CTA Continue. No correct/incorrect styling; the neutral sparkle may play subject to local sound/haptics/reduced-motion settings. No network call; nothing is recorded. It counts as one progress step (§6.5.1) and is excluded from accuracy, scores, mastery, misconceptions, FSRS, combos, retries, XP, and quests. The same block carries ungraded opinion interactions such as polls ("Which explanation feels more convincing to you?"): the reveal discusses the reasoning and never treats the learner's choice as wrong. No new block type is used for lesson arcs, polls or predictions.
- **`story`** (`story_view.dart`) — one story experience; beats advance with "Next". Two kinds share the block: a **sourced story** (Qur'an, authentic Sunnah or verified history; `origin` set) and a **teaching scenario** (lesson-composition refinement: a short, explicitly fictional everyday narrative; `origin`, `provenance` and every `quote` are `null`, model-enforced). A teaching scenario shows its `label` (e.g., "موقف" / "Scenario"), title, visual, dots and narration only: no provenance tags, no origin card, nothing in the sources drawer. **Layout order on every beat:** story `label` → `title` → `visual` (scene) → beat dots → `narration` → (if present) one bordered quote card containing the verbatim `quote` (Quran or authentic hadith) and, **inside the same card**, its `quote_meaning` (localized explanation with dotted `term` spans, separate from the exact quotation and from `hadith.translation`) → the `provenance` tags (grade, reference, provider) **below** the narration/quote area. Tags appear on every beat, including beats without a quote. Narration never contains quoted speech. Narration audio **never autoplays**: a play control appears only when `narration_audio_url` is non-null (the reference story is silent). Consecutive beats with the same built-in `key` (or the same scene version) keep one mounted renderer and transition to the new state; otherwise crossfade, using the prototype transitions. After the last beat, the story goes **directly to the next step** unless `origin.show_card` is `true`, in which case the origin card ("من أين جاءت هذه القصة؟") is shown first. A sourced story's provenance is always available from the sources drawer.
- **`teach`** (`teach_view.dart`) — order: `eyebrow` (small label above the title; `null` → none), `title`, `visual`, `evidence` (**shown on entry, above the points**), then `points`.
  - `style: standard`: point 0 is visible on entry; the CTA reads "اعرض المزيد" / "Show more" until every point is visible, then "متابعة" / "Continue". As each new point appears, earlier points are de-emphasized (prototype styling). With *n* points visible, the visual's params are `visual.params` merged with `points[0..n-1].visual_params` in order (later keys win; `null` = no change). Example (Salah reference day-arc card): base `highlight: -1`, point params `null`, `{highlight: 1}`, `{highlight: 4}`, `null` → highlights −1, 1, 4, 4 as 1–4 points are visible.
  - `style: summary`: all points are visible immediately with the prototype's summary styling; CTA "Continue". Used for end-of-lesson summaries.
  - Reveal state is local only (never sent, not persisted on resume). Screen-reader users get a "Show all" action.
- **`exercise`** blocks interleave with content blocks in the order given.

### 5.7 `Exercise`
Common fields:
```json
{
  "exercise_id": "ex_u2_l1_01",
  "type": "multiple_choice",
  "concept_ids": ["con_allah_one"],
  "prompt": [{ "type": "text", "text": "…" }],
  "time_limit_ms": null, "scoring": { "accuracy": true, "combo": true, "layer": null }, "framing": null,
  "payload": { "options": [ { "option_id": "opt_a", "spans": [{ "type": "text", "text": "…" }] }, { "option_id": "opt_b", "spans": [{ "type": "text", "text": "…" }] } ] }
}
```
`time_limit_ms` is `null` in lessons, tests, and card reviews; `20000` in quick reviews; `15000` in duel challenges; `10000` in group challenges. Type-specific `payload`, answer format, and evaluation extras are defined in §7.
- `scoring` (authored per exercise; separates **checker correctness** from what it counts toward):
  - `accuracy` (bool): included in lesson accuracy and `score` when graded (`correct` true/false).
  - `combo` (bool): participates in the local correct-answer combo flame.
  - `layer` (`understand` | `apply` | `remember` | `null`): which completion bar it feeds. Response keys are `understanding`, `applying`, `remembering`. In this revision `remembering` is always `null` (the prototype placeholder), so a `remember` exercise counts in accuracy but feeds no visible bar.
  - `recite_verse` always has `accuracy: false, combo: false, layer: null` (it is practice with its own checker result), matching the prototype's `ReciteView`.
- **What may be graded (curriculum amendment):** exercises test understanding, recognition and application of the lesson's approved outcome. They never score personal belief, agreement with a religious claim or conversion ("Does God exist? Yes ✅" is invalid; "Which statement best represents the reasoning explored in this lesson?" is valid). Each exercise has one wording per language that serves both tracks (stable identity, keys and mastery), so every exercise must be suitable for an Explorer. Personal reactions use the ungraded `predict` block. Factory QA blocks violations (`belief_grading`).
- `framing`: `null`, or `{ "kind": "myth", "statement": Span[] }` — misconception correction, rendered as in `choice_view.dart`: the **prompt first**, then the bordered "mistaken idea" card with the `statement`, then the options. Framing never changes grading.

### 5.8 `AnswerEvaluation` (feedback mode `immediate`)
```json
{
  "exercise_id": "ex_u2_l1_07",
  "recorded": true,
  "correct": false,
  "correct_answer": { "segment_id": "seg_2" },
  "details": null,
  "explanation": [
    { "type": "text", "text": "الكعبة قِبلة يتّجه إليها المسلمون لتوحيد الوجهة، والعبادة لله وحده." }
  ],
  "source_ids": ["src_q_2_144"],
  "misconception": {
    "misconception_id": "mis_kaaba_worship",
    "title": "المسلمون يعبدون الكعبة",
    "card": [
      { "type": "text", "text": "فكرة شائعة لكنها غير صحيحة: المسلمون يعبدون الله وحده، ويتّجهون إلى الكعبة في صلاتهم امتثالاً لأمره، لا عبادةً لها." }
    ],
    "source_ids": ["src_q_2_144"]
  },
  "mastery_changes": [
    { "concept_id": "con_qibla", "title": "القِبلة", "before": 0.4, "after": 0.3 }
  ],
  "term_changes": [],
  "xp_awarded": 0
}
```
- `correct` is `null` for a skipped recitation and for a `map_place` answered `{ "unavailable": true }`. **`correct: null` answers are excluded** from score denominators, accuracy, layer bars, perfect-lesson checks, mastery, FSRS, misconception updates, and retries; they still complete the step. The UI shows neutral feedback ("تم تخطيه" / "Skipped").
- Exercises with `scoring.accuracy = false` (e.g., recitation) are evaluated and shown normally but never enter accuracy, `score`, layers, perfect-lesson checks, or the combo.
- `misconception` is non-null only when the answer triggered a misconception → show the remediation card (distinct style) before continuing.
- `details` carries per-type extras (§7).
- `xp_awarded` is non-zero only for a passed `recite_verse` (3 XP); all other XP is granted at session finish. `SessionResult.xp.total` includes it.

For feedback modes `none` and `end`, the answer response is only:
```json
{ "exercise_id": "ex_u0_pre_03", "recorded": true }
```

### 5.9 `NextStep`
```json
{
  "type": "lesson",
  "reason": "next_lesson",
  "unit_id": "unit_0",
  "lesson_id": "les_u0_l2",
  "title": "هل يمكن أن يأتي شيء من لا شيء؟",
  "due_reviews_count": 3
}
```
For `type = review`, `lesson_id` is `null`. For `pretest` / `unit_test`, `lesson_id` is `null` and `unit_id` is set. For `journey_complete`, all ids are `null`.

---

## 6. REST endpoints

### 6.1 Auth and onboarding

**Tokens (rev 10 clarification):** `access_token` is an opaque bearer credential bound to a revocable server-side auth session. Guest tokens have no fixed expiry: they stay valid until `DELETE /me`, an operator revocation, or 180 days without any authenticated request. Reviewer tokens expire 12 h after login. Store tokens in platform secure storage (Keychain/Keystore via `flutter_secure_storage`). The web build keeps a guest token in browser storage, which is weaker; that limitation is accepted only if web is an approved release platform ([open decisions](../00_REVIEW/STATUS_AND_OPEN_DECISIONS.md)). Guest accounts have no recovery or account linking in this baseline, so losing the token loses that learner's progress (product decision P-02).

#### `POST /auth/guest`
Creates an anonymous learner. Store the token securely and reuse it. Rate-limited per client network address (§3.4 `429`).
Request:
```json
{ "timezone": "Asia/Riyadh" }
```
Response `201`:
```json
{
  "access_token": "eyJhbGciOi...guest",
  "user": {
    "user_id": "usr_7f3k2a",
    "display_name": "مسافر ٤٧",
    "role": "learner",
    "language": "ar",
    "track": "explorer",
    "daily_goal_minutes": 10,
    "timezone": "Asia/Riyadh",
    "onboarding_completed": false, "avatar_key": "traveler_03", "familiarity": "some", "private_profile": true, "goal_anchor": null,
    "created_at": "2026-10-04T09:00:00Z"
  }
}
```

#### `POST /auth/reviewer`
Request:
```json
{ "email": "reviewer@qabas.app", "password": "••••••••" }
```
Response `200`:
```json
{
  "access_token": "eyJhbGciOi...reviewer",
  "user": {
    "user_id": "usr_rev01",
    "display_name": "المراجع الشرعي",
    "role": "reviewer",
    "language": "ar",
    "track": "explorer",
    "daily_goal_minutes": 10,
    "timezone": "Asia/Riyadh",
    "onboarding_completed": true, "avatar_key": "traveler_03", "familiarity": "some", "private_profile": true, "goal_anchor": null,
    "created_at": "2026-10-01T08:00:00Z"
  }
}
```

#### `POST /onboarding`
Request:
```json
{
  "track_choice": "undisclosed",
  "language": "ar",
  "familiarity": "some",
  "daily_goal_minutes": 10,
  "private_profile": true,
  "goal_anchor": "who_was_muhammad"
}
```
Response `200`:
```json
{
  "user": {
    "user_id": "usr_7f3k2a",
    "display_name": "مسافر ٤٧",
    "role": "learner",
    "language": "ar",
    "track": "explorer",
    "daily_goal_minutes": 10,
    "timezone": "Asia/Riyadh",
    "onboarding_completed": true, "avatar_key": "traveler_03", "familiarity": "some", "private_profile": true, "goal_anchor": "who_was_muhammad",
    "created_at": "2026-10-04T09:00:00Z"
  },
  "start_unit_id": "unit_0",
  "next_step": {
    "type": "pretest",
    "reason": "new_unit_pretest",
    "unit_id": "unit_0",
    "lesson_id": null,
    "title": "اختبار قصير قبل البدء",
    "due_reviews_count": 0
  }
}
```
Mapping: `explorer` and `undisclosed` → `track=explorer`, start `unit_0` (Unit 0 "Start With a Question", Explorer-only). `new_muslim` → start `unit_1`; Unit 0 is not part of the New Muslim track. The learner-type question asks only whether the learner is exploring Islam or has already accepted it ("prefer not to say" = `undisclosed` → Explorer); onboarding never asks for, stores or infers the learner's religion or worldview. `goal_anchor` is the answer to "What would you most like to understand?" (a `goal_anchors` registry key, or `null` if skipped; unknown key → `400 validation_error`). It never changes `start_unit_id`, curriculum order or `next_step`: entry point ≠ curriculum order. The client shows the reviewed onboarding bridge for (`goal_anchor`, track, language) from bundled copy; bridges are onboarding content, not lessons, and are never generated by the lesson factory. `familiarity` (nullable) and `private_profile` are stored; `daily_goal_minutes` ∈ 5/10/15/20. Pages 2 (welcome), 7's "discreet reminders", and 8 (ready) send nothing.

### 6.2 Profile and stats

#### `GET /me` → `User`

#### `PATCH /me`
Body `MePatch`: any non-empty subset of `display_name` (2–24 chars), `language`, `track`, `daily_goal_minutes` (5/10/15/20), `timezone` (IANA name), `avatar_key`, `private_profile`, `goal_anchor`. Send only fields that change; none may be `null`. Response: `User`.
```json
{ "language": "en", "daily_goal_minutes": 15 }
```
Local-only preferences (persisted on device, never sent): sound, haptics, reduced motion (defaults to the OS setting), discreet reminders.
Changing `track` keeps all progress; the journey `current` pointer and `next_step` are recomputed (re-fetch S3). The track changes only when the learner explicitly chooses it (for example an Explorer who becomes Muslim switches to `new_muslim`); it is never inferred from behavior. Completed lessons stay completed because lesson IDs do not depend on the track. Explorer → New Muslim removes Unit 0 from the journey (its completions are retained and reappear if the learner switches back); shared Units 1–10 then serve the New Muslim variant. Changing `language` or `track` never alters an active session's stored snapshot. Changing `timezone` applies from the next event: stored `local_date`s are never rewritten, and the streak is evaluated in the new zone from then on.

#### `DELETE /me` → `204`
Deletes the account. In one transaction the server revokes every auth session of the user, marks the user deleted and removes them from friend lists, pending invitations and current leagues. A durable purge job then deletes, within 30 days: profile fields, learning state, sessions/answers, recitation checks, Raqeeb conversations/messages/attachments (including object storage) and any semantic-memory rows derived from the user's questions. Records other users still need (finished challenge results, league history) keep only an anonymous placeholder ("Deleted learner"/"متعلم محذوف", default avatar). The client clears the token and local state and returns to S1. Repeating the call with the old token returns `401`. Reviewer accounts are deactivated by an operator, not through this endpoint (`403`).

#### `GET /me/stats`
```json
{
  "xp_total": 340,
  "xp_this_week": 120,
  "streak": { "current": 3, "longest": 5, "today_completed": true },
  "daily_goal": { "minutes": 10, "minutes_today": 12, "met": true },
  "league": { "league_id": "lg_2026w40_07", "rank": 4, "size": 20 },
  "concepts": { "mastered": 9, "learning": 6 },
  "terms": { "mastered": 14, "seen": 22 },
  "misconceptions": { "resolved": 2, "active": 1 },
  "lessons_completed": 7,
  "units_completed": 1
}
```
`league` is `null` until the learner's first XP of the current league week assigns a league (backend §10.3).

#### `GET /me/activity?from=2026-09-27&to=2026-10-10`
Qualifying days for the streak calendar, in the learner's `timezone` (range ≤ 62 days; defaults to the last 35 days).
```json
{
  "timezone": "Asia/Riyadh",
  "from": "2026-09-27",
  "to": "2026-10-10",
  "streak": { "current": 3, "longest": 5, "today_completed": true },
  "days": [
    { "date": "2026-10-02", "qualifying": true, "minutes": 9, "xp": 25 },
    { "date": "2026-10-03", "qualifying": true, "minutes": 14, "xp": 40 },
    { "date": "2026-10-04", "qualifying": true, "minutes": 12, "xp": 35 }
  ]
}
```
Days not listed are non-qualifying. The calendar and week views (`streak_screen.dart`) render from this.

#### `GET /me/quests`
Today's three daily quests (rotate at local midnight).
```json
{
  "date": "2026-10-04",
  "resets_in_seconds": 41200,
  "items": [
    { "quest_id": "q_20261004_1", "kind": "earn_xp", "title": "اجمع 30 جمرة", "progress": 25, "goal": 30, "reward_xp": 10, "completed": false },
    { "quest_id": "q_20261004_2", "kind": "complete_lessons", "title": "أكمل درسين", "progress": 2, "goal": 2, "reward_xp": 10, "completed": true },
    { "quest_id": "q_20261004_3", "kind": "perfect_lesson", "title": "أنهِ درساً دون أخطاء", "progress": 0, "goal": 1, "reward_xp": 15, "completed": false }
  ]
}
```
Rewards are granted automatically by the server when `progress` reaches `goal` (they appear in `xp_events` and in the next `SessionResult.xp.breakdown` as `quest_complete`).

#### `GET /me/achievements`
```json
{
  "items": [
    { "achievement_key": "first_lesson", "title": "الخطوة الأولى", "description": "أكمل أول درس", "unlocked": true, "unlocked_at": "2026-10-04T09:30:00Z", "progress": { "current": 1, "target": 1 } },
    { "achievement_key": "seeker", "title": "الباحث", "description": "اسأل رقيب 5 أسئلة", "unlocked": false, "unlocked_at": null, "progress": { "current": 3, "target": 5 } }
  ]
}
```
Badge artwork is bundled in Flutter by `achievement_key` (unknown key → generic badge). The set is the prototype's eight badges; their keys are the Dart enum names in `achievements.dart`, frozen in `contract/registries.json` (example keys here are illustrative). The "Ask Raqeeb 5 questions" badge counts completed Raqeeb answers (backend §10.7). Adding an achievement is a contract update.

#### `GET /me/concepts`
```json
{
  "items": [
    { "concept_id": "con_allah_one", "title": "وحدانية الله", "unit_id": "unit_2", "mastery": 0.86, "next_review_at": "2026-10-07T09:00:00Z" },
    { "concept_id": "con_qibla", "title": "القِبلة", "unit_id": "unit_3", "mastery": 0.32, "next_review_at": "2026-10-05T09:00:00Z" }
  ],
  "next_cursor": null
}
```

### 6.3 Journey

The journey is the **Roadmap** ("What should I learn next?"): the recommended, ordered path of the learner's track. **Discover** ("What can I explore now?") is a second view over the same response: the lessons with `standalone_eligible = true`. Both open the same canonical published lesson through the same `POST /sessions` call; there is no Discover-specific lesson, version, wording or request field (curriculum rules: [curriculum and learning design](../01_PRODUCT/CURRICULUM_AND_LEARNING_DESIGN.md)).

#### `GET /journey`
Example for an Explorer who finished lesson 0.1 (abbreviated: Unit 0 has 12 lessons and Units 3–6, 8 and 9 are omitted; real responses list every unit of the track and every published lesson):
```json
{
  "track": "explorer",
  "current": { "unit_id": "unit_0", "lesson_id": "les_u0_l2" },
  "units": [
    {
      "unit_id": "unit_0",
      "index": 0,
      "title": "ابدأ بسؤال",
      "subtitle": "أسس قبل الأسئلة الكبرى",
      "art_key": "unit_big_questions",
      "has_guide": true,
      "state": "in_progress",
      "coming_soon": false,
      "pretest": { "state": "taken" },
      "unit_test": { "state": "not_passed", "best_percent": null, "pass_percent": 80, "can_skip": true },
      "lessons": [
        { "lesson_id": "les_u0_l1", "index": 0, "title": "هل يجب أن ترى الشيء لتعرفه؟", "lesson_type": "concept", "state": "completed", "estimated_minutes": 5, "xp": 15, "standalone_eligible": true, "soft_lock": null },
        { "lesson_id": "les_u0_l2", "index": 1, "title": "هل يمكن أن يأتي شيء من لا شيء؟", "lesson_type": "concept", "state": "available", "estimated_minutes": 5, "xp": 15, "standalone_eligible": false, "soft_lock": null },
        { "lesson_id": "les_u0_l3", "index": 2, "title": "هل يمكن لشيء أن يخلق نفسه؟", "lesson_type": "concept", "state": "locked", "estimated_minutes": 5, "xp": 15, "standalone_eligible": false,
          "soft_lock": { "prerequisites": [ { "lesson_id": "les_u0_l2", "unit_id": "unit_0", "title": "هل يمكن أن يأتي شيء من لا شيء؟" } ], "start_with": { "lesson_id": "les_u0_l2", "unit_id": "unit_0", "title": "هل يمكن أن يأتي شيء من لا شيء؟" } } },
        { "lesson_id": "les_u0_l4", "index": 3, "title": "كيف سيكون الخالق؟", "lesson_type": "concept", "state": "locked", "estimated_minutes": 6, "xp": 15, "standalone_eligible": false,
          "soft_lock": { "prerequisites": [ { "lesson_id": "les_u0_l3", "unit_id": "unit_0", "title": "هل يمكن لشيء أن يخلق نفسه؟" } ], "start_with": { "lesson_id": "les_u0_l2", "unit_id": "unit_0", "title": "هل يمكن أن يأتي شيء من لا شيء؟" } } }
      ]
    },
    {
      "unit_id": "unit_1",
      "index": 1,
      "title": "الخطوة الأولى",
      "subtitle": "فهم الخطوة الأولى في الإسلام",
      "art_key": "unit_first_steps",
      "has_guide": true,
      "state": "available",
      "coming_soon": false,
      "pretest": { "state": "not_taken" },
      "unit_test": { "state": "not_passed", "best_percent": null, "pass_percent": 80, "can_skip": true },
      "lessons": [
        { "lesson_id": "les_u1_l1", "index": 0, "title": "ما معنى الإسلام؟", "lesson_type": "concept", "state": "available", "estimated_minutes": 5, "xp": 15, "standalone_eligible": true, "soft_lock": null },
        { "lesson_id": "les_u1_l2", "index": 1, "title": "ما معنى العبادة حقاً؟", "lesson_type": "concept", "state": "locked", "estimated_minutes": 5, "xp": 15, "standalone_eligible": false,
          "soft_lock": { "prerequisites": [ { "lesson_id": "les_u1_l1", "unit_id": "unit_1", "title": "ما معنى الإسلام؟" } ], "start_with": { "lesson_id": "les_u1_l1", "unit_id": "unit_1", "title": "ما معنى الإسلام؟" } } },
        { "lesson_id": "les_u1_l3", "index": 2, "title": "لا إله إلا الله", "lesson_type": "concept", "state": "locked", "estimated_minutes": 6, "xp": 15, "standalone_eligible": false,
          "soft_lock": { "prerequisites": [ { "lesson_id": "les_u1_l2", "unit_id": "unit_1", "title": "ما معنى العبادة حقاً؟" } ], "start_with": { "lesson_id": "les_u1_l1", "unit_id": "unit_1", "title": "ما معنى الإسلام؟" } } }
      ]
    },
    {
      "unit_id": "unit_2",
      "index": 2,
      "title": "معرفة الله",
      "subtitle": "من هو الله في الإسلام؟",
      "art_key": null,
      "has_guide": true,
      "state": "available",
      "coming_soon": false,
      "pretest": { "state": "not_taken" },
      "unit_test": { "state": "not_passed", "best_percent": null, "pass_percent": 80, "can_skip": true },
      "lessons": [
        { "lesson_id": "les_u2_l1", "index": 0, "title": "من هو الله؟", "lesson_type": "concept", "state": "available", "estimated_minutes": 5, "xp": 15, "standalone_eligible": true, "soft_lock": null },
        { "lesson_id": "les_u2_l2", "index": 1, "title": "واحدٌ لا مثيل له", "lesson_type": "concept", "state": "locked", "estimated_minutes": 5, "xp": 15, "standalone_eligible": false,
          "soft_lock": { "prerequisites": [ { "lesson_id": "les_u2_l1", "unit_id": "unit_2", "title": "من هو الله؟" } ], "start_with": { "lesson_id": "les_u2_l1", "unit_id": "unit_2", "title": "من هو الله؟" } } }
      ]
    },
    {
      "unit_id": "unit_7",
      "index": 7,
      "title": "رسالة واحدة وأنبياء كثيرون",
      "subtitle": "قصص الأنبياء",
      "art_key": null,
      "has_guide": true,
      "state": "available",
      "coming_soon": false,
      "pretest": { "state": "not_taken" },
      "unit_test": { "state": "not_passed", "best_percent": null, "pass_percent": 80, "can_skip": true },
      "lessons": [
        { "lesson_id": "les_u7_l1", "index": 0, "title": "لماذا الأنبياء؟", "lesson_type": "concept", "state": "available", "estimated_minutes": 5, "xp": 15, "standalone_eligible": true, "soft_lock": null },
        { "lesson_id": "les_u7_l4", "index": 3, "title": "إبراهيم يبحث عن ربه", "lesson_type": "story", "state": "locked", "estimated_minutes": 6, "xp": 15, "standalone_eligible": false,
          "soft_lock": { "prerequisites": [ { "lesson_id": "les_u2_l1", "unit_id": "unit_2", "title": "من هو الله؟" } ], "start_with": { "lesson_id": "les_u2_l1", "unit_id": "unit_2", "title": "من هو الله؟" } } }
      ]
    },
    {
      "unit_id": "unit_10",
      "index": 10,
      "title": "ما بعد الأساسيات",
      "subtitle": "قريباً",
      "art_key": null,
      "has_guide": false,
      "state": "locked",
      "coming_soon": true,
      "pretest": { "state": "not_taken" },
      "unit_test": { "state": "not_passed", "best_percent": null, "pass_percent": 80, "can_skip": false },
      "lessons": []
    }
  ]
}
```
- **Track membership.** The response contains only the units of the learner's track: Explorer sees Unit 0 (Explorer-only) and Units 1–10; New Muslim sees Units 1–10. Unit `title`/`subtitle`/guide are served in the learner's track framing (Unit 1 above uses the Explorer framing; a New Muslim sees "خطواتك الأولى مع الله"). Lesson IDs, completion and progress are the same for both tracks.
- **Position is not a prerequisite.** `index` is the curriculum position (recommended order). A lesson's access depends only on its approved mandatory prerequisites (backend §6.1). `state`:
  - `completed`: a lesson session for this canonical lesson was finished, whether it was opened from the Roadmap or from Discover, in either track.
  - `in_progress`: an active session exists.
  - `locked`: at least one mandatory prerequisite is unmet. `soft_lock` is then non-null: `prerequisites` lists the lessons that introduce the unmet concepts (curriculum order) and `start_with` is the earliest lesson on that dependency path the learner can open now. The client shows the Soft Lock explanation, never an unexplained lock or a skip action (frontend S3).
  - `available`: otherwise, including lessons later in the curriculum that have no unmet prerequisite (e.g., `les_u7_l1`, `les_u2_l1` above).
- `soft_lock` is non-null exactly when `state = locked`; it always names lessons present in the same response, and `start_with` is never locked (model-enforced).
- `standalone_eligible` (approved at Gate 1) marks a lesson that can be understood without mandatory prerequisites. It is listed in Discover. Such a lesson is never locked. A lesson without prerequisites is not automatically standalone-eligible: eligibility is an explicit, reviewed decision. (`les_u0_l2` above is available because its prerequisite, 0.1, is completed; it is not standalone-eligible because it has that prerequisite.) Story lessons are not standalone merely because they are stories (`les_u7_l4` depends on `les_u2_l1`).
- **Unit `state`:** `completed` (all lessons completed and unit test passed), `skipped` (unit test passed before all lessons were completed; treated as completed, and its introduced concepts count as satisfied prerequisites), `in_progress` (any session started), `available` (at least one lesson can be opened), `locked` (`coming_soon`, or every lesson soft-locked). A unit never waits for the previous unit to finish. `unit_test.state`: `not_passed` | `passed`. `can_skip=true` means the "Skip unit" placement test is allowed (unit not completed/skipped and not coming soon); it demonstrates understanding through a unit test and is not a lesson skip.
- A lesson is tappable if `state != locked`; a locked lesson is tappable to show its Soft Lock.
- The reference Salah lesson (fixture ID `les_u1_l3`, frozen in the received export) is the gold candidate for curriculum lesson 3.2 "Five Times a Day" in Unit 3 (§6.5.4).

`art_key` selects bundled unit artwork in Flutter (unknown or `null` → default art); artwork is never downloaded. Node popovers and checkpoint nodes follow the prototype journey widgets.

#### `GET /units/{unit_id}/guide`
Guidebook content for the unit sheet (when `has_guide = true`), in the learner's language and track framing.
```json
{
  "unit_id": "unit_1",
  "title": "دليل الوحدة: الخطوة الأولى",
  "sections": [
    {
      "title": "ستتعلم في هذه الوحدة",
      "sentences": [
        { "sentence_id": "sen_g_u1_1", "spans": [{ "type": "text", "text": "معنى كلمة الإسلام، ومعنى العبادة، والشهادتين، وما يتغير حين يصبح الإنسان مسلماً." }], "source_ids": [] }
      ]
    }
  ],
  "sources": [],
  "terms": {}
}
```

#### `GET /journey/next` → `NextStep` (§5.9)

### 6.4 Lessons (read-only)

#### `GET /lessons/{lesson_id}`
Returns the lesson for re-reading (S6): the **reader projection** — the same content blocks as the session, with `exercise` blocks (and their answer data) omitted and `predict` blocks shown with their reveal. Compare it with a session only after applying this projection. Includes `objectives` (list of `Span[]`, shown on the intro screen) and `completion` (`{ challenge: Span[] | null, review_topics: [{ topic_id, title, concept_ids }], check_in: Span[] | null }`, shown on the completion screen). End-of-lesson summaries are ordinary `teach` blocks with `style: summary`.
```json
{
  "lesson_id": "les_u2_l1",
  "unit_id": "unit_2",
  "title": "من هو الله؟",
  "subtitle": "معرفة الله",
  "lesson_type": "concept",
  "reviewed_by": "لجنة المراجعة الشرعية",
  "version": 3,
  "source_count": 1,
  "objectives": [
    [
      {
        "type": "text",
        "text": "أن تشرح معنى أن الله واحد لا شريك له."
      }
    ],
    [
      {
        "type": "text",
        "text": "أن تتعرف على سورة الإخلاص ومعناها العام."
      }
    ]
  ],
  "blocks": [
    {
      "block_id": "blk_u2_l1_p1",
      "type": "paragraph",
      "sentences": [
        {
          "sentence_id": "sen_u2_l1_01",
          "spans": [
            {
              "type": "text",
              "text": "في الإسلام، الله هو "
            },
            {
              "type": "term",
              "text": "الخالق",
              "term_id": "term_khaliq"
            },
            {
              "type": "text",
              "text": " لكل شيء، وهو واحد لا شريك له."
            }
          ],
          "source_ids": [
            "src_q_112_1_4"
          ]
        }
      ]
    }
  ],
  "completion": {
    "challenge": [
      {
        "type": "text",
        "text": "اقرأ سورة الإخلاص مع معناها، وتأمل كل صفة من صفات الله فيها."
      }
    ],
    "review_topics": [
      {
        "topic_id": "rt_u2_l1_1",
        "title": "وحدانية الله",
        "concept_ids": [
          "con_allah_one"
        ]
      },
      {
        "topic_id": "rt_u2_l1_2",
        "title": "سورة الإخلاص",
        "concept_ids": [
          "con_allah_one"
        ]
      }
    ],
    "check_in": [
      {
        "type": "text",
        "text": "غداً سنسألك: ماذا تعني كلمة «أحد»؟"
      }
    ]
  },
  "sources": [
    {
      "source_id": "src_q_112_1_4",
      "kind": "quran",
      "provider": "quran_com",
      "title": "سورة الإخلاص",
      "reference": "الإخلاص: 1–4",
      "excerpt": "قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ",
      "url": "https://quran.com/112",
      "displayed": true,
      "display_role": "content"
    }
  ],
  "terms": {
    "term_khaliq": {
      "term_id": "term_khaliq",
      "text": "الخالق",
      "transliteration": "Al-Khaliq",
      "state": "learning",
      "level": "basic",
      "definition": [
        {
          "type": "text",
          "text": "الذي أوجد كل شيء من العدم."
        }
      ],
      "example": [
        {
          "type": "text",
          "text": "السماء والأرض من خلق الله."
        }
      ],
      "pronunciation_audio_url": "https://cdn.example.com/terms/term_khaliq.mp3",
      "source_id": null,
      "lesson_id": "les_u2_l1",
      "lesson_title": "من هو الله؟",
      "arabic": null
    }
  }
}
```
`reviewed_by` is shown as a small "راجعه مختص" badge.

### 6.5 Sessions (lessons, reviews, pretests, unit tests)

A **session** is the unit of play. Every lesson attempt, review, pretest, and unit test is a session. The client renders `items` in order.

#### `POST /sessions`
Request (one of):
```json
{ "kind": "lesson", "lesson_id": "les_u2_l1" }
```
```json
{ "kind": "review", "mode": "cards" }
```
(`mode`: `cards` = untimed self-rated flashcard deck, the default review screen S21; `quick` = timed mixed review. `mode` is required for `review` and must be absent/`null` for other kinds; `Session.mode` echoes it.)
```json
{ "kind": "pretest", "unit_id": "unit_0" }
```
```json
{ "kind": "unit_test", "unit_id": "unit_0" }
```
A `unit_test` on a unit that isn't completed is a **skip attempt**; passing marks the unit `skipped` (treated as completed).

**Lesson access (curriculum amendment):** the lesson must be published in a unit of the learner's track (otherwise `404 not_found`) and have no unmet mandatory prerequisite (otherwise `409 prerequisite_unmet` with `details.prerequisite_lesson_ids` and `details.start_with_lesson_id`, the same data as the journey `soft_lock`). An already active session for the lesson is returned regardless. The request is identical whether the learner came from the Roadmap or from Discover; the server neither receives nor stores the entry surface, and the served lesson version, wording, exercises and completion are identical. Completing it completes the canonical lesson everywhere. The variant is the learner's track; a missing New Muslim variant falls back to the Explorer variant, never the reverse (backend §6.2).

At most one `active` session exists per (user, kind, lesson or unit, review mode). Creating one that already exists returns the existing session with `200` (same body, including its pinned language, version and history) instead of creating a duplicate; this also makes `POST /sessions` safe to retry. A new session is `201`. Sessions stay `active` until finished or abandoned; content published later never changes them.

Response `201` — `Session` (lesson example):
```json
{
  "session_id": "ses_91ab",
  "kind": "lesson",
  "status": "active",
  "feedback_mode": "immediate",
  "mode": null,
  "unit_id": "unit_2",
  "lesson_id": "les_u2_l1",
  "lesson_version": 3,
  "title": "من هو الله؟",
  "subtitle": "معرفة الله",
  "lesson_type": "concept",
  "reviewed_by": "لجنة المراجعة الشرعية",
  "objectives": [
    [
      {
        "type": "text",
        "text": "أن تشرح معنى أن الله واحد لا شريك له."
      }
    ],
    [
      {
        "type": "text",
        "text": "أن تتعرف على سورة الإخلاص ومعناها العام."
      }
    ]
  ],
  "counts": {
    "interactions": 3,
    "exercises": 3,
    "scored": 2
  },
  "source_count": 1,
  "total_exercises": 3,
  "answered_exercises": 0,
  "answers": [],
  "started_at": "2026-10-04T09:20:00Z",
  "items": [
    {
      "block_id": "blk_u2_l1_p1",
      "type": "paragraph",
      "sentences": [
        {
          "sentence_id": "sen_u2_l1_01",
          "spans": [
            {
              "type": "text",
              "text": "في الإسلام، الله هو "
            },
            {
              "type": "term",
              "text": "الخالق",
              "term_id": "term_khaliq"
            },
            {
              "type": "text",
              "text": " لكل شيء، وهو واحد لا شريك له."
            }
          ],
          "source_ids": [
            "src_q_112_1_4"
          ]
        },
        {
          "sentence_id": "sen_u2_l1_02",
          "spans": [
            {
              "type": "text",
              "text": "هذا الإيمان بوحدانية الله يسمّى "
            },
            {
              "type": "term",
              "text": "التوحيد",
              "term_id": "term_tawhid"
            },
            {
              "type": "text",
              "text": "، وهو أساس الإسلام كله."
            }
          ],
          "source_ids": [
            "src_q_112_1_4",
            "src_tafsir_112_mukhtasar"
          ]
        }
      ]
    },
    {
      "block_id": "blk_u2_l1_e1",
      "type": "evidence",
      "caption": [
        {
          "type": "text",
          "text": "سورة قصيرة تصف الله في أربع آيات:"
        }
      ],
      "evidence": {
        "evidence_id": "src_q_112_1_4",
        "kind": "quran",
        "quran": {
          "surah": 112,
          "surah_name": "الإخلاص",
          "ayah_start": 1,
          "ayah_end": 4,
          "segment": null,
          "text_uthmani": "قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ",
          "translation": null,
          "translation_source": null,
          "audio": {
            "reciter": "مشاري راشد العفاسي",
            "url": "https://cdn.example.com/quran/afasy/112001-112004.mp3",
            "words": null
          }
        },
        "hadith": null
      }
    },
    {
      "block_id": "blk_u2_l1_x1",
      "type": "exercise",
      "exercise": {
        "exercise_id": "ex_u2_l1_01",
        "type": "multiple_choice",
        "concept_ids": [
          "con_allah_one"
        ],
        "prompt": [
          {
            "type": "text",
            "text": "ماذا تعني كلمة «أحد» في سورة الإخلاص؟"
          }
        ],
        "time_limit_ms": null,
        "scoring": {
          "accuracy": true,
          "combo": true,
          "layer": "understand"
        },
        "framing": null,
        "payload": {
          "options": [
            {
              "option_id": "opt_a",
              "spans": [
                {
                  "type": "text",
                  "text": "أن الله واحد لا شريك له"
                }
              ]
            },
            {
              "option_id": "opt_b",
              "spans": [
                {
                  "type": "text",
                  "text": "أن الله أول الآلهة"
                }
              ]
            },
            {
              "option_id": "opt_c",
              "spans": [
                {
                  "type": "text",
                  "text": "أن الله خاص بالعرب"
                }
              ]
            }
          ]
        }
      }
    },
    {
      "block_id": "blk_u2_l1_x2",
      "type": "exercise",
      "exercise": {
        "exercise_id": "ex_u2_l1_07",
        "type": "spot_error",
        "concept_ids": [
          "con_qibla"
        ],
        "prompt": [
          {
            "type": "text",
            "text": "في العبارة التالية جزء خاطئ. اضغط عليه."
          }
        ],
        "time_limit_ms": null,
        "scoring": {
          "accuracy": true,
          "combo": true,
          "layer": "understand"
        },
        "framing": null,
        "payload": {
          "segments": [
            {
              "segment_id": "seg_1",
              "spans": [
                {
                  "type": "text",
                  "text": "يتّجه المسلمون في صلاتهم إلى الكعبة"
                }
              ]
            },
            {
              "segment_id": "seg_2",
              "spans": [
                {
                  "type": "text",
                  "text": "لأنهم يعبدونها"
                }
              ]
            },
            {
              "segment_id": "seg_3",
              "spans": [
                {
                  "type": "text",
                  "text": "وهي قِبلة واحدة لكل المسلمين."
                }
              ]
            }
          ]
        }
      }
    },
    {
      "block_id": "blk_u2_l1_x3",
      "type": "exercise",
      "exercise": {
        "exercise_id": "ex_u2_l1_09",
        "type": "recite_verse",
        "concept_ids": [
          "con_allah_one"
        ],
        "prompt": [
          {
            "type": "text",
            "text": "استمع إلى الآية ثم اقرأها بصوتك."
          }
        ],
        "time_limit_ms": null,
        "scoring": {
          "accuracy": false,
          "combo": false,
          "layer": null
        },
        "framing": null,
        "payload": {
          "surah": 112,
          "ayah": 1,
          "word_start": null,
          "word_end": null,
          "text_uthmani": "قُلْ هُوَ اللَّهُ أَحَدٌ",
          "audio": {
            "reciter": "مشاري راشد العفاسي",
            "url": "https://cdn.example.com/quran/afasy/112001.mp3",
            "words": [
              {
                "ayah": 1,
                "position": 1,
                "text": "قُلْ",
                "start_ms": 0,
                "end_ms": 520
              },
              {
                "ayah": 1,
                "position": 2,
                "text": "هُوَ",
                "start_ms": 520,
                "end_ms": 900
              },
              {
                "ayah": 1,
                "position": 3,
                "text": "اللَّهُ",
                "start_ms": 900,
                "end_ms": 1650
              },
              {
                "ayah": 1,
                "position": 4,
                "text": "أَحَدٌ",
                "start_ms": 1650,
                "end_ms": 2900
              }
            ]
          },
          "transliteration": "Qul huwa Allahu ahad",
          "meaning": [
            {
              "type": "text",
              "text": "قل: هو الله الواحد لا شريك له."
            }
          ],
          "source_id": "src_q_112_1_4",
          "max_duration_ms": 30000,
          "skippable": true
        }
      }
    }
  ],
  "completion": {
    "challenge": [
      {
        "type": "text",
        "text": "اقرأ سورة الإخلاص مع معناها، وتأمل كل صفة من صفات الله فيها."
      }
    ],
    "review_topics": [
      {
        "topic_id": "rt_u2_l1_1",
        "title": "وحدانية الله",
        "concept_ids": [
          "con_allah_one"
        ]
      },
      {
        "topic_id": "rt_u2_l1_2",
        "title": "سورة الإخلاص",
        "concept_ids": [
          "con_allah_one"
        ]
      }
    ],
    "check_in": [
      {
        "type": "text",
        "text": "غداً سنسألك: ماذا تعني كلمة «أحد»؟"
      }
    ]
  },
  "sources": [
    {
      "source_id": "src_q_112_1_4",
      "kind": "quran",
      "provider": "quran_com",
      "title": "سورة الإخلاص",
      "reference": "الإخلاص: 1–4",
      "excerpt": "قُلْ هُوَ اللَّهُ أَحَدٌ ۝ اللَّهُ الصَّمَدُ ۝ لَمْ يَلِدْ وَلَمْ يُولَدْ ۝ وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ",
      "url": "https://quran.com/112",
      "displayed": true,
      "display_role": "content"
    },
    {
      "source_id": "src_tafsir_112_mukhtasar",
      "kind": "tafsir",
      "provider": "tafsir_center",
      "title": "المختصر في التفسير",
      "reference": "تفسير سورة الإخلاص",
      "excerpt": "قل -أيها الرسول-: هو الله المتفرد بالألوهية...",
      "url": null,
      "displayed": false,
      "display_role": null
    },
    {
      "source_id": "src_q_2_144",
      "kind": "quran",
      "provider": "quran_com",
      "title": "سورة البقرة",
      "reference": "البقرة: 144",
      "excerpt": "فَوَلِّ وَجْهَكَ شَطْرَ الْمَسْجِدِ الْحَرَامِ",
      "url": "https://quran.com/2/144",
      "displayed": false,
      "display_role": null
    }
  ],
  "terms": {
    "term_khaliq": {
      "term_id": "term_khaliq",
      "text": "الخالق",
      "transliteration": "Al-Khaliq",
      "state": "learning",
      "level": "basic",
      "definition": [
        {
          "type": "text",
          "text": "الذي أوجد كل شيء من العدم."
        }
      ],
      "example": [
        {
          "type": "text",
          "text": "السماء والأرض من خلق الله."
        }
      ],
      "pronunciation_audio_url": "https://cdn.example.com/terms/term_khaliq.mp3",
      "source_id": null,
      "lesson_id": "les_u2_l1",
      "lesson_title": "من هو الله؟",
      "arabic": null
    },
    "term_tawhid": {
      "term_id": "term_tawhid",
      "text": "التوحيد",
      "transliteration": "Tawhid",
      "state": "new",
      "level": "basic",
      "definition": [
        {
          "type": "text",
          "text": "الإيمان بأن الله واحد لا شريك له، وأنه وحده من يستحق العبادة."
        }
      ],
      "example": [
        {
          "type": "text",
          "text": "سورة الإخلاص تلخّص معنى التوحيد في أربع آيات قصيرة."
        }
      ],
      "pronunciation_audio_url": "https://cdn.example.com/terms/term_tawhid.mp3",
      "source_id": "src_q_112_1_4",
      "lesson_id": "les_u2_l1",
      "lesson_title": "من هو الله؟",
      "arabic": null
    }
  }
}
```

**Story lessons** use a `story` block (one block containing all beats), followed by exercises. Example with a downloaded illustration, a medallion overlay, provenance tags, and a quote with its gloss (one beat shown; real stories have several):
```json
{
  "block_id": "blk_u7_l4_story",
  "type": "story",
  "label": "قصة",
  "title": "إبراهيم يبحث عن ربه",
  "provenance": {
    "source_id": "src_q_6_74_79",
    "provider": "quran_com",
    "reference": "الأنعام: 74–79",
    "grade_label": null
  },
  "beats": [
    {
      "beat_id": "beat_u7_l4_0",
      "beat_index": 0,
      "narration": [
        {
          "sentence_id": "sen_u7_l4_01",
          "spans": [
            {
              "type": "text",
              "text": "نشأ إبراهيم عليه السلام في قوم يعبدون الكواكب والأصنام، فأراد أن يبيّن لهم أنها لا تستحق العبادة."
            }
          ],
          "source_ids": ["src_q_6_74_79"]
        }
      ],
      "narration_audio_url": null,
      "quote": {
        "evidence_id": "src_q_6_76",
        "kind": "quran",
        "quran": {
          "surah": 6,
          "surah_name": "الأنعام",
          "ayah_start": 76,
          "ayah_end": 76,
          "segment": null,
          "text_uthmani": "فَلَمَّا جَنَّ عَلَيْهِ اللَّيْلُ رَأَىٰ كَوْكَبًا ۖ قَالَ هَٰذَا رَبِّي ۖ فَلَمَّا أَفَلَ قَالَ لَا أُحِبُّ الْآفِلِينَ",
          "translation": null,
          "translation_source": null,
          "audio": null
        },
        "hadith": null
      },
      "quote_meaning": [
        {"type": "text", "text": "لما أظلم الليل رأى كوكباً، فلما غاب بيّن أن ما يغيب لا يصلح أن يكون رباً."}
      ],
      "visual": {
        "kind": "image",
        "key": null,
        "version": null,
        "params": null,
        "image": {
          "url": "https://cdn.example.com/scenes/u7_l4_s1_night_sky.webp",
          "mime_type": "image/webp",
          "width": 1600,
          "height": 1000
        },
        "scene": null,
        "fallback_image": null, "fallback_params": null,
        "alt": "سماء ليل صافية فيها كوكب لامع فوق صحراء",
        "overlays": [
          {
            "type": "medallion",
            "asset_url": "https://cdn.example.com/medallions/ibrahim.svg",
            "label": "إبراهيم عليه السلام",
            "anchor": "top_start",
            "size_pct": 22
          }
        ]
      }
    }
  ],
  "origin": {
    "title": "من أين جاءت هذه القصة؟",
    "source_ids": ["src_q_6_74_79", "src_tafsir_6_76_mukhtasar"],
    "show_card": true
  }
}
```

#### 6.5.1 Lesson flow and progress
1. **Intro** (lesson sessions only, `lesson_intro_screen.dart`): `title`, `subtitle`, unit index/title and lesson index (from `GET /journey`), `estimated_minutes` and reward `xp` (journey lesson entry), **interactions** = `counts.interactions` (exercise + `predict` blocks), `objectives`, and **sources** = `source_count`, plus the `reviewed_by` badge. `counts.exercises` (= `total_exercises`) and `counts.scored` (exercises with `scoring.accuracy`) are separate numbers — never reuse one for another. (Salah reference: 8 interactions, 7 exercises, 6 scored, 4 sources.)
2. **Steps** = the top-level `items` in order (`hook`, `predict`, `story`, `teach`, `paragraph`, `evidence`, `visual`, `callout`, `exercise`). A `story` (all its beats) and a `teach` card (all its reveals) are **one step each**.
3. **Retry round** for incorrectly answered graded exercises (rule below).
4. `POST /sessions/{id}/finish` → completion screen (S5), which shows `completion.challenge`, `review_topics`, and `check_in`. There is no separate challenge page before finishing.

**Lesson progress bar** (as `LessonSession.progress` in `qabas/lib/features/lesson/lesson_session.dart`): completed top-level steps ÷ number of top-level steps. A content step completes on Continue; an exercise or `predict` step completes **when its feedback panel is shown** (as the prototype advances the bar at feedback). Retries don't move the bar. **Recitation exception (reference):** `recite_verse` completes on **Continue** — its inline coach/checker result does not go through the ordinary feedback panel (`recite_view.dart` doesn't call `LessonSession.submit`). Production keeps that timing; its genuine checker result is shown inline (listed in Appendix A product differences). Progress is derived locally from the ordered items — no backend progress updates. `review`, `pretest`, and `unit_test` sessions use answered ÷ total exercises.

For `review`, `pretest`, and `unit_test` sessions, `objectives` is `[]`, `completion` is `null`, and items contain only `exercise` blocks.

#### 6.5.2 Grouping rules
Hook, prediction, story beats, and teaching points are grouped by their block structure (§5.6), never by ids or wording. A `story` block is played as one unit; a `teach` block owns its reveal state; `predict` and `exercise` blocks stand alone between content blocks. Lessons may use any combination, order, and count of blocks allowed by the backend rules; nothing requires a hook, story, recitation, or a specific visual. The arrangement realises the lesson's approved lesson arc (factory §13.1) with these existing block types; the arc itself is planning data and is not sent to learners.

#### 6.5.3 Displayed-evidence budget
| Role | What counts | Limit |
|---|---|---|
| `content` | distinct sources shown by `evidence` blocks, `teach.evidence`, and story `quote`s (all excerpts of one hadith or verse = one source) | **≤ 3** per lesson |
| `activity` | a verified source introduced by an activity itself and not shown as content — currently the Quran source of a `recite_verse` (its `source_id`) | **≤ 1 per recitation exercise** |

`Source.displayed` is `true` exactly for content and activity sources, with `display_role` set accordingly; `source_count` = their number. A `recite_verse` may recite a source already displayed as content (then it adds nothing) or its own activity source. `verse_meaning` must reference a content source. `which_evidence` options and drawer-only sources don't count. The Salah reference: river hadith, pillars hadith, prayer-times hadith (`content`, 3) + An-Nisa 4:103 segment (`activity`, 1) → `source_count` 4, as the prototype's `sourceCount: 4`.

#### 6.5.4 Reference lesson: Salah
The prototype's Salah lesson (`qabas/lib/data/lesson_salah.dart`) is reproduced **1:1** as a regression fixture — all 14 steps, its copy, terms, states, evidence, and recitation segment, in both languages and both tracks. Appendix A is the binding step-by-step conversion specification; the fixtures are generated from the Dart source, not retyped. Its fixture identity (`les_u1_l3`, `unit_1`) is frozen in the received export and kept as an opaque fixture ID; in the Unit 0–10 curriculum the reference is the gold candidate for lesson 3.2 "Five Times a Day" in Unit 3, and acceptance compares sessions after normalizing IDs (quality §18.1). This sequence is specific to the reference; it is not a template every lesson must follow. Its size (14 steps, 6 scored exercises, about 7 minutes) is within the duration guidance; its scope spans the current slots 3.1 and 3.2, and its publication is decided separately (status P-07).

#### 6.5.5 Resume
Progress stays local, so resume uses **durable local session state** plus the server's answer history:
- Local state (persisted on every step change, keyed by `session_id` + `lesson_version`): current top-level item index, completed step ids, `predict` selections and whether their feedback was shown, the exercise whose feedback panel is open (with its evaluation), the retry queue and completed retries, and the outro/completion stage.
- In-card state **resets intentionally**: a story resumes at beat 0 and a teaching card at its first point (both cheap to replay); `predict` keeps its selection.
- On restart, if local state exists and matches the server session's `lesson_version`, restore it exactly (re-showing an open feedback panel from the stored evaluation, never re-submitting).
- **Answer history visibility** (`answers[].result`): `immediate` → `correct` / `incorrect` / `neutral` (skipped or unavailable) with the stored `evaluation` snapshot (the original evaluation as issued, including mastery before/after — never recomputed); `end` → `hidden` with `evaluation: null` while the session is active, then real results after finish (the result/review stage); `none` → always `hidden` with `evaluation: null`. `hidden` never means skipped; grading is unaffected server-side. A duplicate submission returns the same response shape the mode allows (`{exercise_id, recorded}` for `none`/`end`).
- **Fresh device / lost local state** (reference algorithm `tools/recovery.py`): the cursor comes from **first attempts in authored order** — resume right after the longest contiguous answered prefix of exercise blocks (retries never move it). If history ever had a gap (a later exercise answered while an earlier one isn't — the server rejects this, so it is defensive only), resume at the content boundary before the earliest unanswered exercise; completed items are never re-submitted and unanswered ones are never skipped. When every exercise has a first attempt: resume at the first content item after the last exercise, else at the retry round if retries remain, else at completion. **Retry queue** = first attempts with `result: incorrect`, excluding `recite_verse`, `flashcard`, and `neutral`/`hidden`, **minus every exercise with any recorded retry (correct or incorrect)** — the one retry is spent either way. An interrupted retry that was never recorded stays in the queue. Content reading isn't recorded server-side, so content after the resume point is shown again; `predict` selections are not restored. `none`/`end` sessions have no retry round.
- Tests: restart in content, after a prediction, with an incorrect-feedback panel open, during the retry round, and on a fresh device.

#### `GET /sessions/{session_id}` → `Session` (resume; see §6.5.5). `answers` lists every recorded answer in order (`{ exercise_id, is_retry, result, recorded_at, evaluation }`), redacted per feedback mode as described in §6.5.5.

#### `POST /sessions/{session_id}/answers`
Request:
```json
{
  "exercise_id": "ex_u2_l1_07",
  "answer": { "segment_id": "seg_2" },
  "elapsed_ms": 6400,
  "is_retry": false
}
```
Response: `AnswerEvaluation` (§5.8) or `{ "exercise_id": "...", "recorded": true }` for `none`/`end` modes.

**Retry rule (lessons only):** after the last item, the client re-presents exercises answered incorrectly (**once each**) and submits them with `"is_retry": true`. Retries give no XP, never lower mastery, and never count in accuracy. `recite_verse`, `flashcard`, and neutral (skipped/unavailable) outcomes are not retried.
- **One original attempt and one retry per exercise and session.** **Attempt identity = (`session_id`, `exercise_id`, `is_retry`).** Exactly two identities can exist per exercise: the original and the retry. Any request whose identity is already recorded is a **replay**: the server returns the stored response the feedback mode allows, applies no mastery/FSRS/misconception/quest/XP change, records nothing, and **ignores the request body** (a different `answer` for a recorded identity is not re-graded; it is logged for diagnostics only). Because a retry request for an exercise whose retry is already recorded has a recorded identity, it is always a replay — there is no "second retry" outcome. `409 retry_not_allowed` applies only to a retry request whose identity is **not yet recorded** and which is ineligible: no first attempt yet, a first attempt that wasn't `incorrect` (correct, neutral, or hidden-mode), an excluded type (`recite_verse`, `flashcard`), or a non-lesson session.
- **First attempts follow authored order:** a first attempt for an exercise while an earlier exercise block has none → `409 out_of_order`.
- **Processing order (normative):** (1) authenticate; (2) load the session and check ownership (`404` if it does not exist or belongs to someone else); (3) parse only `exercise_id` and `is_retry` and look up that identity: if recorded, return the stored mode-permitted response (also after the session finished); (4) otherwise reject fresh attempts on a `finished`/`abandoned` session (`409 session_finished` / `session_not_active`); (5) check the exercise was served, then retry eligibility and authored order; (6) validate the full body against the served payload (`400 validation_error`); (7) grade, record and apply effects in one transaction. A concurrent duplicate that loses the unique-identity race re-reads and returns the winner's stored response.

**Quick reviews (`mode: quick`):** `feedback_mode=immediate`, `time_limit_ms=20000` per exercise, ~10 exercises; on timeout submit `"answer": null` → evaluated as incorrect. **Card reviews (`mode: cards`)** are untimed (`time_limit_ms: null`) self-rated `flashcard` decks of up to 12 cards (fewer when fewer are due and practiced; `409 nothing_to_review` when there is none).

#### `POST /sessions/{session_id}/finish`
Request:
```json
{ "duration_ms": 312000 }
```
Finish is idempotent: the first successful call commits exactly one completion and stores the `SessionResult`. Any later call for that session, including a client retry after a timeout or a different `duration_ms`, returns the stored result with `200` and changes nothing. The server clamps `duration_ms` to `[0, wall-clock time since started_at]` and stores the clamped value. Finishing an `abandoned` session → `409 session_not_active`. Every served exercise needs a recorded first attempt before finish (skips, unavailable maps and review timeouts are recorded answers); otherwise `409 out_of_order` with `details.missing_exercise_ids`. Retries are optional at finish.
Response `200` — `SessionResult`:
```json
{
  "session_id": "ses_91ab",
  "kind": "lesson",
  "score": { "correct": 1, "total": 2, "percent": 50 },
  "passed": null,
  "xp": { "total": 15, "breakdown": [ { "reason": "lesson_complete", "xp": 10 }, { "reason": "recitation_passed", "xp": 3 }, { "reason": "daily_goal_met", "xp": 2 } ] },
  "duration_ms": 312000,
  "layers": {
    "understanding": { "correct": 1, "total": 2, "percent": 50 },
    "applying": null,
    "remembering": null
  },
  "streak": { "current": 3, "extended_today": true },
  "daily_goal": { "minutes": 10, "minutes_today": 12, "met": true },
  "mastery_summary": [
    { "concept_id": "con_allah_one", "title": "وحدانية الله", "before": 0.2, "after": 0.56 },
    { "concept_id": "con_qibla", "title": "القِبلة", "before": 0.4, "after": 0.37 }
  ],
  "terms_mastered": [ { "term_id": "term_khaliq", "text": "الخالق" } ],
  "misconceptions": { "activated": [ { "misconception_id": "mis_kaaba_worship", "title": "المسلمون يعبدون الكعبة" } ], "resolved": [] },
  "unlocked": [ { "type": "lesson", "id": "les_u2_l2", "title": "واحدٌ لا مثيل له" } ],
  "review_items": null,
  "next_step": {
    "type": "lesson",
    "reason": "next_lesson",
    "unit_id": "unit_2",
    "lesson_id": "les_u2_l2",
    "title": "واحدٌ لا مثيل له",
    "due_reviews_count": 1
  }
}
```
- This example follows the §6.5 session: multiple choice correct; spot-error **incorrect** on the first attempt (misconception activated, mastery of القِبلة drops) then corrected in the retry round; recitation passed. Accuracy counts the two accuracy-eligible first attempts (1/2); the recitation is excluded; no `lesson_perfect` (not all accuracy-counted first attempts were correct). XP: `lesson_complete` 10 + `recitation_passed` 3 + `daily_goal_met` 2 = 15. `tools/validate.py` recomputes this result from the session and its answer history (`fixtures/workflows/ses_91ab.json`).
- `mastery_summary[].before/after`: each practiced concept's mastery **at session start** and **at session end**, after every update the session applied (first attempts, retries, recitation), rounded half-up to 2 decimals. The example: وحدانية الله 0.20 → 0.48 (correct MCQ) → 0.56 (passed recitation: +0.15 × (1 − m)); القِبلة 0.40 → 0.30 (incorrect first attempt) → 0.37 (correct retry: +0.10 × (1 − m)). Stored answer evaluations keep their original snapshots (the spot-error evaluation still shows 0.40 → 0.30). Excluding recitation from accuracy does not exclude its mastery update.
- `passed`: `true/false` for `unit_test` (≥ `pass_percent`), `null` otherwise.
- `duration_ms`: echo of the submitted duration (shown as the time tile).
- `layers`: graded first attempts of exercises with `scoring.accuracy = true`, grouped by `scoring.layer`: `understand` → `understanding`, `apply` → `applying`. A key is `null` when no such exercise exists. `remembering` is always `null` in this revision (prototype placeholder); `remember`-layer results count in accuracy only.
- Accuracy and `score` count graded first attempts (`correct` true/false) of exercises with `scoring.accuracy = true`; `predict`, recitation, and `correct: null` answers are excluded. `lesson_perfect` requires at least one **accuracy-counted, graded first attempt**, with all such attempts correct. The result denominator counts graded first attempts (a skipped/unavailable eligible exercise reduces it), so it can be smaller than `counts.scored`.
- The lesson completion screen (S5) shows accuracy, time, and embers (= `xp.total`) count-ups, `layers` bars, `Session.completion.review_topics`, `Session.completion.challenge`, and `Session.completion.check_in` ("غداً سنسألك" / "Tomorrow we'll ask"). Celebration, count-ups, sounds, haptics, combo flame, and the streak transition follow the prototype and run locally.
- `review_items` (only for `unit_test`, feedback mode `end`): `[{ "exercise_id", "correct", "correct_answer", "explanation": Span[], "source_ids": [] }]` shown as an answer review list.
- `pretest` shows only a thank-you screen and `next_step` (no score shown to the learner).

#### `POST /sessions/{session_id}/abandon` → `204`
Idempotent for an active or already abandoned session; `409 session_finished` after finish. Effects already applied by recorded answers (mastery, misconceptions, recitation XP) remain; finish-time effects (FSRS, lesson completion, XP, streak, quests) never happen for an abandoned session.

### 6.6 Recitation

#### `POST /recitation/checks` (multipart/form-data)
| Field | Type | Required |
|---|---|---|
| `audio` | file (§3.7) | yes |
| `surah` | int | yes |
| `ayah` | int | yes |
| `word_start` | int | no — with `word_end`, checks a segment of the ayah (1-based, inclusive). Omit both for the whole ayah. |
| `word_end` | int | no |
| `exercise_id` | string | no (set when inside a session) |

Response `200` — evaluated with errors:
```json
{
  "check_id": "rchk_55e1",
  "status": "evaluated",
  "passed": false,
  "words": [
    { "index": 0, "expected": "قُلْ", "result": "correct", "heard": "قل", "audio_segment": { "url": "https://cdn.example.com/quran/afasy/112001.mp3", "start_ms": 0, "end_ms": 520 } },
    { "index": 1, "expected": "هُوَ", "result": "correct", "heard": "هو", "audio_segment": { "url": "https://cdn.example.com/quran/afasy/112001.mp3", "start_ms": 520, "end_ms": 900 } },
    { "index": 2, "expected": "اللَّهُ", "result": "substituted", "heard": "الله", "audio_segment": { "url": "https://cdn.example.com/quran/afasy/112001.mp3", "start_ms": 900, "end_ms": 1650 } },
    { "index": 3, "expected": "أَحَدٌ", "result": "missing", "heard": null, "audio_segment": { "url": "https://cdn.example.com/quran/afasy/112001.mp3", "start_ms": 1650, "end_ms": 2900 } }
  ],
  "summary": { "correct": 2, "missing": 1, "substituted": 1, "extra": 0 },
  "message": [{ "type": "text", "text": "أحسنت في البداية! انتبه إلى الكلمتين المظللتين، اضغط على كل كلمة لتسمع نطقها ثم أعد المحاولة." }]
}
```
Passed:
```json
{
  "check_id": "rchk_55e2",
  "status": "evaluated",
  "passed": true,
  "words": [
    { "index": 0, "expected": "قُلْ", "result": "correct", "heard": "قل", "audio_segment": null },
    { "index": 1, "expected": "هُوَ", "result": "correct", "heard": "هو", "audio_segment": null },
    { "index": 2, "expected": "اللَّهُ", "result": "correct", "heard": "الله", "audio_segment": null },
    { "index": 3, "expected": "أَحَدٌ", "result": "correct", "heard": "احد", "audio_segment": null }
  ],
  "summary": { "correct": 4, "missing": 0, "substituted": 0, "extra": 0 },
  "message": [{ "type": "text", "text": "ما شاء الله، قراءة صحيحة!" }]
}
```
Unclear audio:
```json
{
  "check_id": "rchk_55e3",
  "status": "unclear",
  "passed": false,
  "words": [],
  "summary": { "correct": 0, "missing": 0, "substituted": 0, "extra": 0 },
  "message": [{ "type": "text", "text": "لم نسمعك بوضوح. اقترب من الميكروفون وأعد المحاولة في مكان هادئ." }]
}
```
Word `index` values are 0-based positions within the checked text (the segment when `word_start`/`word_end` were sent). UI: render the ayah (or segment) word by word; color `missing` and `substituted` words, and show `extra` words (with `expected=null`, `heard` set) as small inserted chips. Tapping a word plays `audio_segment` (seek + stop at `end_ms`); if `audio_segment` is `null`, play the whole ayah audio. The heard text is **not** shown to the learner by default (it is ASR text without diacritics).
Extra word example entry: `{ "index": 2, "expected": null, "result": "extra", "heard": "هو", "audio_segment": null }`.

Requires `Idempotency-Key` (§3.2). The check is owned by the caller. When the answer is submitted, the server verifies that the check belongs to the same user and matches the served exercise's surah, ayah, word range and expected-text digest; a mismatch → `409 recitation_check_mismatch`. A check can be used by any number of submissions of that same exercise, but only by its owner. At capacity the endpoint returns `503 upstream_unavailable` with `details.retry_after_ms` rather than queueing indefinitely; the client offers retry or skip.

After the learner is done (passed, or chooses to continue), submit the exercise answer to the session:
```json
{ "exercise_id": "ex_u2_l1_09", "answer": { "check_id": "rchk_55e2" }, "elapsed_ms": 41000, "is_retry": false }
```
or skip:
```json
{ "exercise_id": "ex_u2_l1_09", "answer": { "skipped": true }, "elapsed_ms": 5000, "is_retry": false }
```

### 6.7 Glossary

#### `GET /glossary?state=all|new|learning|mastered&cursor=&limit=`
```json
{
  "items": [
    {
      "term_id": "term_tawhid",
      "text": "التوحيد",
      "transliteration": "Tawhid",
      "state": "learning",
      "level": "basic",
      "definition": [
        {
          "type": "text",
          "text": "الإيمان بأن الله واحد لا شريك له، وأنه وحده من يستحق العبادة."
        }
      ],
      "example": [
        {
          "type": "text",
          "text": "سورة الإخلاص تلخّص معنى التوحيد في أربع آيات قصيرة."
        }
      ],
      "pronunciation_audio_url": "https://cdn.example.com/terms/term_tawhid.mp3",
      "source_id": "src_q_112_1_4",
      "lesson_id": "les_u2_l1",
      "lesson_title": "من هو الله؟",
      "arabic": null
    }
  ],
  "next_cursor": null
}
```

#### `GET /glossary/{term_id}` → `TermCard`

#### `POST /glossary/{term_id}/opened` → `204`
Call when the term card opens (used by the adaptive engine; fire-and-forget).

### 6.8 Raqeeb (رقيب)

Answers take 5–30 s. The client posts a message, then **polls** the assistant message until it completes.

#### `POST /raqeeb/conversations`
Request (`context` is optional; set it when the learner opens Raqeeb from a lesson via "Ask Raqeeb about this"):
```json
{ "context": { "lesson_id": "les_u2_l1", "block_id": "blk_u2_l1_e1" } }
```
Response `201`:
```json
{ "conversation_id": "conv_3c9d", "title": null, "context": { "lesson_id": "les_u2_l1", "block_id": "blk_u2_l1_e1" }, "created_at": "2026-10-04T10:00:00Z", "updated_at": "2026-10-04T10:00:00Z" }
```

#### `GET /raqeeb/conversations?cursor=&limit=`
```json
{
  "items": [
    { "conversation_id": "conv_3c9d", "title": "لماذا يصلي المسلمون خمس مرات؟", "last_message_preview": "فرض الله على المسلمين خمس صلوات في اليوم والليلة…", "updated_at": "2026-10-04T10:01:10Z" },
    { "conversation_id": "conv_3c9e", "title": "هل هذا الحديث صحيح؟", "last_message_preview": "هذا اللفظ حكم عليه العلماء بأنه باطل…", "updated_at": "2026-10-03T18:22:00Z" }
  ],
  "next_cursor": null
}
```
`title` is set by the backend after the first answer.

#### `GET /raqeeb/conversations/{conversation_id}`
```json
{
  "conversation": { "conversation_id": "conv_3c9d", "title": "لماذا يصلي المسلمون خمس مرات؟", "context": null, "created_at": "2026-10-04T10:00:00Z", "updated_at": "2026-10-04T10:01:10Z" },
  "messages": []
}
```
`messages` is ordered oldest → newest and contains user and assistant `Message` objects (below).

#### `POST /raqeeb/conversations/{conversation_id}/messages` (multipart/form-data)
| Field | Type | Notes |
|---|---|---|
| `text` | string | optional, ≤ 2,000 chars |
| `audio` | file | optional, the learner's spoken question |
| `images` | file, repeatable | optional, ≤ 3 |
| `document` | file | optional, 1 PDF or DOCX |

At least one field is required (`validation_error` otherwise). Any combination is allowed (e.g., image + text "is this hadith authentic?"). Requires `Idempotency-Key` (§3.2): a retried upload returns the original `202` body and never starts a second answer. Only one assistant message per conversation may be `processing`; a new message while one is processing → `409 answer_in_progress`. Attachment and document text is untrusted data: Raqeeb never follows instructions found inside it (backend §9.1).

Response `202`:
```json
{
  "user_message": {
    "message_id": "msg_u_101",
    "role": "user",
    "status": "received",
    "text": "هل هذا الحديث صحيح؟",
    "attachments": [
      { "attachment_id": "att_img_1", "kind": "image", "filename": "screenshot.jpg", "mime": "image/jpeg", "size_bytes": 482133, "url": "https://cdn.example.com/att/att_img_1.jpg", "duration_ms": null, "pages": null }
    ],
    "created_at": "2026-10-04T10:05:00Z"
  },
  "assistant_message": {
    "message_id": "msg_a_102",
    "role": "assistant",
    "status": "processing",
    "stage": "received",
    "created_at": "2026-10-04T10:05:00Z"
  }
}
```

#### `GET /raqeeb/messages/{message_id}`
Poll every **1,000 ms** until `status` is `completed` or `failed`. Stop after **90 s** and show a retry action. The response is the `AssistantMessage` union discriminated by `status` (`processing` | `failed` | `completed`); conversation history (`ConvDetail.messages`) uses the same union plus user messages (`status: received`). A retry action posts a new message (new `Idempotency-Key`); the server marks a message `failed` no later than 75 s after acceptance, so a stalled message never blocks the conversation.

Processing:
```json
{
  "message_id": "msg_a_102",
  "role": "assistant",
  "status": "processing",
  "stage": "verifying",
  "created_at": "2026-10-04T10:05:00Z"
}
```
Show a stage indicator with localized labels: `reading_inputs` "أقرأ ما أرسلته", `classifying` "أفهم سؤالك", `retrieving` "أبحث في المصادر", `verifying` "أتحقق من المصادر", `writing` "أكتب الإجابة", `adapting` "أبسّط الإجابة لك".

Failed:
```json
{
  "message_id": "msg_a_102",
  "role": "assistant",
  "status": "failed",
  "stage": "retrieving",
  "created_at": "2026-10-04T10:05:00Z",
  "error": { "code": "upstream_unavailable", "message": "Sources are temporarily unavailable." }
}
```

##### Completed assistant `Message` — full schema
| Field | Type | Notes |
|---|---|---|
| `message_id`, `role`, `status`, `stage`, `created_at`, `completed_at` | | `stage = done` |
| `understood_input` | object | What Raqeeb extracted from the inputs; render as a collapsible "ما فهمته من رسالتك" row. Fields: `transcript` (string\|null, from audio), `images` (`[{ attachment_id, extracted_text, description }]`), `document` (`{ attachment_id, filename, pages_processed, truncated, summary }` \| null). |
| `classification` | object | `{ question_class, label }` — `label` is localized; render as a small chip. |
| `abstained` | bool | `true` when Raqeeb deliberately did not answer (fatwa, out-of-scope, insufficient sources). |
| `blocks` | `AnswerBlock[]` | Render in order. |
| `citations` | `[{ ref, source: Source }]` | Targets of `citation` spans. Render as a numbered sources list under the answer. |
| `suggested_lessons` | `[{ lesson_id, title }]` | Chips "تعلّم أكثر". Only published lessons of the learner's track; opening one follows the normal access rules (a locked lesson shows its Soft Lock). |
| `feedback` | `"up" \| "down" \| null` | Current user's rating. |

`AnswerBlock` types:
| `type` | Fields |
|---|---|
| `paragraph` | `spans: Span[]` (may contain `term` spans — use the message's `terms` map; and `citation` spans) |
| `evidence` | `evidence: Evidence` |
| `verification` | `items: VerificationItem[]` |
| `differing_views` | `intro: Span[]`, `views: [{ holder: string, spans: Span[], source_ids: string[] }]` |
| `referral` | `referral: Referral` |

The completed message also includes `terms: { [term_id]: TermCard }` for any `term` spans.

`VerificationItem`:
| Field | Notes |
|---|---|
| `item_id` | |
| `quote_text` | The quote as found in the user's input. |
| `detected_kind` | `quran` \| `hadith` \| `claim` |
| `status` | `VerificationStatus` |
| `hadith_grade` | `{ grade_label, grade_category, grader, source_book, reference }` \| null — `grade_label` is verbatim from the source (e.g., "صحيح", "ضعيف", "موضوع", "باطل"). |
| `correct_text` | `Evidence` \| null — for `quran_inexact`: the exact verse. |
| `alternative` | `Evidence` \| null — an authentic hadith with a related meaning, when the quote is weak/fabricated. |
| `note` | `Span[]` |
| `source_ids` | `string[]` |

Render as a card with a status badge: `quran_exact` green "مطابق للمصحف", `quran_inexact` amber "نص الآية غير دقيق", `hadith_graded` colored by `grade_category` (authentic/acceptable green, weak amber, fabricated red, other grey), `not_found` grey "لم نجد له أصلاً في المصادر المتاحة" (this is **not** the same as fabricated), `needs_specialist` blue "يحتاج إلى مختص".

`Referral`:
```json
{
  "referral_type": "fatwa_authority",
  "reason": [{ "type": "text", "text": "…" }],
  "targets": [ { "name": "…", "description": "…", "url": "https://…", "contact": null } ]
}
```

**Example A — general knowledge (text question):**
```json
{
  "message_id": "msg_a_202",
  "role": "assistant",
  "status": "completed",
  "stage": "done",
  "created_at": "2026-10-04T10:01:00Z",
  "completed_at": "2026-10-04T10:01:09Z",
  "understood_input": {
    "transcript": null,
    "images": [],
    "document": null
  },
  "classification": {
    "question_class": "general_knowledge",
    "label": "سؤال معرفي"
  },
  "abstained": false,
  "blocks": [
    {
      "type": "paragraph",
      "spans": [
        {
          "type": "text",
          "text": "فرض الله على المسلمين خمس صلوات في اليوم والليلة، وهي من "
        },
        {
          "type": "term",
          "text": "أركان الإسلام",
          "term_id": "term_arkan_islam"
        },
        {
          "type": "text",
          "text": " الخمسة."
        },
        {
          "type": "citation",
          "ref": 1
        },
        {
          "type": "text",
          "text": " وتتوزع على أوقات اليوم: الفجر والظهر والعصر والمغرب والعشاء، فتبقى صلة المسلم بربه متجددة طوال يومه."
        },
        {
          "type": "citation",
          "ref": 2
        }
      ]
    }
  ],
  "citations": [
    {
      "ref": 1,
      "source": {
        "source_id": "src_h_buni_islam",
        "kind": "hadith",
        "provider": "dorar",
        "title": "حديث: بُني الإسلام على خمس",
        "reference": "صحيح البخاري (8)، صحيح مسلم (16)",
        "excerpt": "بُنِيَ الإسْلَامُ علَى خَمْسٍ…",
        "url": null,
        "displayed": false,
        "display_role": null
      }
    },
    {
      "ref": 2,
      "source": {
        "source_id": "src_ih_prayer_times",
        "kind": "article",
        "provider": "islamhouse",
        "title": "أوقات الصلوات الخمس",
        "reference": "IslamHouse",
        "excerpt": "…",
        "url": "https://islamhouse.com/",
        "displayed": false,
        "display_role": null
      }
    }
  ],
  "terms": {
    "term_arkan_islam": {
      "term_id": "term_arkan_islam",
      "text": "أركان الإسلام",
      "transliteration": "Arkan al-Islam",
      "state": "new",
      "level": "basic",
      "definition": [
        {
          "type": "text",
          "text": "الأعمال الخمسة الأساسية التي يقوم عليها الإسلام: الشهادتان، والصلاة، والزكاة، والصوم، والحج."
        }
      ],
      "example": [
        {
          "type": "text",
          "text": "الصلاة هي الركن الثاني من أركان الإسلام."
        }
      ],
      "pronunciation_audio_url": "https://cdn.example.com/terms/term_arkan_islam.mp3",
      "source_id": "src_h_buni_islam",
      "lesson_id": "les_u4_l1",
      "lesson_title": "أركان الإسلام",
      "arabic": null
    }
  },
  "suggested_lessons": [
    {
      "lesson_id": "les_u4_l1",
      "title": "أركان الإسلام"
    }
  ],
  "feedback": null
}
```

**Example B — verification (image screenshot of a social media post):**
```json
{
  "message_id": "msg_a_102",
  "role": "assistant",
  "status": "completed",
  "stage": "done",
  "created_at": "2026-10-04T10:05:00Z",
  "completed_at": "2026-10-04T10:05:14Z",
  "understood_input": {
    "transcript": null,
    "images": [ { "attachment_id": "att_img_1", "extracted_text": "قال رسول الله ﷺ: اطلبوا العلم ولو بالصين", "description": "لقطة شاشة لمنشور على منصة تواصل اجتماعي" } ],
    "document": null
  },
  "classification": { "question_class": "verification", "label": "تحقق" },
  "abstained": false,
  "blocks": [
    {
      "type": "verification",
      "items": [
        {
          "item_id": "vi_1",
          "quote_text": "اطلبوا العلم ولو بالصين",
          "detected_kind": "hadith",
          "status": "hadith_graded",
          "hadith_grade": { "grade_label": "باطل", "grade_category": "fabricated", "grader": "الألباني", "source_book": "السلسلة الضعيفة", "reference": null },
          "correct_text": null,
          "alternative": {
            "evidence_id": "src_h_talab_ilm",
            "kind": "hadith",
            "quran": null,
            "hadith": { "text_ar": "طَلَبُ الْعِلْمِ فَرِيضَةٌ عَلَى كُلِّ مُسْلِمٍ", "translation": null, "narrator": "أنس بن مالك رضي الله عنه", "collections": ["سنن ابن ماجه"], "grade_label": "صحيح", "grade_category": "authentic", "grade_source": "الألباني", "excerpt": false }
          },
          "note": [ { "type": "text", "text": "هذا اللفظ لا يصح نسبته إلى النبي ﷺ. ويغني عنه في الحث على طلب العلم حديث صحيح بمعنى قريب." } ],
          "source_ids": ["src_dorar_talab_sin"]
        }
      ]
    }
  ],
  "citations": [
    { "ref": 1, "source": { "source_id": "src_dorar_talab_sin", "kind": "hadith", "provider": "dorar", "title": "الموسوعة الحديثية — الدرر السنية", "reference": "اطلبوا العلم ولو بالصين", "excerpt": "…", "url": "https://dorar.net/", "displayed": false, "display_role": null } }
  ],
  "terms": {},
  "suggested_lessons": [],
  "feedback": null
}
```
*(Fixture note: grading values in this example are illustrative; live values come verbatim from Dorar.)*

**Example C — personal fatwa (abstention + referral):**
```json
{
  "message_id": "msg_a_302",
  "role": "assistant",
  "status": "completed",
  "stage": "done",
  "created_at": "2026-10-04T11:00:00Z",
  "completed_at": "2026-10-04T11:00:04Z",
  "understood_input": { "transcript": "أنا أعمل في مطعم يقدّم الخمر، هل يجب أن أترك عملي؟", "images": [], "document": null },
  "classification": { "question_class": "personal_fatwa", "label": "فتوى شخصية" },
  "abstained": true,
  "blocks": [
    {
      "type": "referral",
      "referral": {
        "referral_type": "fatwa_authority",
        "reason": [ { "type": "text", "text": "سؤالك يتعلق بحالتك الشخصية، والحكم فيه يحتاج إلى عالم يسمع تفاصيل وضعك. لذلك لا أقدّم فيه حكماً، وأنصحك بسؤال جهة إفتاء معتمدة." } ],
        "targets": [
          { "name": "الرئاسة العامة للبحوث العلمية والإفتاء", "description": "بوابة الفتوى الرسمية في المملكة العربية السعودية", "url": "https://www.alifta.gov.sa", "contact": null }
        ]
      }
    }
  ],
  "citations": [],
  "terms": {},
  "suggested_lessons": [],
  "feedback": null
}
```

**Example D — sensitive human situation:**
```json
{
  "message_id": "msg_a_402",
  "role": "assistant",
  "status": "completed",
  "stage": "done",
  "created_at": "2026-10-04T12:00:00Z",
  "completed_at": "2026-10-04T12:00:02Z",
  "understood_input": { "transcript": null, "images": [], "document": null },
  "classification": { "question_class": "sensitive_human", "label": "دعم" },
  "abstained": true,
  "blocks": [
    { "type": "paragraph", "spans": [ { "type": "text", "text": "يؤسفني ما تمر به، وسلامتك أهم شيء الآن. تحدّث مع مرشد يستطيع مساعدتك بشكل مباشر." } ] },
    {
      "type": "referral",
      "referral": {
        "referral_type": "human_support",
        "reason": [ { "type": "text", "text": "هذه حالة تحتاج دعماً بشرياً مباشراً." } ],
        "targets": [ { "name": "فريق دعم المهتدين", "description": "مرشدون متطوعون للمسلمين الجدد", "url": null, "contact": "support@qabas.app" } ]
      }
    }
  ],
  "citations": [],
  "terms": {},
  "suggested_lessons": [],
  "feedback": null
}
```

**Example E — differing opinions (Word document input):**
```json
{
  "message_id": "msg_a_502",
  "role": "assistant",
  "status": "completed",
  "stage": "done",
  "created_at": "2026-10-04T12:30:00Z",
  "completed_at": "2026-10-04T12:30:09Z",
  "understood_input": {
    "transcript": null,
    "images": [],
    "document": {
      "attachment_id": "att_doc_1",
      "filename": "سؤال.docx",
      "pages_processed": 1,
      "truncated": false,
      "summary": "سؤال عن تحريك الإصبع في التشهد أثناء الصلاة."
    }
  },
  "classification": {"question_class": "differing_opinions", "label": "مسألة خلافية"},
  "abstained": false,
  "blocks": [
    {
      "type": "differing_views",
      "intro": [{"type": "text", "text": "في هذه المسألة قولان معتبران عند العلماء:"}],
      "views": [
        {
          "holder": "القول الأول",
          "spans": [
            {
              "type": "text",
              "text": "يشير المصلي بإصبعه في التشهد ويحرّكها، واستدلوا بحديث وائل بن حجر رضي الله عنه."
            },
            {"type": "citation", "ref": 1}
          ],
          "source_ids": ["src_ih_tashahhud_1"]
        },
        {
          "holder": "القول الثاني",
          "spans": [
            {"type": "text", "text": "يشير بإصبعه دون تحريك، واستدلوا بحديث عبد الله بن الزبير رضي الله عنهما."},
            {"type": "citation", "ref": 2}
          ],
          "source_ids": ["src_ih_tashahhud_2"]
        }
      ]
    },
    {
      "type": "referral",
      "referral": {
        "referral_type": "specialist",
        "reason": [{"type": "text", "text": "لترجيح أحد القولين في حالتك، اسأل عالماً أو مختصاً تثق به."}],
        "targets": [
          {
            "name": "فريق دعم المهتدين",
            "description": "مرشدون يجيبون عن أسئلة المسلمين الجدد",
            "url": null,
            "contact": "support@qabas.app"
          }
        ]
      }
    }
  ],
  "citations": [
    {
      "ref": 1,
      "source": {
        "source_id": "src_ih_tashahhud_1",
        "kind": "fatwa",
        "provider": "islamhouse",
        "title": "الإشارة بالإصبع في التشهد",
        "reference": "IslamHouse",
        "excerpt": "…",
        "url": "https://islamhouse.com/",
        "displayed": false,
        "display_role": null
      }
    },
    {
      "ref": 2,
      "source": {
        "source_id": "src_ih_tashahhud_2",
        "kind": "fatwa",
        "provider": "islamhouse",
        "title": "صفة الإشارة في التشهد",
        "reference": "IslamHouse",
        "excerpt": "…",
        "url": "https://islamhouse.com/",
        "displayed": false,
        "display_role": null
      }
    }
  ],
  "terms": {},
  "suggested_lessons": [],
  "feedback": null
}
```
A `differing_views` answer always ends with a `referral` block of type `specialist`.

**Example F — text explanation (voice input):**
```json
{
  "message_id": "msg_a_602",
  "role": "assistant",
  "status": "completed",
  "stage": "done",
  "created_at": "2026-10-04T12:40:00Z",
  "completed_at": "2026-10-04T12:40:09Z",
  "understood_input": {"transcript": "ما معنى الصمد في سورة الإخلاص؟", "images": [], "document": null},
  "classification": {"question_class": "text_explanation", "label": "شرح نص"},
  "abstained": false,
  "blocks": [
    {
      "type": "evidence",
      "evidence": {
        "evidence_id": "src_q_112_2",
        "kind": "quran",
        "quran": {
          "surah": 112,
          "surah_name": "الإخلاص",
          "ayah_start": 2,
          "ayah_end": 2,
          "segment": null,
          "text_uthmani": "اللَّهُ الصَّمَدُ",
          "translation": null,
          "translation_source": null,
          "audio": null
        },
        "hadith": null
      }
    },
    {
      "type": "paragraph",
      "spans": [
        {
          "type": "text",
          "text": "«الصَّمَد» هو السيد الذي يقصده الخلق في حوائجهم كلها، فكل شيء محتاج إليه، وهو غني عن كل أحد."
        },
        {"type": "citation", "ref": 1}
      ]
    }
  ],
  "citations": [
    {
      "ref": 1,
      "source": {
        "source_id": "src_tafsir_112_mukhtasar",
        "kind": "tafsir",
        "provider": "tafsir_center",
        "title": "المختصر في التفسير",
        "reference": "تفسير الإخلاص: 2",
        "excerpt": "…",
        "url": null,
        "displayed": false,
        "display_role": null
      }
    }
  ],
  "terms": {},
  "suggested_lessons": [],
  "feedback": null
}
```

**Example G — deep creed question (PDF input):**
```json
{
  "message_id": "msg_a_702",
  "role": "assistant",
  "status": "completed",
  "stage": "done",
  "created_at": "2026-10-04T12:50:00Z",
  "completed_at": "2026-10-04T12:50:09Z",
  "understood_input": {
    "transcript": null,
    "images": [],
    "document": {
      "attachment_id": "att_doc_2",
      "filename": "question.pdf",
      "pages_processed": 2,
      "truncated": false,
      "summary": "مقال يسأل: لماذا توجد المعاناة إذا كان الله رحيماً؟"
    }
  },
  "classification": {"question_class": "doubt_or_deep_creed", "label": "سؤال عقدي"},
  "abstained": false,
  "blocks": [
    {
      "type": "paragraph",
      "spans": [
        {
          "type": "text",
          "text": "من الحِكم التي يذكرها العلماء أن الحياة الدنيا دار اختبار، يُبتلى فيها الإنسان بالخير والشر ليظهر صبره وعمله."
        },
        {"type": "citation", "ref": 1},
        {"type": "citation", "ref": 2}
      ]
    },
    {
      "type": "evidence",
      "evidence": {
        "evidence_id": "src_q_67_2",
        "kind": "quran",
        "quran": {
          "surah": 67,
          "surah_name": "الملك",
          "ayah_start": 2,
          "ayah_end": 2,
          "segment": null,
          "text_uthmani": "الَّذِي خَلَقَ الْمَوْتَ وَالْحَيَاةَ لِيَبْلُوَكُمْ أَيُّكُمْ أَحْسَنُ عَمَلًا ۚ وَهُوَ الْعَزِيزُ الْغَفُورُ",
          "translation": null,
          "translation_source": null,
          "audio": null
        },
        "hadith": null
      }
    },
    {
      "type": "referral",
      "referral": {
        "referral_type": "specialist",
        "reason": [{"type": "text", "text": "هذا سؤال عميق، ويفيدك الحوار المباشر مع مختص لمناقشة تفاصيله."}],
        "targets": [
          {
            "name": "فريق دعم المهتدين",
            "description": "مرشدون يجيبون عن أسئلة المسلمين الجدد",
            "url": null,
            "contact": "support@qabas.app"
          }
        ]
      }
    }
  ],
  "citations": [
    {
      "ref": 1,
      "source": {
        "source_id": "src_q_67_2",
        "kind": "quran",
        "provider": "quran_com",
        "title": "سورة الملك",
        "reference": "الملك: 2",
        "excerpt": "الَّذِي خَلَقَ الْمَوْتَ وَالْحَيَاةَ لِيَبْلُوَكُمْ",
        "url": "https://quran.com/67/2",
        "displayed": false,
        "display_role": null
      }
    },
    {
      "ref": 2,
      "source": {
        "source_id": "src_ih_suffering",
        "kind": "article",
        "provider": "islamhouse",
        "title": "الحكمة من الابتلاء",
        "reference": "IslamHouse",
        "excerpt": "…",
        "url": "https://islamhouse.com/",
        "displayed": false,
        "display_role": null
      }
    }
  ],
  "terms": {},
  "suggested_lessons": [],
  "feedback": null
}
```

**Example H — out of scope:**
```json
{
  "message_id": "msg_a_802",
  "role": "assistant",
  "status": "completed",
  "stage": "done",
  "created_at": "2026-10-04T13:00:00Z",
  "completed_at": "2026-10-04T13:00:09Z",
  "understood_input": {"transcript": null, "images": [], "document": null},
  "classification": {"question_class": "out_of_scope", "label": "خارج النطاق"},
  "abstained": true,
  "blocks": [
    {
      "type": "paragraph",
      "spans": [
        {
          "type": "text",
          "text": "أنا رقيب، أساعدك في أسئلتك عن الإسلام ومصادره. لا أستطيع الإجابة عن حالة الطقس، لكن يسعدني أن أجيب عن أي سؤال يخص تعلمك."
        }
      ]
    }
  ],
  "citations": [],
  "terms": {},
  "suggested_lessons": [],
  "feedback": null
}
```
Together, examples A–H cover all eight classes (A general, B verification with an image, C personal fatwa with voice, D sensitive, E differing with DOCX, F text explanation with voice, G deep creed with PDF, H out of scope).

#### `POST /raqeeb/messages/{message_id}/feedback`
```json
{ "rating": "down", "reason": "unclear", "comment": null }
```
`reason`: `inaccurate` | `unclear` | `not_helpful` | `other` | null. Response `204`.

**Chat composer UI:** text field; mic button (press-and-hold or tap-to-toggle, 60 s max, shows timer); image button (gallery/camera, up to 3 thumbnails); document button (PDF/DOCX, 1). Show user message immediately with attachment chips (audio chip shows duration; tapping plays the local recording).

### 6.9 League and friends

#### `GET /leagues/current`
Weekly league of ~20 learners (week = Sunday 00:00 → Saturday 23:59, Asia/Riyadh, for every learner regardless of their own timezone) in a named tier. The top `promotion_zone_size` ranks move up one tier at week end; there is **no demotion**. Tier artwork is bundled by `tier_key`. Before the learner's first XP of the week: `404 not_found` with `details.reason = "no_league_this_week"`.
```json
{
  "league_id": "lg_2026w40_07",
  "week_start": "2026-10-03T21:00:00Z",
  "week_end": "2026-10-10T20:59:59Z",
  "ends_in_seconds": 412300,
  "my_rank": 4,
  "tier": { "tier_key": "tier_beacon", "index": 1, "name": "منارة", "is_top_tier": false },
  "promotion_zone_size": 5,
  "demotion": false,
  "members": [
    { "rank": 1, "user_id": "usr_a1", "display_name": "نور ١٢", "xp_week": 310, "is_me": false, "avatar_key": "traveler_01", "in_promotion_zone": true },
    { "rank": 2, "user_id": "usr_a2", "display_name": "Traveler 88", "xp_week": 240, "is_me": false, "avatar_key": "traveler_02", "in_promotion_zone": true },
    { "rank": 3, "user_id": "usr_a3", "display_name": "سالك ٥", "xp_week": 180, "is_me": false, "avatar_key": "traveler_03", "in_promotion_zone": true },
    { "rank": 4, "user_id": "usr_7f3k2a", "display_name": "مسافر ٤٧", "xp_week": 120, "is_me": true, "avatar_key": "traveler_04", "in_promotion_zone": true },
    { "rank": 5, "user_id": "usr_a5", "display_name": "Seeker 21", "xp_week": 95, "is_me": false, "avatar_key": "traveler_05", "in_promotion_zone": true }
  ]
}
```
*(Fixture abbreviated to 5 members; real payload has all members.)* Members with `private_profile` appear to others as a generic localized name ("مسافر" / "Traveler") with the default avatar. Tiers are the prototype's four — Lantern, Beacon, Star, Dawn (`tier_lantern`, `tier_beacon`, `tier_star`, `tier_dawn`) — with localized names from `contract/registries.json` (exported from `community.dart`; the Arabic names in examples are provisional until that export).

#### `GET /friends`
```json
{
  "items": [
    { "user_id": "usr_f1", "display_name": "Seeker 21", "xp_week": 95, "streak_current": 2, "online": true, "avatar_key": "traveler_02" },
    { "user_id": "usr_f2", "display_name": "سالك ٥", "xp_week": 180, "streak_current": 6, "online": false, "avatar_key": "traveler_02" }
  ],
  "next_cursor": null
}
```
`online` = connected in the last 60 s (used to enable "Duel now"). `xp_week` and `streak_current` are `null` for friends with `private_profile`.

#### `POST /friends/invites` → `201`
```json
{ "invite_id": "inv_x1", "code": "QBS-7F3K", "share_text": "انضم إليّ في قبس! استخدم الرمز QBS-7F3K", "expires_at": "2026-10-11T09:00:00Z" }
```
Share via the OS share sheet.

#### `POST /friends/invites/accept`
```json
{ "code": "QBS-7F3K" }
```
Response `200`: a friend item (same shape as `GET /friends` items). Errors: `invite_invalid`, `already_friends`.

#### `DELETE /friends/{user_id}` → `204`

### 6.10 Challenges (REST; endpoints keep the `/duels` path)

Two presets (the UI calls both "challenges"):
| `preset` | Players | Questions | Time each | Notes |
|---|---|---|---|---|
| `duel` | 2 (you + one friend, or you + the practice bot) | 7 | 15 s | Points `100 + floor(100 × remaining ÷ limit)`, result reveal 3 s. Async fallback available. |
| `group` | 2–4 (you + up to 3 friends) | 3 | 10 s | Points `100 + half_up(50 × remaining ÷ limit)` with `half_up(x) = floor(x + 0.5)` (Dart `.round()` for positive values; **not** banker's rounding), result reveal 2.2 s (prototype values). Boundary: 500 ms remaining → bonus 2.5 → **103**. The prototype's live challenge (`live_challenge_screen.dart`). Live only; starts when all invitees responded or after 60 s with whoever joined (≥ 1 friend); if nobody joined, offer the practice bot duel. `bot_fill: true` fills empty seats with practice bots. |

Closed question types only (`multiple_choice`, `true_false`, `verse_meaning`). Points per question come from `config.scoring` (`base + rounding(speed_bonus × remaining_ms ÷ time_limit_ms)` if correct, else 0); the reveal lasts `config.reveal_ms`. Ranking by total points; ties broken by the lower total response time of correct answers; still tied → **shared rank**. `result.winner_user_ids` lists every rank-1 player; each of them receives the rank-1 XP. `is_draw` is `true` when all players share rank 1.

#### `Duel` object
```json
{
  "duel_id": "duel_8a1",
  "status": "ready",
  "mode": "live",
  "preset": "duel",
  "opponent_type": "bot",
  "players": [
    { "user_id": "usr_7f3k2a", "display_name": "مسافر ٤٧", "avatar_key": "traveler_03", "is_me": true, "is_bot": false, "status": "joined" },
    { "user_id": "usr_bot_1", "display_name": "المدرّب", "avatar_key": "traveler_bot", "is_me": false, "is_bot": true, "status": "joined" }
  ],
  "config": { "question_count": 7, "time_limit_ms": 15000, "scoring": { "base": 100, "speed_bonus": 100, "rounding": "floor" }, "reveal_ms": 3000 },
  "ws_url": "wss://api.example.com/v1/ws/duels/duel_8a1",
  "created_at": "2026-10-04T13:00:00Z",
  "expires_at": "2026-10-04T13:02:00Z",
  "result": null
}
```
`result` (when `status = finished`):
```json
{
  "winner_user_ids": ["usr_7f3k2a"],
  "is_draw": false,
  "scores": [ { "user_id": "usr_7f3k2a", "rank": 1, "points": 845, "correct": 6 }, { "user_id": "usr_bot_1", "rank": 2, "points": 610, "correct": 5 } ],
  "xp_awarded": 15
}
```

#### `POST /duels`
```json
{ "preset": "duel", "opponent_type": "bot", "friend_user_ids": [], "bot_fill": false }
```
```json
{ "preset": "duel", "opponent_type": "friend", "friend_user_ids": ["usr_f1"], "bot_fill": false }
```
```json
{ "preset": "group", "opponent_type": "friends", "friend_user_ids": ["usr_f1", "usr_f2", "usr_f3"], "bot_fill": true }
```
`opponent_type`: `bot` | `friend` (duel, exactly 1 id) | `friends` (group, 1–3 ids). Response `201`: `Duel`. Bot duels start as `ready`. Friend challenges start as `pending`; each player has `status` `invited` | `joined` | `declined`. Duels expire after 2 minutes; group challenges start or close after 60 s (rules above).
Group lobby: connect the WebSocket as soon as the challenge exists (status `pending`); the server sends `player_status` events as invitees join or decline and a `state` with `status: ready` when the start rule fires (all responded, or 60 s with ≥ 1 friend joined). If the socket can't connect, poll `GET /duels/{id}` every 2 s.

#### `GET /duels/invitations`
```json
{
  "items": [
    { "duel_id": "duel_9b2", "from": { "user_id": "usr_f1", "display_name": "Seeker 21" }, "created_at": "2026-10-04T13:05:00Z", "expires_at": "2026-10-04T13:07:00Z" }
  ],
  "next_cursor": null
}
```

#### `POST /duels/{duel_id}/accept` → `200` `Duel`
Usually `status = ready`, `mode = live` → connect the WebSocket. If the inviter already switched to async, the response has `mode = async`, `status = in_progress` → use the async flow below. Async duels stay acceptable for 24 h.
#### `POST /duels/{duel_id}/decline` → `204`
#### `GET /duels/{duel_id}` → `Duel`
#### `GET /duels?cursor=&limit=` → `{ "items": [Duel], "next_cursor": null }` (history)

#### Async fallback
(Duel preset only.) If a friend duel stays `pending` for 60 s, show "Play now; your friend plays later". This converts the duel to `mode = async`:

`POST /duels/{duel_id}/async` → `200` `Duel` (`mode = async`, `status = in_progress`).

Then per question:

`POST /duels/{duel_id}/async/next` → `200`
```json
{
  "question_index": 0,
  "total": 7,
  "exercise": {
    "exercise_id": "ex_duel_u2_03",
    "type": "true_false",
    "concept_ids": ["con_allah_one"],
    "prompt": [{ "type": "text", "text": "صح أم خطأ؟" }],
    "time_limit_ms": 15000, "scoring": { "accuracy": true, "combo": true, "layer": null }, "framing": null,
    "payload": { "statement": [{ "type": "text", "text": "يؤمن المسلمون بأن لله شريكاً في الخلق." }] }
  },
  "issued_at": "2026-10-04T13:06:10Z",
  "deadline_at": "2026-10-04T13:06:25Z"
}
```
`POST /duels/{duel_id}/async/answer`
```json
{ "question_index": 0, "answer": { "value": false } }
```
Response `200`:
```json
{
  "question_index": 0,
  "correct": true,
  "correct_answer": { "value": false },
  "points": 164,
  "explanation": [{ "type": "text", "text": "الإسلام يقوم على أن الله واحد لا شريك له." }],
  "total_points": 164,
  "finished": false
}
```
After the 7th answer, `finished = true` and the duel shows "Waiting for your friend" until `GET /duels/{id}` returns `status = finished`. The server measures time between `next` and `answer`.

Async idempotency and timing (rev 10, normative):
- `async/next` is idempotent: until the current question is answered or its deadline passes, every call returns the same `question_index`, `issued_at` and `deadline_at`. It never skips ahead. After the deadline an unanswered question is recorded as a 0-point timeout and the next call issues the following question.
- `async/answer` for the current index records once (unique per duel, player and question). Repeating it returns the stored response. An index other than the current or an already answered one → `409 out_of_order` (an answered index replays). `"answer": null` records a timeout. Answers arriving after `deadline_at` score 0.
- Each player plays their own seven questions; the duel finishes when both players have finished, or 24 h after the switch to async. If the friend has not finished by then, the friend forfeits: unanswered questions score 0 and the inviter is the winner (`duel_win` XP; the friend receives no challenge XP), as in backend §11.4. If the inviter abandons mid-way, their unanswered questions score 0 at the 24 h close and normal ranking applies.

### 6.11 Reviewer console (role `reviewer`)

#### `POST /admin/factory/runs`
Start the lesson factory for a curriculum lesson slot (here 1.1 "What Does Islam Mean?"). One run produces the lesson for every track the unit serves (Arabic Explorer and Arabic New Muslim variants, then their English localizations). `position_index` is the curriculum position inside the unit; it never creates a prerequisite (those come from the approved plan).
```json
{
  "unit_id": "unit_1",
  "lesson_type": "concept",
  "brief": "الدرس 1.1: معنى كلمة الإسلام (الاستسلام لله) بلغة بسيطة جداً، فوزٌ تعلّمي صغير واحد.",
  "position_index": 0
}
```
Response `201`: `FactoryRun` (`status = running`, `stage = plan`).

#### `GET /admin/factory/runs?status=&cursor=&limit=`
```json
{
  "items": [
    { "run_id": "run_41", "unit_id": "unit_1", "lesson_type": "concept", "title": "ما معنى الإسلام؟", "status": "awaiting_gate2", "stage": "qa", "updated_at": "2026-10-04T14:10:00Z" },
    { "run_id": "run_42", "unit_id": "unit_7", "lesson_type": "story", "title": "إبراهيم يبحث عن ربه", "status": "awaiting_gate1", "stage": "plan", "updated_at": "2026-10-04T14:20:00Z" }
  ],
  "next_cursor": null
}
```

#### `GET /admin/factory/runs/{run_id}` → `FactoryRun`
Poll every 3 s while `status = running`. `review_digest` (rev 10) is non-null exactly while the run awaits a gate. It is the SHA-256 of the stored gate artifact (plan for Gate 1; draft plus QA report for Gate 2), computed by [review.py](contract_revision10/contract/review.py). Any change to that artifact, including a completed regeneration, produces a new digest. `published` is `{lesson_id, version}` once the run is published and `null` before that. `error` is set exactly when `status = failed`.
```json
{
  "run_id": "run_42",
  "unit_id": "unit_7",
  "lesson_type": "story",
  "brief": "الدرس 7.4: قصة إبراهيم عليه السلام مع الكوكب والقمر والشمس من سورة الأنعام.",
  "status": "awaiting_gate1",
  "stage": "plan",
  "stages": [
    { "stage": "plan", "status": "done", "started_at": "2026-10-04T14:19:00Z", "finished_at": "2026-10-04T14:20:00Z" },
    { "stage": "decompose", "status": "pending", "started_at": null, "finished_at": null }
  ],
  "plan": {
    "title": { "ar": "إبراهيم يبحث عن ربه", "en": "Ibrahim Searches for His Lord" },
    "central_question": { "ar": "كيف انتهى إبراهيم إلى أن ما يغيب لا يستحق العبادة؟", "en": "How did Ibrahim conclude that what sets does not deserve worship?" },
    "supporting_understandings": [
      { "ar": "ما رآه إبراهيم: الكوكب والقمر والشمس تظهر ثم تغيب.", "en": "What Ibrahim saw: the star, the moon and the sun appear and then set." },
      { "ar": "ما استنتجه: ما يتغيّر ويغيب لا يكون رباً يستحق العبادة.", "en": "What he concluded: what changes and disappears cannot be a Lord worthy of worship." },
      { "ar": "عِظَم المخلوقات يدل على عظمة خالقها، ولا يجعلها معبودة.", "en": "The greatness of created things points to their Creator's greatness; it does not make them worthy of worship." }
    ],
    "depth_profile": "standard",
    "primary_learning_outcome": { "ar": "أن يشرح المتعلم، كما يروي القرآن، لماذا انتهى إبراهيم إلى أن ما يغيب لا يستحق العبادة.", "en": "The learner can explain, as the Qur'an narrates it, why Ibrahim concluded that what sets does not deserve worship." },
    "objectives": [
      { "ar": "بعد الدرس يستطيع المتعلم أن يشرح لماذا لا يستحق الكوكب أو القمر أو الشمس العبادة.", "en": "After the lesson, the learner can explain why stars, the moon, or the sun do not deserve worship." }
    ],
    "prerequisite_concept_ids": ["con_allah_one"],
    "introduced_concept_ids": ["con_creation_not_worshipped"],
    "new_terms": [ { "ar": "الآفلين", "en": "Those that set" } ],
    "target_misconceptions": [
      { "misconception_id": null, "title": { "ar": "كل ما هو عظيم في الكون يستحق التقديس", "en": "Anything great in the universe deserves worship" }, "description": { "ar": "…", "en": "…" } }
    ],
    "lesson_type": "story",
    "estimated_minutes": 6,
    "lesson_arc": {
      "pattern": "story",
      "rationale": { "ar": "يعيش المتعلم الملاحظة مع إبراهيم ويتوقع قبل أن يرى الخلاصة، ثم يطبقها على مثال معاصر.", "en": "The learner follows Ibrahim's observations and predicts before seeing the conclusion, then applies it to a modern example." },
      "steps": [
        { "step_id": "setting", "technique": "scenario", "experience": { "ar": "ليلة في الصحراء ونجم لامع يلفت النظر.", "en": "A night in the desert and a bright star that draws the eye." }, "interactive": false },
        { "step_id": "predict", "technique": "prediction", "experience": { "ar": "يتوقع المتعلم ماذا يستنتج من يرى النجم يغيب.", "en": "The learner predicts what someone would conclude when the star sets." }, "interactive": true },
        { "step_id": "turning_point", "technique": "story", "experience": { "ar": "القمر ثم الشمس يغيبان كذلك.", "en": "The moon and then the sun set as well." }, "interactive": false },
        { "step_id": "consequence", "technique": "explanation", "experience": { "ar": "خلاصة إبراهيم كما ترويها الآيات.", "en": "Ibrahim's conclusion as the verses narrate it." }, "interactive": false },
        { "step_id": "apply", "technique": "practice", "experience": { "ar": "يطبق المتعلم الفكرة على أشياء عظيمة في حياتنا اليوم.", "en": "The learner applies the idea to great things in today's life." }, "interactive": true }
      ]
    },
    "reasoning_tools": [
      { "tool": "observation", "justification": { "ar": "القصة قائمة على مشاهدة النجم والقمر والشمس وهي تغيب.", "en": "The story turns on watching the star, the moon and the sun set." } },
      { "tool": "inference", "justification": { "ar": "هدف الدرس هو الخلاصة المستنتجة مما شوهد: ما يغيب لا يكون رباً.", "en": "The outcome is the conclusion drawn from what was observed: what disappears cannot be the Lord." } }
    ],
    "standalone_eligible": false,
    "content_budget": 4,
    "exercise_budget": 3
  },
  "draft": null,
  "qa_report": null,
  "error": null,
  "review_digest": "4eb85084abe69ff1342e1a476aa9d4280d51cc67afc2815b0b9578d330a33e1a",
  "published": null
}
```

#### `POST /admin/factory/runs/{run_id}/gate1`
```json
{ "decision": "approve", "plan": null, "reason": null, "review_digest": "4eb85084abe69ff1342e1a476aa9d4280d51cc67afc2815b0b9578d330a33e1a" }
```
`LessonPlan` (curriculum amendment) records the Curriculum Architect's decisions that Gate 1 approves: the `central_question` the lesson answers completely; one coherent `primary_learning_outcome` (one outcome, not one fact or definition; `objectives` are 1–3 learner-facing intro lines for that same outcome); `supporting_understandings` (the ideas the learner needs for that outcome to be complete and not misleading; they stay inside this lesson and never become sibling lessons); `depth_profile` (`foundational`, `standard` or `focused`: how much development the outcome needs, not difficulty; all Unit 0 and Unit 1 lessons are foundational); `lesson_type` = the lesson's **primary pedagogical mode** (not a limit on which techniques or blocks it may use), mandatory `prerequisite_concept_ids` (the only unlock input), `introduced_concept_ids`, `new_terms`, `target_misconceptions`, `estimated_minutes` for the whole composed lesson (guidance about 6–10 minutes, foundational about 8–10; never a cap or a target to pad to), the lesson-specific `lesson_arc` (`pattern` label, `rationale`, ordered `steps` each with a `technique` — `scenario`, `prediction`, `example`, `story`, `demonstration`, `explanation`, `evidence`, `comparison`, `practice`, `reflection` or `takeaway` — what the learner experiences and whether they act; the arc is the composition plan of the one lesson, its techniques are the lesson's required modes, a story-type arc contains a `story` step, a practice-type arc a `practice` step, and there is at most one `takeaway`), explicitly justified `reasoning_tools` (empty = none; the Writer may not add others), `standalone_eligible` (Discover; requires no prerequisites), `content_budget` (planned non-interactive learner-experience blocks, sized to the depth the outcome needs rather than minimised) and `exercise_budget` (planned graded lesson exercises, 2–6, usually about 3–5; ungraded interactions such as predictions and polls are separate). Model validators enforce the structural rules; per-type targets are reviewer guidance and QA warnings (factory §13.1, §13.3).

`decision`: `approve` | `reject`. To edit, send `approve` with a full edited `plan` object (`LessonPlan`, same shape). `review_digest` must equal the run's current `review_digest`; otherwise → `409 review_stale` and nothing changes. Decisions are recorded with the authenticated reviewer, timestamp, digest and any edited plan (durable audit record). Response `200`: `FactoryRun` (`status = running`). Two reviewers acting on the same gate: the first valid decision wins; the second gets `409 run_not_at_gate` (or `review_stale`).

#### Gate 2 draft (`status = awaiting_gate2`)
The run's `draft` and `qa_report` become non-null:
```json
{
  "draft": {
    "languages": ["ar", "en"],
    "variants": ["explorer", "new_muslim"],
    "previews": [
      { "language": "ar", "variant": "explorer", "objectives": [], "items": [], "completion": null },
      { "language": "en", "variant": "explorer", "objectives": [], "items": [], "completion": null }
    ],
    "claims": [
      {
        "claim_id": "clm_1",
        "text": "رأى إبراهيم كوكباً فلما غاب بيّن أنه لا يستحق العبادة.",
        "status": "supported",
        "basis": "source",
        "reasoning": null,
        "evidence": [
          { "source": { "source_id": "src_q_6_76", "kind": "quran", "provider": "quran_com", "title": "سورة الأنعام", "reference": "الأنعام: 76", "excerpt": "فَلَمَّا جَنَّ عَلَيْهِ اللَّيْلُ رَأَىٰ كَوْكَبًا…", "url": "https://quran.com/6/76", "displayed": true, "display_role": "content" }, "supports": true, "verifier_note": "النص المعروض مطابق للمصحف.",
            "semantic_review": { "fit": "partial", "concerns": ["needs_tafsir", "scholarly_disagreement"], "note": "الآية تنص على «لا أحب الآفلين»؛ فهمها نفياً لاستحقاق العبادة يحتاج إلى التفسير، والمفسرون مختلفون هل كان المقام نظراً أم مناظرة لقومه، فلا تُعرض الجملة كأنها القول الوحيد." } }
        ]
      },
      { "claim_id": "clm_7", "text": "كان عمر إبراهيم آنذاك ست عشرة سنة.", "status": "dropped", "basis": "source", "evidence": [], "reasoning": null }
    ],
    "sentence_map": [
      { "sentence_id": "sen_u7_l4_00", "role": "question", "claim_ids": [] },
      { "sentence_id": "sen_u7_l4_01", "role": "claim", "claim_ids": ["clm_1"] }
    ],
    "arc_map": [
      { "step_id": "setting", "block_ids": ["blk_u7_l4_hook"] },
      { "step_id": "predict", "block_ids": ["blk_u7_l4_predict"] },
      { "step_id": "turning_point", "block_ids": ["blk_u7_l4_story"] },
      { "step_id": "consequence", "block_ids": ["blk_u7_l4_teach"] },
      { "step_id": "apply", "block_ids": ["blk_u7_l4_x1", "blk_u7_l4_x2"] }
    ],
    "exercises": [],
    "glossary": [],
    "misconceptions": [
      { "misconception_id": "mis_worship_creation", "title": "كل ما هو عظيم في الكون يستحق التقديس", "card": [{ "type": "text", "text": "عِظَم المخلوقات يدل على عظمة خالقها، والعبادة لله وحده." }], "source_ids": ["src_q_6_76"] }
    ],
    "visuals": [
      { "scene_id": "scn_3", "origin": "generated_scene", "visual": { "kind": "scene", "key": null, "version": null, "params": { "beat": 0, "focus": -1 }, "image": null, "scene": { "scene_id": "scn_test_desert_well", "version": 2, "schema_version": "qabas.scene/1", "url": "https://cdn.example.com/scenes/scn_test_desert_well/v2/scene.json", "mime_type": "application/json", "sha256": "145f9fd45a554b9e5c77e2b796ba4814fd85d46d72a9b1a91543b3a155e0d7e7", "view_box": { "width": 1600, "height": 1000 }, "required_capabilities": ["scene/1", "shape.rect/1", "shape.ellipse/1", "shape.path/1", "paint.gradient/1", "track/1", "anchors/1", "fx.sparkles/1"] }, "fallback_image": { "url": "https://cdn.example.com/scenes/scn_test_desert_well/v2/fallback_b0_f-1.webp", "mime_type": "image/webp", "width": 1600, "height": 1000 }, "fallback_params": { "beat": 0, "focus": -1 }, "alt": "صحراء ليلاً فيها بئر ونخلة وخيمة", "overlays": [] }, "audit": { "passed": true, "issues": [] }, "attempts": 1,
        "previews": { "frames": [ { "state": { "beat": 0, "focus": -1 }, "time_ms": 0, "reduced_motion": false, "image": { "url": "https://cdn.example.com/previews/scn_test_desert_well/v2/b0_f-1_t0.png", "mime_type": "image/png", "width": 1600, "height": 1000 } }, { "state": { "beat": 1, "focus": 0 }, "time_ms": 1500, "reduced_motion": false, "image": { "url": "https://cdn.example.com/previews/scn_test_desert_well/v2/b1_f0_t1500.png", "mime_type": "image/png", "width": 1600, "height": 1000 } } ],
          "animation": { "url": "https://cdn.example.com/previews/scn_test_desert_well/v2/anim.webm", "mime_type": "video/webm", "width": 1600, "height": 1000, "duration_ms": 8000 },
          "reduced_motion_still": { "url": "https://cdn.example.com/previews/scn_test_desert_well/v2/still.png", "mime_type": "image/png", "width": 1600, "height": 1000 },
          "fallbacks": [ { "state": { "beat": 0, "focus": -1 }, "time_ms": 0, "reduced_motion": true, "image": { "url": "https://cdn.example.com/scenes/scn_test_desert_well/v2/fallback_b0_f-1.webp", "mime_type": "image/webp", "width": 1600, "height": 1000 } } ],
          "timing": { "build_raster_p95_ms": 4.1, "first_frame_ms": 92.0, "device": "reference mid-range Android" },
          "renderer_version": "qabas_scene 1.0.0" } },
      { "scene_id": "scn_1", "origin": "generated", "visual": { "kind": "image", "key": null, "version": null, "params": null, "image": { "url": "https://cdn.example.com/scenes/u7_l4_s1_night_sky.webp", "mime_type": "image/webp", "width": 1600, "height": 1000 }, "scene": null, "fallback_image": null, "fallback_params": null, "alt": "سماء ليل صافية فيها كوكب لامع فوق صحراء", "overlays": [] }, "audit": { "passed": true, "issues": [] }, "attempts": 1, "previews": null },
      { "scene_id": "scn_2", "origin": "builtin", "visual": { "kind": "builtin", "key": "day_arc", "version": 1, "params": { "highlight": -1 }, "image": null, "scene": null, "fallback_image": null, "fallback_params": null, "alt": "قوس يمثل مسار الشمس من الفجر إلى الليل", "overlays": [] }, "audit": null, "attempts": 0, "previews": null }
    ]
  },
  "qa_report": {
    "issues": [
      { "severity": "warning", "kind": "reading_level", "location": { "sentence_id": "sen_u7_l4_04", "exercise_id": null, "scene_id": null }, "message": "الجملة طويلة لمستوى المبتدئ (38 كلمة)." },
      { "severity": "warning", "kind": "scholarly_review", "location": { "sentence_id": null, "exercise_id": null, "scene_id": null }, "message": "clm_1 / src_q_6_76 (partial; needs_tafsir, scholarly_disagreement): الآية تنص على «لا أحب الآفلين»؛ فهمها نفياً لاستحقاق العبادة يحتاج إلى التفسير، والمفسرون مختلفون هل كان المقام نظراً أم مناظرة لقومه، فلا تُعرض الجملة كأنها القول الوحيد." },
      { "severity": "warning", "kind": "pedagogy", "location": { "sentence_id": null, "exercise_id": null, "scene_id": null }, "message": "الخلاصة تعيد جملة الشرح الثانية بالنص نفسه؛ يُفضَّل أن تجمع الفكرة بدلاً من تكرارها." }
    ]
  }
}
```
- `previews[]` carries `objectives`, `items`, and `completion` with exactly the session schema (§6.5), including `Visual` descriptors, `hook`/`story`/`teach` blocks, and presentations such as `day_arc`. **Reuse the learner renderers** (same built-in scenes, same reveal and beat behavior) so the reviewer sees exactly what learners will see. Answer interactions in previews are local only (no session).
- `exercises`: `Exercise` objects extended with `answer_key`, `option_misconceptions` (`{ option_id: misconception_id }`), `duel_eligible` (bool).
- `glossary`: `StoredGlossaryTerm[]`, the canonical bilingual factory/storage records from `contract/qabas_contract.py`: `term_id`, `text: {ar,en}`, `arabic: string | null`, `transliteration`, `definition: {basic: {ar: Span[], en: Span[]}, intermediate: {ar: Span[], en: Span[]} | null}`, `example: {ar: Span[], en: Span[]}`, and nullable `concept_id`, `lesson_id`, `source_id`, `pronunciation_audio_url`. Reviewer projections retain canonical Arabic separately from localized headings and learner state. Previews retain category artwork, ordering labels/presentation and the served bank order. Reuse the same learner renderers; do not infer decoration from translated labels, positions or lesson IDs.
- `misconceptions`: remediation cards for the plan's target misconceptions (same shape as `AnswerEvaluation.misconception`).
- `visuals` (`DraftVisual` = `{ scene_id, origin, visual, audit, attempts, previews }`, one authoritative model): `origin = builtin` → registry selection, `visual.kind = builtin`, `audit: null`, `attempts: 0`, `previews: null`, not regenerable; `origin = generated` → static image, `visual.kind = image`, audit + attempts, `previews: null`, regenerable; `origin = generated_scene` → `visual.kind = scene`, audit + attempts and **required** `previews` (`ScenePreview`: state `frames`, `animation` WebM, `reduced_motion_still`, one `fallbacks` frame per fallback state, `timing`, `renderer_version`), regenerable. The reviewer console also renders the draft scene live with the learner renderer. **Visual readiness (pre-generation audit):** `contextual.visual_readiness` derives one state per draft visual from these fields: `placeholder` (a media URL is a reserved example host or `mock-asset://`: no real asset), `compiled` (builtin), `capability_blocked` (a scene needs a capability that the production registry has not released), `preview_only` (scene frames not rendered by a `qabas_scene` build), `unaudited`, `audit_failed`, `audited`. Approve requires every visual to be `compiled` or `audited`, and publication rejects any media URL anywhere in the lesson version that `contextual.placeholder_media_errors` flags (reserved example hosts, `mock-asset://`, anything other than published https). The `cdn.example.com` URLs in this document are illustrative and would fail that gate.
- Evidence panel: tapping a sentence in the preview shows its `role` and highlights its `claim_ids`, listing their evidence with `supports` + `verifier_note` and, for Quran, hadith and tafsir evidence, the `semantic_review` (`fit`: `exact`/`partial`/`stretched`/`unrelated`; `concerns` such as `needs_tafsir`, `context_dependent`, `addressee_specific`, `generalised_from_specific`, `beyond_source`, `scholarly_disagreement`, `single_opinion_as_consensus`, `oversimplified`, `translation_sensitive`; and a note), or the `reasoning` (tool, premises, inference) of a `basis: reasoning` claim. `dropped` claims are listed separately in grey.
- **Semantic scholarly review (pre-generation audit):** `verifier_note` records the text check (exact mushaf/Dorar match, grade); `semantic_review` records whether the verse or hadith supports the claim **as worded**. Model-enforced: supporting Quran, hadith or tafsir evidence carries a `semantic_review`; a `stretched` or `unrelated` fit can never support a claim; a `partial` fit names its concern. Concerns on supporting evidence become `scholarly_review` QA issues (`contextual.scholarly_review_issues`): `beyond_source` and `single_opinion_as_consensus` are blockers until the sentence is narrowed or edited; the others are warnings for the specialist, who decides. The AI flags; it never approves.
- **Sentence roles (curriculum amendment):** `sentence_map[].role` is `claim` (asserts something factual, historical, theological or religious; links ≥ 1 supported claim) or one of the non-assertive roles `framing`, `hypothetical`, `instruction`, `question` (links none). Only assertions need evidence; a non-assertive sentence that actually asserts something is an `unsupported_sentence` blocker. Model-enforced: a `claim` sentence has claim IDs and other roles have none.
- **Claim basis (curriculum amendment):** `basis: source` claims are supported by verified sources (scriptural support or other attributable sources); `basis: reasoning` claims carry `reasoning` that a learner can evaluate without first accepting scripture's authority. Scripture never supports a reasoning claim (model-enforced, no circular support). Both are human-reviewed.
- **Arc map (curriculum amendment):** `arc_map` lists, for each approved `lesson_arc` step, the blocks that realise it; it covers every block, so nothing is appended outside the approved arc (a `story` block belongs to a `story` or `scenario` step, a summary card to the `takeaway` step, a `predict` block to a `prediction` or `reflection` step). All four previews share the same top-level block IDs, types and order; Explorer and New Muslim variants differ only inside blocks (wording, address, framing, some examples), and each English preview is the constrained localization of its Arabic variant (same sentences, roles, claims, exercises, keys and sources).
- A `blocker` issue disables Approve. Deterministic code-validator findings use `kind: validation` (rev 10) and are re-evaluated after the edits in the approve request. A model-reported blocker (`unsupported_sentence`, `fatwa_like`, `image_policy`, `belief_grading`, `circular_reasoning`, `localization`, a `scholarly_review` blocker, or a `pedagogy` blocker for an unsound reasoning example) clears only when that approve request edits or removes the flagged sentence or exercise, or after a regeneration produces a new draft. The server rejects an approve that would leave any blocker.

#### `POST /admin/factory/runs/{run_id}/gate2`
```json
{
  "decision": "approve",
  "sentence_edits": [
    { "sentence_id": "sen_u7_l4_04", "language": "ar", "variant": "explorer", "new_text": "…" },
    { "sentence_id": "sen_u7_l4_04", "language": "en", "variant": "explorer", "new_text": "…" }
  ],
  "exercise_removals": [],
  "reason": null,
  "review_digest": "7f69f6a59dfe9daebe0bc2b59965221eddd1fe595f6ac8d0d3e54201ceaab577"
}
```
`decision`: `approve` (publishes) | `request_changes` (`reason` required; pipeline re-runs from `write`, including `localize`) | `reject`. `sentence_edits`/`exercise_removals` are allowed only with `approve`. Because Arabic is the semantic source, an `ar` sentence edit must be accompanied by the `en` edit of the same `sentence_id` and `variant` (model-enforced); an `en`-only edit may polish the localization without changing meaning. `review_digest` must match (`409 review_stale` otherwise).
On `approve` the server applies the edits, re-links terms in edited text with the deterministic term linker, re-runs every deterministic validator (QA code checks, evidence budget, structure, pools) and only then publishes in one transaction. If an edit introduces a blocker, nothing is published and the response is `400 validation_error` with the issues in `details.issues`. The audit record stores the reviewed digest and the digest of the final published content.
Response `200`: `FactoryRun` with `status = published` and `"published": { "lesson_id": "les_u7_l4", "version": 1 }` on approve.

#### `POST /admin/factory/runs/{run_id}/images/{scene_id}/regenerate` → `202`
Regenerates one `generated` image or `generated_scene` (the path keeps its historical name). Optional body `{ "reason": "…" }` is passed to the author. For scenes it re-runs `scene_author` → `scene_render` → audit and replaces that `draft.visuals` entry (new attempt count, previews, fallback); `builtin` entries return **`400 validation_error`** (not regenerable). `409 run_not_at_gate` is reserved for requests made when the run is not at the required gate. While a regeneration is running, the run reports `status: running` and has no `review_digest`; it returns to `awaiting_gate2` with a new digest when done.

#### `GET /admin/blind-test/next`
```json
{
  "pair_id": "pair_12",
  "lesson_a": { "title": "ما معنى الإسلام؟", "objectives": [], "items": [], "completion": null },
  "lesson_b": { "title": "ما معنى الإسلام؟", "objectives": [], "items": [], "completion": null }
}
```
Response `204` when no pairs remain. Each lesson uses the preview schema above and the learner renderers.

#### `POST /admin/blind-test/{pair_id}`
```json
{ "clearer": "a", "more_accurate": "same", "guessed_handwritten": "b" }
```
Values: `a` | `b` | `same` (for `guessed_handwritten`: `a` | `b` | `unsure`). Response `204`.

#### `GET /admin/metrics`
```json
{
  "learning": {
    "pre_post": [ { "unit_id": "unit_0", "unit_title": "ابدأ بسؤال", "participants": 12, "pre_avg_percent": 48, "post_avg_percent": 81, "delta": 33 } ],
    "misconceptions": { "activated": 19, "resolved": 14, "resolution_rate_percent": 74 },
    "completion": { "units_started": 15, "units_completed": 11 }
  },
  "raqeeb_benchmark": {
    "run_at": "2026-10-06T15:00:00Z",
    "question_count": 80,
    "systems": [
      { "name": "raqeeb", "accuracy_percent": 91, "unsupported_claim_rate_percent": 2, "correct_abstention_percent": 95, "correct_referral_percent": 93 },
      { "name": "baseline_llm", "accuracy_percent": 64, "unsupported_claim_rate_percent": 27, "correct_abstention_percent": 21, "correct_referral_percent": 18 }
    ],
    "by_class": [ { "question_class": "verification", "raqeeb_accuracy_percent": 94, "baseline_accuracy_percent": 41 } ]
  },
  "factory": {
    "lessons_published": 9,
    "avg_generation_minutes": 7,
    "avg_review_minutes": 12,
    "blind_test": { "responses": 18, "handwritten_identified_percent": 44, "generated_preferred_or_same_percent": 61 }
  }
}
```
*(Fixture numbers are placeholders for UI layout only.)*

---

## 7. Exercise catalog

16 exercise experiences = **14 item types** + **2 modes** (quick review = `review` session with timer; live duel = §8). For each type: `payload`, the `answer` the client sends, the `correct_answer` returned, and `details` (if any). Common exercise fields are in §5.7.

General UI: a "Check" button is enabled once an answer is complete. After evaluation, show a bottom feedback panel (correct/incorrect, explanation spans, "Sources" link if `source_ids` non-empty, remediation card if `misconception` non-null), then "Continue".

### 7.1 `multiple_choice`
```json
{ "options": [ { "option_id": "opt_a", "spans": [{ "type": "text", "text": "أن الله واحد لا شريك له" }] }, { "option_id": "opt_b", "spans": [{ "type": "text", "text": "أن الله أول الآلهة" }] }, { "option_id": "opt_c", "spans": [{ "type": "text", "text": "أن الله خاص بالعرب" }] } ] }
```
Answer `{ "option_id": "opt_a" }` · correct_answer `{ "option_id": "opt_a" }` · details `null`.

### 7.2 `true_false_reason`
Two steps on one screen: choose صح/خطأ, then choose the reason.
```json
{
  "statement": [{ "type": "text", "text": "يجب على كل من أسلم أن يغيّر اسمه." }],
  "reasons": [
    { "option_id": "r_1", "spans": [{ "type": "text", "text": "يُغيَّر الاسم فقط إذا كان معناه مخالفاً للإسلام." }] },
    { "option_id": "r_2", "spans": [{ "type": "text", "text": "لأن الأسماء غير العربية لا تجوز." }] },
    { "option_id": "r_3", "spans": [{ "type": "text", "text": "لأن تغيير الاسم من أركان الإسلام." }] }
  ]
}
```
Answer `{ "value": false, "reason_option_id": "r_1" }` · correct_answer `{ "value": false, "reason_option_id": "r_1" }` · details `{ "value_correct": true, "reason_correct": true }`. Correct only if both are correct.

### 7.3 `match_pairs`
```json
{
  "left": [ { "item_id": "l_1", "spans": [{ "type": "text", "text": "الزكاة" }] }, { "item_id": "l_2", "spans": [{ "type": "text", "text": "الصوم" }] }, { "item_id": "l_3", "spans": [{ "type": "text", "text": "الحج" }] } ],
  "right": [ { "item_id": "r_1", "spans": [{ "type": "text", "text": "قصد مكة لأداء المناسك" }] }, { "item_id": "r_2", "spans": [{ "type": "text", "text": "مال يُعطى للمستحقين" }] }, { "item_id": "r_3", "spans": [{ "type": "text", "text": "الامتناع عن الطعام والشراب من الفجر إلى المغرب" }] } ]
}
```
Answer `{ "pairs": [ { "left_id": "l_1", "right_id": "r_2" }, { "left_id": "l_2", "right_id": "r_3" }, { "left_id": "l_3", "right_id": "r_1" } ] }` · correct_answer same shape · details `{ "pair_results": [ { "left_id": "l_1", "correct": true } ] }`.
UI: tap left then right to pair; pairs lock with a color; all must be paired before Check.

### 7.4 `flashcard`
```json
{ "front": [{ "type": "text", "text": "ما معنى «التوحيد»؟" }], "back": [{ "type": "text", "text": "إفراد الله وحده بالعبادة، والإيمان بأنه واحد لا شريك له." }] }
```
Flip card, then the learner rates recall. Answer `{ "rating": "good" }` (`again` | `hard` | `good` | `easy`) · correct_answer `null` · `correct` = `rating != "again"`. No explanation panel; go straight to Continue.

### 7.5 `fill_blank`
```json
{
  "segments": [ { "type": "text", "text": "أركان الإسلام " }, { "type": "blank", "blank_id": "b_1" }, { "type": "text", "text": " أركان، أولها " }, { "type": "blank", "blank_id": "b_2" }, { "type": "text", "text": "." } ],
  "word_bank": [ { "word_id": "w_1", "text": "خمسة" }, { "word_id": "w_2", "text": "ستة" }, { "word_id": "w_3", "text": "الشهادتان" }, { "word_id": "w_4", "text": "الصوم" } ]
}
```
Answer `{ "fills": [ { "blank_id": "b_1", "word_id": "w_1" }, { "blank_id": "b_2", "word_id": "w_3" } ] }` · correct_answer same shape · details `{ "blank_results": [ { "blank_id": "b_1", "correct": true } ] }`.

### 7.6 `categorize`
Payload fields: `presentation` (`CategorizePresentation`), `categories: [{ category_id, label, art_key, phase, capacity }]`, `items: [{ item_id, spans, secondary_label }]`. Nullable keys are required. `secondary_label` is display only. A bucket's `art_key` selects a bundled `UnitArtIcon` drawing from `contract/exercise_art_registry.json`; null omits artwork, unknown keys are rejected. The reference declares `prayer_rug` and `heart`; generic examples use null. `day_arc` categories keep `art_key: null` and select their existing `PhaseIcon` using `phase`. Render the items in received order, including the Dart-captured reference order; no local reshuffle or opaque-ID sorting.

**Presentation `buckets`** (default sorting into groups; `phase` and `capacity` are `null`, 2–3 categories, unlimited items per category):
```json
{
  "presentation": "buckets",
  "categories": [
    {
      "category_id": "c_1",
      "label": "أركان الإسلام",
      "phase": null,
      "capacity": null,
      "art_key": null
    },
    {
      "category_id": "c_2",
      "label": "أركان الإيمان",
      "phase": null,
      "capacity": null,
      "art_key": null
    }
  ],
  "items": [
    {
      "item_id": "i_1",
      "spans": [
        {
          "type": "text",
          "text": "الصلاة"
        }
      ],
      "secondary_label": null
    },
    {
      "item_id": "i_2",
      "spans": [
        {
          "type": "text",
          "text": "الإيمان بالملائكة"
        }
      ],
      "secondary_label": null
    },
    {
      "item_id": "i_3",
      "spans": [
        {
          "type": "text",
          "text": "الزكاة"
        }
      ],
      "secondary_label": null
    },
    {
      "item_id": "i_4",
      "spans": [
        {
          "type": "text",
          "text": "الإيمان باليوم الآخر"
        }
      ],
      "secondary_label": null
    }
  ]
}
```
UI: drag chips into category buckets (tap-to-assign fallback). Draw category art only when its declared `art_key` is non-null; labels and category position do not choose artwork.

**Presentation `day_arc`** (the prototype's five-slot prayer placement, `qabas/lib/features/lesson/exercises/timeline_view.dart`): exactly 5 categories in day order with `phase` = `dawn`, `midday`, `afternoon`, `sunset`, `night` and `capacity: 1`, and exactly 5 items (shuffled). Labels are time-of-day moments, not prayer names.
```json
{
  "presentation": "day_arc",
  "categories": [
    {
      "category_id": "cat_5t",
      "label": "أول الضوء",
      "phase": "dawn",
      "capacity": 1,
      "art_key": null
    },
    {
      "category_id": "cat_j8",
      "label": "منتصف النهار",
      "phase": "midday",
      "capacity": 1,
      "art_key": null
    },
    {
      "category_id": "cat_2w",
      "label": "بعد الظهيرة",
      "phase": "afternoon",
      "capacity": 1,
      "art_key": null
    },
    {
      "category_id": "cat_q1",
      "label": "الغروب",
      "phase": "sunset",
      "capacity": 1,
      "art_key": null
    },
    {
      "category_id": "cat_x6",
      "label": "الليل",
      "phase": "night",
      "capacity": 1,
      "art_key": null
    }
  ],
  "items": [
    {
      "item_id": "itm_c4",
      "spans": [
        {
          "type": "text",
          "text": "العصر"
        }
      ],
      "secondary_label": null
    },
    {
      "item_id": "itm_9a",
      "spans": [
        {
          "type": "text",
          "text": "الفجر"
        }
      ],
      "secondary_label": null
    },
    {
      "item_id": "itm_e2",
      "spans": [
        {
          "type": "text",
          "text": "العشاء"
        }
      ],
      "secondary_label": null
    },
    {
      "item_id": "itm_k7",
      "spans": [
        {
          "type": "text",
          "text": "الظهر"
        }
      ],
      "secondary_label": null
    },
    {
      "item_id": "itm_b5",
      "spans": [
        {
          "type": "text",
          "text": "المغرب"
        }
      ],
      "secondary_label": null
    }
  ]
}
```
`day_arc` UI rules — binding layout from `timeline_view.dart` (all local, no network until Check):
1. Prompt and the tap/drag instruction.
2. The animated day arc above the interaction (`DayArcScene`, proportion 2.8, §5.5d), starting at **dawn (`highlight: 0`)**.
3. The chip bank (items in the order received). A chip may show `secondary_label` beneath its text (e.g., the Arabic prayer name under "Fajr" in English).
4. Five **vertical slot rows** in category order; each row has the slot's sky icon (`PhaseIcon` from `phase`), its time-of-day `label`, and a placement area.
- States as in the prototype: selected chip, ghost chip while dragging, filled slot, correct/incorrect feedback colors after evaluation, and a gentle nudge animation on an incorrect answer.
- Input: drag-and-drop **and** tap-a-chip-then-tap-a-slot.
- One occupant per slot (`capacity: 1`). Dropping onto an occupied slot returns the previous occupant to the bank. Moving a chip removes it from its previous slot. Tapping a filled slot (with no chip selected) clears it, returning the chip to the bank.
- Placing a chip updates the sky/arc to that slot's phase immediately.
- Check is enabled only when every slot is filled. The client never grades locally (the prototype's index-equality grading is replaced by server evaluation).
- The payload never says which phase an item belongs to; ids are opaque.

Answer (both presentations) `{ "assignments": [ { "item_id": "itm_9a", "category_id": "cat_5t" }, { "item_id": "itm_k7", "category_id": "cat_j8" }, { "item_id": "itm_c4", "category_id": "cat_2w" }, { "item_id": "itm_b5", "category_id": "cat_q1" }, { "item_id": "itm_e2", "category_id": "cat_x6" } ] }`. Every item must be assigned exactly once, only to listed categories, within capacity; otherwise `400 validation_error` (timeouts in reviews send `answer: null` instead).
correct_answer: same shape (only when the feedback mode permits) · details `{ "item_results": [ { "item_id": "itm_9a", "correct": true } ] }` (one entry per item). After evaluation, `day_arc` marks each slot correct/incorrect and shows the correct placement.

Correct-answer evaluation fixture (`answer_day_arc_correct.json`):
```json
{
  "exercise_id": "ex_d9v4",
  "recorded": true,
  "correct": true,
  "correct_answer": { "assignments": [ { "item_id": "itm_9a", "category_id": "cat_5t" }, { "item_id": "itm_k7", "category_id": "cat_j8" }, { "item_id": "itm_c4", "category_id": "cat_2w" }, { "item_id": "itm_b5", "category_id": "cat_q1" }, { "item_id": "itm_e2", "category_id": "cat_x6" } ] },
  "details": { "item_results": [ { "item_id": "itm_9a", "correct": true }, { "item_id": "itm_k7", "correct": true }, { "item_id": "itm_c4", "correct": true }, { "item_id": "itm_b5", "correct": true }, { "item_id": "itm_e2", "correct": true } ] },
  "explanation": [{ "type": "text", "text": "أحسنت! الفجر عند أول الضوء، والظهر بعد منتصف النهار، والعصر بعد الظهيرة، والمغرب عند الغروب، والعشاء في الليل." }],
  "source_ids": ["src_h_muslim_612"],
  "misconception": null,
  "mastery_changes": [ { "concept_id": "con_prayer_times", "title": "أوقات الصلوات الخمس", "before": 0.3, "after": 0.55 } ],
  "term_changes": [],
  "xp_awarded": 0
}
```
Incorrect-answer evaluation fixture (`answer_day_arc_incorrect.json`, Asr and Maghrib swapped):
```json
{
  "exercise_id": "ex_d9v4",
  "recorded": true,
  "correct": false,
  "correct_answer": { "assignments": [ { "item_id": "itm_9a", "category_id": "cat_5t" }, { "item_id": "itm_k7", "category_id": "cat_j8" }, { "item_id": "itm_c4", "category_id": "cat_2w" }, { "item_id": "itm_b5", "category_id": "cat_q1" }, { "item_id": "itm_e2", "category_id": "cat_x6" } ] },
  "details": { "item_results": [ { "item_id": "itm_9a", "correct": true }, { "item_id": "itm_k7", "correct": true }, { "item_id": "itm_c4", "correct": false }, { "item_id": "itm_b5", "correct": false }, { "item_id": "itm_e2", "correct": true } ] },
  "explanation": [{ "type": "text", "text": "العصر يكون بعد الظهيرة في آخر النهار، أما المغرب فبعد غروب الشمس." }],
  "source_ids": ["src_h_muslim_612"],
  "misconception": null,
  "mastery_changes": [ { "concept_id": "con_prayer_times", "title": "أوقات الصلوات الخمس", "before": 0.3, "after": 0.23 } ],
  "term_changes": [],
  "xp_awarded": 0
}
```

### 7.7 `spot_error`
Payload in §6.5 (`segments`). Answer `{ "segment_id": "seg_2" }` · correct_answer `{ "segment_id": "seg_2" }`.

### 7.8 `which_evidence`
```json
{
  "claim": [{ "type": "text", "text": "الله واحد لا شريك له." }],
  "options": [
    { "option_id": "ev_1", "evidence": { "evidence_id": "src_q_112_1", "kind": "quran", "quran": { "surah": 112, "surah_name": "الإخلاص", "ayah_start": 1, "ayah_end": 1, "segment": null, "text_uthmani": "قُلْ هُوَ اللَّهُ أَحَدٌ", "translation": null, "translation_source": null, "audio": null }, "hadith": null } },
    { "option_id": "ev_2", "evidence": { "evidence_id": "src_h_niyyat", "kind": "hadith", "quran": null, "hadith": { "text_ar": "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى", "translation": null, "narrator": "عمر بن الخطاب رضي الله عنه", "collections": ["صحيح البخاري (1)", "صحيح مسلم (1907)"], "grade_label": "صحيح", "grade_category": "authentic", "grade_source": "متفق عليه", "excerpt": false } } }
  ]
}
```
Answer `{ "option_id": "ev_1" }` · correct_answer `{ "option_id": "ev_1" }`. Note `audio` may be `null` inside exercise evidence.

### 7.9 `order_steps`
```json
{
  "steps": [
    {
      "step_id": "st_3",
      "spans": [
        {
          "type": "text",
          "text": "غسل الوجه"
        }
      ],
      "secondary_label": null
    },
    {
      "step_id": "st_1",
      "spans": [
        {
          "type": "text",
          "text": "النية"
        }
      ],
      "secondary_label": null
    },
    {
      "step_id": "st_5",
      "spans": [
        {
          "type": "text",
          "text": "مسح الرأس"
        }
      ],
      "secondary_label": null
    },
    {
      "step_id": "st_2",
      "spans": [
        {
          "type": "text",
          "text": "المضمضة والاستنشاق"
        }
      ],
      "secondary_label": null
    },
    {
      "step_id": "st_4",
      "spans": [
        {
          "type": "text",
          "text": "غسل اليدين إلى المرفقين"
        }
      ],
      "secondary_label": null
    },
    {
      "step_id": "st_6",
      "spans": [
        {
          "type": "text",
          "text": "غسل الرجلين إلى الكعبين"
        }
      ],
      "secondary_label": null
    }
  ],
  "presentation": "plain"
}
```
Payload includes required `presentation: plain | day_sequence` and steps `{step_id, spans, secondary_label}`. Producers use `plain` as the general default; `day_sequence` explicitly adds the existing dawn → night `PhaseIcon` header. `secondary_label: string | null` is required, display only, and preserved in bank, chosen and ghost tokens. The reference sends Arabic secondary labels in English and null in Arabic. Steps arrive in the served bank order; respect it without sorting IDs or reshuffling. Answer `{ "order": ["st_1", "st_2", "st_3", "st_4", "st_5", "st_6"] }` · correct_answer same shape · details `{ "first_wrong_index": null }`. Grading uses opaque IDs and the private key, independent of this metadata.

### 7.10 `scenario`
```json
{
  "situation": [{ "type": "text", "text": "دعاك زميلك إلى عشاء عمل، وسيُقدَّم فيه الخمر." }],
  "options": [
    { "option_id": "s_1", "spans": [{ "type": "text", "text": "أحضر وأعتذر بلطف عن الخمر، وأشرب شيئاً آخر." }] },
    { "option_id": "s_2", "spans": [{ "type": "text", "text": "أشرب قليلاً حتى لا أُحرج زميلي." }] },
    { "option_id": "s_3", "spans": [{ "type": "text", "text": "أقاطع زميلي ولا أكلّمه." }] }
  ]
}
```
Answer `{ "option_id": "s_1" }` · correct_answer `{ "option_id": "s_1" }` · details `{ "option_feedback": [ { "option_id": "s_2", "spans": [{ "type": "text", "text": "…" }] } ] }` — show the feedback for the chosen option.

### 7.11 `timeline_order`
```json
{ "events": [ { "event_id": "t_2", "spans": [{ "type": "text", "text": "الهجرة إلى المدينة" }] }, { "event_id": "t_4", "spans": [{ "type": "text", "text": "فتح مكة" }] }, { "event_id": "t_1", "spans": [{ "type": "text", "text": "نزول الوحي في غار حراء" }] }, { "event_id": "t_3", "spans": [{ "type": "text", "text": "غزوة بدر" }] } ] }
```
Answer `{ "order": ["t_1", "t_2", "t_3", "t_4"] }` · correct_answer same · details `{ "event_dates": [ { "event_id": "t_1", "label": "نحو 610م" }, { "event_id": "t_2", "label": "1 هـ / 622م" }, { "event_id": "t_3", "label": "2 هـ" }, { "event_id": "t_4", "label": "8 هـ" } ] }` — reveal dates on a vertical timeline after checking. (`timeline_order` is for **historical** sequences; placing prayers into times of day uses `categorize` with `day_arc`, §7.6.)

### 7.12 `map_place`
Payload: `presentation: MapPresentation`, `visual: Visual` (a downloaded map/illustration, a built-in scene, **or a generated scene**), `question: Span[]`, `pins: [{ pin_id, x_pct, y_pct, label, radius_pct, anchor_id }]`, `interaction: Interaction | null`.
- **Generated scene branch:** `presentation: hotspots`; every pin has `anchor_id` (a static manifest anchor, §5.5e) and lies inside its radius; `visual.fallback_params == visual.params`; pin coordinates are percentages of `scene.view_box`.
- **`Interaction`** = `{ "bindings": [{ "pin_id", "set": { <state>: <value> } }], "reset_on_deselect": bool, "after_evaluation": { "correct": {…} | null, "incorrect": {…} | null } | null }`. Selecting a bound pin sets those declared states immediately (one selection at a time); with `reset_on_deselect`, deselecting/selecting another restores the previous values first. `after_evaluation` applies after the server evaluation is shown, by outcome only — it never reveals which pin is correct before evaluation. States are validated against the registry (built-in) or the manifest's declared states (scene). `null` for image maps (no state). Example: `fixtures/scenes/session_test_scene_lesson.json` (`ex_s_hotspot`: palm → `focus 1`, well → `focus 0`, tent → `focus 2`; correct → `beat 2`).
- `presentation: hotspots` — labeled hotspots on an illustrated scene (`discover_view.dart`): **every pin has a non-null localized `label` sent before evaluation**, shown as a visible pill at the pin; the learner taps the pill/hotspot named in the question. Pill states: idle, selected, correct, incorrect (prototype styling). Built-in scenes use the 1.15 box (§5.5d). Sending all labels does not reveal which pin is correct.
- `presentation: map_pins` — geographic pins on a map image; `label` may be `null` (place-finding) or non-null (event questions).

Downloaded map:
```json
{
  "presentation": "map_pins",
  "visual": { "kind": "image", "key": null, "version": null, "params": null, "image": { "url": "https://cdn.example.com/maps/hijaz.webp", "mime_type": "image/webp", "width": 1600, "height": 1200 }, "scene": null, "fallback_image": null, "fallback_params": null, "alt": "خريطة منطقة الحجاز بلا أسماء", "overlays": [] },
  "question": [{ "type": "text", "text": "أين تقع المدينة المنورة؟" }],
  "pins": [ { "pin_id": "p_1", "x_pct": 58.0, "y_pct": 71.5, "label": null, "radius_pct": null, "anchor_id": null }, { "pin_id": "p_2", "x_pct": 52.5, "y_pct": 38.0, "label": null, "radius_pct": null, "anchor_id": null }, { "pin_id": "p_3", "x_pct": 47.0, "y_pct": 45.2, "label": null, "radius_pct": null, "anchor_id": null } ],
  "interaction": null
}
```
Built-in scene with labeled hotspots (the Salah reference "find the river", frozen values from `lesson_salah.dart`):
```json
{
  "presentation": "hotspots",
  "visual": { "kind": "builtin", "key": "river_house", "version": 1, "params": { "beat": 1 }, "image": null, "scene": null, "fallback_image": null, "fallback_params": null, "alt": "بيت ونخيل ونهر جارٍ أمام الباب", "overlays": [] },
  "question": [{ "type": "text", "text": "أين النهر؟" }],
  "pins": [
    { "pin_id": "pin_h3", "x_pct": 16.0, "y_pct": 36.0, "label": "النخلة", "radius_pct": null, "anchor_id": null },
    { "pin_id": "pin_q8", "x_pct": 55.0, "y_pct": 52.0, "label": "الباب", "radius_pct": null, "anchor_id": null },
    { "pin_id": "pin_z1", "x_pct": 80.0, "y_pct": 34.0, "label": "النافذة", "radius_pct": null, "anchor_id": null },
    { "pin_id": "pin_m4", "x_pct": 42.0, "y_pct": 86.0, "label": "النهر", "radius_pct": null, "anchor_id": null }
  ],
  "interaction": null
}
```
*(Coordinates are the prototype's values in the 1.15 box. Question and label copy in the generated fixtures come verbatim from `lesson_salah.dart`.)*

Coordinate rules:
- `x_pct`/`y_pct` are percentages of the **visual's box for this use**, origin **top-left**, independent of reading direction. The box proportion is `image.width / image.height` for images, or the §5.5d value (1.15 for `hotspots`) for built-in scenes. Render the visual and the pins in the same box (a stack sized to that aspect ratio), so they stay aligned at every screen size and in both `ar` and `en`. Neither the scene nor the pin positions mirror in RTL.
- `radius_pct` (nullable) is the tap-target radius as % of the box width; when `null`, use the prototype's hotspot/pin size (min 44 px target).
- `label` may be non-null (then the question asks about an event, e.g., "أين وقعت غزوة بدر؟").

Answer `{ "pin_id": "p_2" }` · correct_answer `{ "pin_id": "p_2" }` · details `{ "pin_labels": [ { "pin_id": "p_1", "label": "مكة المكرمة" }, { "pin_id": "p_2", "label": "المدينة المنورة" }, { "pin_id": "p_3", "label": "بدر" } ] }`.
If neither the visual nor a geometry-safe fallback can be rendered (§3.8), submit `{ "unavailable": true }` → `correct: null` (`result: neutral`), no mastery change, no retry.

### 7.13 `recite_verse`
Payload: `surah`, `ayah`, `word_start`/`word_end` (both `null` for a whole ayah, else the 1-based inclusive segment), `text_uthmani`, `audio` (clip of exactly that text, with `audio.words` timings for highlighting), `transliteration`, **`meaning`** (`Span[] | null`, a localized explanation from the verified source, shown in the prototype's "المعنى" / "Meaning" expander — the transliteration toggle doesn't replace it), **`source_id`** (the verified Quran source of this text — a content source of the lesson or the exercise's own `activity` source, §6.5.3), `max_duration_ms`, `skippable`. Text, range, audio, timings, and the checker all describe the same verified text; the check request sends the same `word_start`/`word_end`. Scoring is always `accuracy: false, combo: false, layer: null`. Payload and flow in §6.5 and §6.6. UI: play reciter audio (highlight words if `words` present) → record (max `max_duration_ms`, visible countdown) → upload to `/recitation/checks` → show word feedback → "Try again" or "Continue" → submit `{ "check_id": "…" }` (or `{ "skipped": true }` if `skippable`). Evaluation: `correct` = the referenced check `passed`; `null` if skipped. Show transliteration toggle for non-Arabic readers.

### 7.14 `verse_meaning`
Used only when the verse's meaning is explained in the same lesson.
```json
{
  "verse": { "evidence_id": "src_q_112_2", "kind": "quran", "quran": { "surah": 112, "surah_name": "الإخلاص", "ayah_start": 2, "ayah_end": 2, "segment": null, "text_uthmani": "اللَّهُ الصَّمَدُ", "translation": null, "translation_source": null, "audio": null }, "hadith": null },
  "options": [ { "option_id": "m_1", "spans": [{ "type": "text", "text": "الذي يحتاج إليه كل الخلق، وهو لا يحتاج إلى أحد" }] }, { "option_id": "m_2", "spans": [{ "type": "text", "text": "الذي خلق السماوات في ستة أيام" }] } ]
}
```
Answer `{ "option_id": "m_1" }` · correct_answer `{ "option_id": "m_1" }`.

### 7.15 `true_false` (duels only)
```json
{ "statement": [{ "type": "text", "text": "يؤمن المسلمون بأن لله شريكاً في الخلق." }] }
```
Answer `{ "value": false }` · correct_answer `{ "value": false }`.

### 7.16 Modes
- **Card review** — `POST /sessions {kind: review, mode: cards}` (S21): untimed flip-card deck rated again/hard/good/easy.
- **Quick review** — `POST /sessions {kind: review, mode: quick}`; each exercise shows a 20 s countdown bar; timeout submits `answer: null`.
- **Live duel** — §8.

---

## 8. Challenge WebSocket protocol (duel and group presets)

The same protocol serves both presets; `players`, `question_result.players`, and `totals` contain 2–4 entries, and timers use the challenge's `config.time_limit_ms`. Who connects when: the creator and each invited player may connect as soon as the challenge exists (`pending`, lobby: `player_status` events, then a `state` with `status: ready` when the start rule fires); a friend duel's invitee connects after accepting; bot duels are `ready` immediately. Endpoint:
`Duel.ws_url`, used exactly as returned (rev 10). The server embeds a single-use connection ticket in that URL (for example `wss://<API_HOST>/v1/ws/duels/duel_8a1?ticket=…`). The ticket is bound to the caller and the duel and is valid for 60 s. Access tokens never appear in WebSocket URLs (URLs end up in proxy and access logs). `ws_url` values inside socket `state` events and in duel history carry no ticket and are not for connecting. Before every connect or reconnect, get a fresh `Duel` from `POST /duels`, `POST /duels/{id}/accept` or `GET /duels/{id}`. An invalid, expired or reused ticket fails the HTTP upgrade with `401`; a caller who is not a player gets `403`.

All messages are JSON: `{ "type": "<event>", "data": { … } }`.

### 8.1 Client → server
| `type` | `data` | When |
|---|---|---|
| `ready` | `{}` | Right after connecting and rendering the lobby. |
| `answer` | `{ "question_index": 0, "answer": { "option_id": "opt_a" } }` | Once per question. Answer shapes as in §7 for `multiple_choice`, `true_false`, `verse_meaning`. |
| `ping` | `{}` | Every 10 s. |

Client messages are the `WsClientMessage` root (rev 10), discriminated by `type`:
```json
[
  { "type": "ready", "data": {} },
  { "type": "answer", "data": { "question_index": 0, "answer": { "option_id": "opt_a" } } },
  { "type": "ping", "data": {} }
]
```
The server answers an invalid or unknown message with an `error` event (`validation_error`) and keeps the socket open. It closes sockets that send nothing for 30 s and limits each socket to 5 messages per second. An `answer` for any index other than the open question, or a second answer to the same question, is ignored; the `state`/`answer_received` events remain the source of truth.

### 8.2 Server → client
| `type` | `data` |
|---|---|
| `state` | `{ "duel": Duel, "server_ts": "2026-10-04T13:00:01Z", "live": Live \| null }` — sent on connect/reconnect and on lobby → ready. `Live` = `{ "phase": "countdown" \| "question" \| "result" \| "finished", "question_index": int, "question": QuestionEvent \| null, "deadline_at": string \| null, "answered_user_ids": string[], "my_answer": { "answer": object, "locked": true } \| null, "totals": [{ "user_id", "points" }], "results_so_far": [question_result data] }`. It restores the scoreboard, the locked answer (the server rejects a second answer for the same question), and past results without losing points. |
| `player_ready` | `{ "user_id": "usr_bot_1" }` |
| `player_left` | `{ "user_id": "usr_f2" }` — group only; remaining questions score 0 for that player. |
| `countdown` | `{ "starts_at": "2026-10-04T13:00:05Z", "seconds": 3 }` |
| `question` | `{ "question_index": 0, "total": 7, "exercise": Exercise, "issued_at": "…", "deadline_at": "…" }` |
| `answer_received` | `{ "question_index": 0 }` — lock your options. |
| `opponent_answered` | `{ "question_index": 0, "user_id": "usr_f2" }` — mark that player's avatar as answered (no correctness yet). |
| `player_status` | `{ "user_id": "usr_f2", "status": "joined" }` — lobby updates while `pending`. |
| `question_result` | `{ "question_index": 0, "correct_answer": {…}, "explanation": Span[], "players": [ { "user_id": "usr_7f3k2a", "correct": true, "elapsed_ms": 5200, "points": 165 }, { "user_id": "usr_bot_1", "correct": false, "elapsed_ms": 7900, "points": 0 } ], "totals": [ { "user_id": "usr_7f3k2a", "points": 165 }, { "user_id": "usr_bot_1", "points": 0 } ] }` — shown for `config.reveal_ms` (group 2200 ms, duel 3000 ms), then the next `question` arrives. Mock replay uses the same value. |
| `finished` | `{ "result": DuelResult }` (§6.10 `result` shape) plus `"summary": [ { "question_index": 0, "prompt": Span[], "correct_answer": {…}, "explanation": Span[] } ]` |
| `opponent_disconnected` | `{ "user_id": "usr_f2", "grace_ms": 10000 }` |
| `opponent_reconnected` | `{ "user_id": "usr_f2" }` |
| `error` | `{ "code": "duel_not_joinable", "message": "…" }` |
| `pong` | `{}` |

### 8.3 Timing
- The countdown uses `starts_at`; question timers use `deadline_at` (compute remaining time from server timestamps adjusted by the clock offset measured at connect: `offset = server_ts(state message) − local_now`).
- The server is authoritative: late answers are ignored and scored 0.
- If the opponent doesn't reconnect within `grace_ms`, the duel finishes with the remaining questions scored 0 for them.
- If the learner's own socket drops, reconnect with backoff (0.5 s, 1 s, 2 s, max 5 tries), fetching a fresh ticketed `ws_url` (`GET /duels/{id}`) before each attempt; the `state` message restores the current question.
- Server instances can restart during a challenge. The coordinator design in [backend §11.2](../05_BACKEND/BACKEND_HANDOFF.md) keeps deadlines and scores durable, so a reconnect after takeover receives the same `state` (phase, deadline, locked answers, totals).

### 8.4 Typical event sequence
```json
[
  { "type": "state", "data": { "duel": { "duel_id": "duel_8a1", "status": "ready", "mode": "live", "preset": "duel", "opponent_type": "bot", "players": [ { "user_id": "usr_7f3k2a", "display_name": "مسافر ٤٧", "avatar_key": "traveler_03", "is_me": true, "is_bot": false, "status": "joined" }, { "user_id": "usr_bot_1", "display_name": "المدرّب", "avatar_key": "traveler_bot", "is_me": false, "is_bot": true, "status": "joined" } ], "config": { "question_count": 7, "time_limit_ms": 15000, "scoring": { "base": 100, "speed_bonus": 100, "rounding": "floor" }, "reveal_ms": 3000 }, "ws_url": "wss://api.example.com/v1/ws/duels/duel_8a1", "created_at": "2026-10-04T13:00:00Z", "expires_at": "2026-10-04T13:02:00Z", "result": null }, "server_ts": "2026-10-04T13:00:01Z", "live": null } },
  { "type": "player_ready", "data": { "user_id": "usr_bot_1" } },
  { "type": "countdown", "data": { "starts_at": "2026-10-04T13:00:05Z", "seconds": 3 } },
  { "type": "question", "data": { "question_index": 0, "total": 7, "exercise": { "exercise_id": "ex_duel_u2_01", "type": "multiple_choice", "concept_ids": ["con_allah_one"], "prompt": [{ "type": "text", "text": "ما معنى «أحد» في سورة الإخلاص؟" }], "time_limit_ms": 15000, "scoring": { "accuracy": true, "combo": true, "layer": null }, "framing": null, "payload": { "options": [ { "option_id": "opt_a", "spans": [{ "type": "text", "text": "واحد لا شريك له" }] }, { "option_id": "opt_b", "spans": [{ "type": "text", "text": "أول الآلهة" }] } ] } }, "issued_at": "2026-10-04T13:00:05Z", "deadline_at": "2026-10-04T13:00:20Z" } },
  { "type": "answer_received", "data": { "question_index": 0 } },
  { "type": "opponent_answered", "data": { "question_index": 0, "user_id": "usr_bot_1" } },
  { "type": "question_result", "data": { "question_index": 0, "correct_answer": { "option_id": "opt_a" }, "explanation": [{ "type": "text", "text": "«أحد» تعني أن الله واحد لا شريك له." }], "players": [ { "user_id": "usr_7f3k2a", "correct": true, "elapsed_ms": 5200, "points": 165 }, { "user_id": "usr_bot_1", "correct": false, "elapsed_ms": 7900, "points": 0 } ], "totals": [ { "user_id": "usr_7f3k2a", "points": 165 }, { "user_id": "usr_bot_1", "points": 0 } ] } },
  { "type": "finished", "data": { "result": { "winner_user_ids": ["usr_7f3k2a"], "is_draw": false, "scores": [ { "user_id": "usr_7f3k2a", "rank": 1, "points": 845, "correct": 6 }, { "user_id": "usr_bot_1", "rank": 2, "points": 610, "correct": 5 } ], "xp_awarded": 15 }, "summary": [] } }
]
```

---
### 8.5 Group example (4 players, 3 × 10 s)
The complete scripts with timeout, one disconnect/reconnect, a two-way rank-1 tie, and finish are `fixtures/challenges/group_ws_script.json` (generated and validated with the contract models). Excerpt:
```json
[
  { "type": "player_status", "data": { "user_id": "usr_f1", "status": "joined" } },
  { "type": "opponent_answered", "data": { "question_index": 0, "user_id": "usr_f3" } },
  { "type": "opponent_disconnected", "data": { "user_id": "usr_f2", "grace_ms": 10000 } },
  { "type": "opponent_reconnected", "data": { "user_id": "usr_f2" } },
  { "type": "question_result", "data": { "question_index": 0, "correct_answer": { "option_id": "opt_a" }, "explanation": [{ "type": "text", "text": "…" }], "players": [ { "user_id": "usr_7f3k2a", "correct": true, "elapsed_ms": 5000, "points": 125 }, { "user_id": "usr_f1", "correct": true, "elapsed_ms": 5000, "points": 125 }, { "user_id": "usr_f2", "correct": false, "elapsed_ms": 10000, "points": 0 }, { "user_id": "usr_f3", "correct": false, "elapsed_ms": 7100, "points": 0 } ], "totals": [ { "user_id": "usr_7f3k2a", "points": 125 }, { "user_id": "usr_f1", "points": 125 }, { "user_id": "usr_f2", "points": 0 }, { "user_id": "usr_f3", "points": 0 } ] } }
]
```
