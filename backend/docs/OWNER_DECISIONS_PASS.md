# Owner decisions: backend pass (2026-10-06)

This follows Phase 20; it is not Phase 21's broad hardening audit. The owner subsequently
confirmed that frontend/backend linking is deferred and no live provider configuration or
licensed reciter files are available locally. Backend engineering, product approval,
specialist approval and live acceptance remain distinct.

## Implemented pilot behavior

* Raqeeb original uploads: seven days **after message processing completes**, then the
  existing receipt cleanup deletes bytes and leaves extraction/history with null attachment
  URLs. Failed admission objects still expire after one hour. Conversation/account deletion
  retains its existing stronger purge. Quran recitation-check audio is never persisted.
* P-01: training league members are opt-in in production as well as staging. Every such
  member's `display_name` carries `منافس تدريبي` / `Training Opponent`, including private
  profiles. Revision 10 remains unchanged; no undocumented response flag was added.
  They remain unable to authenticate, befriend, receive achievements or count in learner
  metrics. Enable `SYNTHETIC_LEAGUE_MEMBERS=true`, migrate and run the existing seed;
  the existing beat job handles deterministic, replay-safe activity.
* `content/learner_copy.json` holds the owner-approved bilingual review labels and short
  AI, external-processing, seven-day upload, guest-loss and training-opponent disclosures.
  The frontend must bundle/display this copy when linking resumes. This is not a new API
  endpoint or evidence that any Android screen has already been verified.
* The five rewarded eligible challenges per learner/local day and promotion-without-demotion
  rules are now owner-approved pilot behavior. Extra challenge play remains available.
  Corrected achievement wording `فُز` already exists in `registries.json`.

## Curriculum inventory and bounded admission

The registered curriculum has 93 slots: units 0–10 contain 12, 6, 7, 9, 7, 8, 8, 8, 10, 8, 10.
Inventory must precede generation. Run against the intended application database, never
substitute the test database's fixture lessons for real content:

```powershell
python scripts/curriculum_batch.py inventory --output .private/content/inventory.json
python scripts/curriculum_batch.py enqueue --unit unit_0 --reviewer-id <existing-reviewer-id> --lesson-type concept --limit 1
```

The operator explicitly selects the lesson's primary type; the brief only projects the
existing working slot metadata and constraints. Existing authored versions and attempted
runs are skipped, not overwritten. A database admission lock bounds concurrent batch
operators to four running candidates, and the existing active-slot constraint still applies.
Each run uses the existing token budget and Factory stages, source/model/media abstractions,
QA, provenance and review digest. Missing model configuration is rejected before mutation.
Run the factory/media workers with bounded concurrency (one is appropriate for this pilot).

The inventory exposes registered/scaffold/content/review/publication state and the exact
run status/stage, review digest, error and QA issues. `queued` means a durable pending stage;
it is an operator projection, not a new contract state. Gates remain `awaiting_gate1` and
`awaiting_gate2`; a reviewed final draft still requires normal Gate 2 validation and atomic
approval/publication. Inventory is not itself a publication approval.

Admission commits before dispatch, as in the existing Factory path. If dispatch fails,
the durable run remains visible and the command prints its ID without broker credentials:

```powershell
python scripts/curriculum_batch.py resume --run-id <run-id> --reviewer-id <existing-reviewer-id>
```

This only redispatches the current pending stage. It does not reset a running/failed stage,
approve gates or revise content. Worker-crash redelivery and explicit failed-stage recovery
remain the established Factory mechanisms. Re-inventory before processing the next unit.

The inspected local development DB has 93 slots, zero lesson versions and zero Factory
runs; it is still at migration 0008 and has no active reviewer. Test databases are separate
and migrate through 0014. Do not present the old development schema as a deployed service.
The private Unit 0 source has 12 authored drafts, all blocked by the actual converter:
168 unmapped tool references, 187 missing bilingual plan fields, 34 concept references,
66 unpublished scene uses, 31 source bindings and 18 claim-link placement issues.
No draft was generated/imported/published during this pass because live credentials are absent.
Unit 0's starting position is owner-approved; its Explorer-only membership is preserved.
Changing track membership would require a separate explicit curriculum amendment.
The Salah reference remains internal/test-only; it is not promoted into slots 3.1/3.2.

