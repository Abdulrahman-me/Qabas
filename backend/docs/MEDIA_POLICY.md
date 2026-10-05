# Build-time media pipeline (Phase 14)

This is production backend code behind explicit approval gates. No image model, TTS model, voice, reciter licence,
style guide, character sheet, scene example, design-token mapping or normative renderer has been approved by this
implementation. The committed [policy](../content/media/policy.yaml) records those pending inputs. An API key
does not approve anything. Synthetic policies are allowed only in dev/test, never in staging or production.

## Factory stages

The contract order is `localize → visuals → scene_author → scene_render → narration → qa → awaiting_gate2`.
These stages execute on the `media` queue; nothing is silently skipped. A missing required input is an explicit
failure/blocker, not an instruction to downgrade a scene to a picture or builtin.

| Stage | Model work | Deterministic work |
|---|---|---|
| `visuals` | Strong Visual Selector; strong Image Prompt Writer; strong pixel-level Visual Auditor | Brief/figure parity, compiled-registry validation, related occurrence groups, maximum three image/audit attempts, resize/encode final WebP, immutable private staging |
| `scene_author` | Strong Animated Scene Author, with complete revision 10 schema, capability limits, approved tokens/style and two reviewed example manifests; image generation/audit for artwork briefs | Assigned scene identity/version, actual asset metadata, bounded SVG/raster validation, complete `scene_check.py`, typed occurrence/point states; at most three corrected manifests |
| `scene_render` | Strong visual audit of the actual rendered frames, in bounded batches | Renderer interface, complete state/time coverage, decoded frames/WebM, state-aligned fallbacks, performance/release evidence; private manifest and preview receipts |
| `narration` | Approved TTS for optional story narration and term pronunciation | Exact language/track/text binding, actual MP3 decode, replay, immutable private staging; scripture/verified quotations never go to TTS |

All language-model calls go through `app/llm` with locked prompts/schemas, structured output, budget accounting
and model provenance. Factory code calls `MediaService` and the `ImageProvider`, `NarrationProvider` and
`ScenePreviewer` protocols; it does not call provider SDKs. The implemented HTTP candidates are OpenAI image
generation/edits and speech. Their selection, exact supported model/native size/voices and distribution terms
remain pending O-03/O-13. CI uses injected deterministic providers and synthetic geometry/tone, not paid calls.

## Appearance and content boundaries

The prompts carry Factory 13.4's flat fills/soft gradients, approved brand palette and consistent setting,
time of day and recurring faceless characters. Approved style/character files and reference artwork are pinned
by digest and supplied to prompting/generation/audit. Related static occurrences reuse one image; typed scene
states retain one setting. Alt text is separately localized and is reviewed with the lesson.

No generated God, prophets, companions, angels, heaven or hell, including symbolic/silhouette substitutes.
Historical Prophet-era backgrounds have no people. No text/calligraphy/scripture in generated artwork or scene
layers. The teaching claims and verified source content remain the authority; image models add no religious
facts. Writer figure metadata must survive selection unchanged. Referenced sacred figures require separately
approved human-authored SVG medallions, bilingual labels, licence and exact registry/artwork digest. The consumer
exists, but no empty registry or fabricated art was committed (D-37). Missing art is an `image_policy` blocker.

Static illustrations are 1600×1000, maps 1600×1200. Approved provider-native dimensions are transformed explicitly
with LANCZOS to those dimensions; final WebP pixels are audited, not the original file or a URL. Actual MIME,
decoded dimensions, byte/pixel limits and hashes are checked. Narration is optional and never autoplays;
the current API carries a nullable URL, not an autoplay flag. Language/track recordings are separate bindings.

## Scenes and the external renderer

Authoring uses the complete `qabas.scene/1` grammar. An in-memory authoring registry permits proposed capabilities
for checking; the production registry is never edited or loosened. Publication uses the real released-capability
registry and the existing `scene_versions`/`scene_assets` identities. Material regeneration gets a fresh scene
identity; reviewed/published bytes are never overwritten. All compiled visual keys/versions remain unchanged.

`InspectionPreviewer` produces real asset-bearing frames, a silent WebM, reduced-motion stills and per-state
fallbacks through resvg/PyAV. It explicitly reports **non-normative inspection**: state cuts and inspection pixels
are not Flutter transition, golden-parity, anchor-visibility or reference-device evidence. It cannot publish.
The complete scene definitions are retained; this renderer is not a lower-quality scene authoring grammar.

`CommandPreviewer` is a bounded JSON stdio bridge for the separately delivered `tools/scene_preview`: approved
absolute executable/launcher SHA-256, exact renderer version, no shell, no inherited credentials, 25 MB transport
limits, timeout/kill/reap, strict response schema. A launcher maps the bridge to the owner's CLI; this repository
does not claim that external CLI exists. Tests exercise a synthetic launcher. Runtime output must cover every
requested state × preview frame time and the still time, with matching view-box dimensions; occurrence and point
states, plus existing exercise binding/evaluation states, are included. Normative output also requires passing
performance and anchor/fallback evidence. Capability release and joint Integration Gate 4 remain external.