## Feature verification and boundaries

| Feature | Existing backend behavior | Remaining delivery dependency |
| --- | --- | --- |
| Onboarding | Learning track and curiosity choice; no religion stored/inferred (AD-33) | Actual client screens/approved bridge copy |
| Roadmap/Discover | One canonical lesson; Discover uses standalone eligibility, bypassing journey prerequisites | Published real content |
| Fourteen exercise types | Deterministic grading, hidden server keys, pinned session content | Client/player integration |
| Quran recitation | Local `tarteel-ai/whisper-base-ar-quran`, CTranslate2; never-persisted learner audio | Licensed reference files/device acceptance |
| Raqeeb voice | Separate hosted Whisper large-v3 STT; original private upload plus extracted transcript | Configured STT and real processing terms |
| Images/camera | Bounded image uploads; camera output uses the same image intake | Client camera capture |
| PDF/DOCX | Bounded isolated extraction/OCR and model summary | Configured approved models/storage |
| Raqeeb eight classes | Trusted-source binding, canonical scripture, uncertainty, abstention and referrals | Real provider approvals/evaluation |
| Personal fatwas | Protective referral to approved authority; no independent personal ruling | No automatic internal specialist case queue is specified/implemented |
| Factory | Plan → Gate 1 → generation/source/media/QA → Gate 2 atomic publish | Models, media/source bindings, active specialist |
| Community/challenges | Friends, leagues, achievements, async/live durable coordinator and one reward path | Actual app/hosting acceptance |

An external referral is not a promise that an internal reviewer has received the question.
Do not advertise an internal scholar inbox without implementing a separately agreed workflow.

## Organizer acceptance and unresolved receipts

Both supplied organizer PDFs were reviewed completely (44-page participant guide and
15-page scientific package). The official scientific behavior cases (page 6) are the core
pilot acceptance basis; the canonical/source-authority requirements and terminology table
remain authoritative. The guide also requires a working public demo, public non-secret
repository, source/licence documentation, a presentation and a video no longer than two minutes.

Private preparation contains 24 organizer-derived Arabic/English candidates and 24 hidden
paraphrases. They are **pending specialist review**, not accepted gold or benchmark results.
Two generic scenarios need concrete canonical inputs; verified source refs and the full
Phase 17 bilingual/eight-class/adversarial/input coverage still need completion. Hidden
material never enters prompts or the public repository. Genuine live evaluations run: zero.
No release score, critical-failure count or genuine metrics row is fabricated.

The existing benchmark runner/judge/release evaluator remains the sole path. Zero tolerance
for fabricated scripture/grades, unsafe fatwa overreach and false protected reuse is owner
confirmed. The proposed 90% accuracy / 2% unsupported / 80% agreement numerical thresholds
remain unapproved; organizer-example strategy approval does not implicitly approve them.

O-03 model/source/cache terms, O-09 actual provider processing/deletion receipts, D-93 English
Quran selection, specialist source/gold approvals, actual renderer/assets/licence receipts
and private benchmark sign-off remain gates. Owner permission for a configured external
provider is not a claim that provider terms have been verified. Upload/STT policy manifests
therefore retain pending operational approval even though the seven-day choice is settled.

Frontend linking, APK, public web and Render acceptance were expressly deferred by the owner
until backend completion. A simple Render deployment with PostgreSQL/Redis and the existing
coordinator is permitted; no live hosting was provisioned or claimed during this pass.
Reviewer MFA, extra guest verification, iOS distribution, account recovery, multi-region HA,
global legal/age/residency decisions, provider migration and general learner video are deferred.
No existing durable, source, privacy or publication safeguard was removed.