## Reference recitation

`app/media/recitation.py` accepts explicit Quran Foundation capability bindings and already licensed recording
bytes; it never downloads a model-provided URL or synthesizes scripture. Canonical ayah/word identity is checked
against the pinned mushaf before cutting. All timings must be valid and cover the canonical words. Cuts use exact
selected word boundaries, reject neighbouring words and preserve canonical positions while rebasing milliseconds.
The cut's original URL/hash, source response hash, reciter name/ID, dataset hash, range, licence and clip hash are retained.
`scripture.insert` and gold verification can mechanically reconstruct the returned capability snapshot; whole-ayah
audio still cannot masquerade as a segment (F-79). The clip receipt must accompany the reviewed bundle before
publication. O-06 approval remains pending. The Exercise Designer's recitation/mapping follow-ups in F-108 are
not declared resolved by providing this clip primitive; no licensed production bindings were fabricated.

## Storage, provenance and review identity

Generated bytes are first written create-only to private content-addressed keys. Receipts bind SHA-256, byte size,
MIME/dimensions, asset class, generation provider/model/parameters/request ID, prompt/audit identities, creation
time, source/transform/style, licence and exact lesson/text/scene binding. Successful jobs and production receipts
are append-only database rows with constraints and insert-only triggers. The same pixels can be reused with
different review provenance; receipt identity is separate from byte identity.

At QA, every receipt is bound to the final package hash. A receipt-bundle hash is included in the contract QA
report, making provenance changes change the Gate 2 review digest even if pixels happen to remain identical.
The digest is calculated from the exact stored draft/report by contract `review.py`. Reviewer clients echo it,
and never compute it from signed transport URLs. Replacing media, editing bound narration or regenerating a
shared occurrence group requires new QA and review. Gate 2 never generates media.

Reviewer URLs are private signed projections with lifetime ≤900 seconds. Asset-bearing scene manifests need
private dependencies too: a private transport copy substitutes signed asset URLs and its SceneRef supplies the
transport hash for the normal loader. Canonical manifest bytes/hash and stored draft/digest remain unchanged;
asset hashes and semantic scene data remain identical. Frames/WebM remain private even after publication.
The review console exposes only revision 10 shapes, not prompts, raw responses or receipts.

Gate 2 reruns content, media, licence, pixel audit, scene registry, hash, text/scene binding and source validators.
**Approve means publish**, in one DB transaction. Verified media are uploaded to immutable content-addressed
`content` keys *before* that transaction commits (F-114). S3 uses conditional `IfNoneMatch=*`; a racing writer
verifies the existing winner instead of overwriting it. Public objects use HTTPS canonical CDN URLs with a
one-year immutable cache header; private objects use `private, no-store`. Published rows are created only after
uploads succeed. An aborted DB transaction can leave unreferenced immutable objects, never a published lesson
waiting for an upload. Retry uses the same bytes. Gold publication also refuses URL-only/unverified media.

## Replay and failures

Each private job is keyed by run, operation and concrete input fingerprint and serialized with a PostgreSQL
advisory transaction lock. No learner/run row lock spans a model/provider call. Durable private checkpoints
recover after a failed DB insert/commit; ready rows replay output and recover model spend without charging it
twice. Stage completion checks the current revision/regeneration fence, preventing an older attempt from
attaching media to a newer draft. Reviewer regeneration archives the previous draft/report before clearing its
digest and restarting the required media stages. Writing revisions discard prior selection/regeneration controls.

HTTP connect timeout is 5 s, media timeout defaults to 120 s, with two full-jitter retries only for transport,
429 and 5xx, and the existing provider/process circuit breaker. Refusal, malformed response, wrong format/hash,
missing approval and storage failure stay distinct failures. No URL fetch or fabricated asset fills the gap.
There is an unavoidable window between a provider response and durable checkpoint creation: a worker crash
there may repeat a paid generation. This code guarantees replay of durable work and exactly one accepted
production effect, not exactly-once provider billing. Unreferenced object/transport/checkpoint retention and
operator cleanup remain part of Phase 21's approved retention/hosting work; nothing published is deleted here.
Missing objects, immutable-key conflicts and temporary storage outages are classified at the media I/O boundary;
SDK details do not become QA messages. Review-frame and learner-fallback paths are distinct even for identical pixels.

## Current release state

No real lesson became publishable. Remaining inputs include approved O-03 model/provider/media terms,
O-05/O-13 gold/style/characters/references, actual human medallion art, scene tokens/two reviewed manifests,
O-02 normative renderer/capability release and joint Integration Gate 4, and O-06 licensed recitation.
O-12 curriculum decisions, D-93 English Quran translation selection, F-116 live source re-fetch policy and
earlier Unit 0 decisions remain open. These gates are not replaced by test geometry, tones or synthetic approvals.
Phase 14 remains in progress until its real-art requirement and acceptance dependencies are satisfied.
