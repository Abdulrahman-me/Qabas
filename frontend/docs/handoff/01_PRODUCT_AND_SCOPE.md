# 01 — Product and scope

## What Qabas is

Qabas (قبس, "a small flame carried to give light and warmth") helps people learn Islam step by step, **from their first question to real understanding**. It is for two audiences:

| Track | Who | Starts with | Tone |
|---|---|---|---|
| `explorer` | People exploring Islam | Unit 0 "Start With a Question" (Explorer-only foundation: observation and evidence, a Creator, guidance, revelation, the messenger) | Attributed wording ("The Qur'an describes…", "Muslims believe…"), no presupposition, no pressure |
| `new_muslim` | People who have already accepted Islam | Unit 1 "The First Step" | Direct, warm, personal ("Allah tells us…") |

Onboarding also offers **"Prefer not to say"** (`undisclosed`), which the backend treats as explorer. After Unit 0 both tracks share **one canonical curriculum, Units 1–10**, with per-track variants of the same lessons; completion belongs to the lesson, so switching track keeps progress (`docs/contract/01_PRODUCT/CURRICULUM_AND_LEARNING_DESIGN.md`). Onboarding never asks, records or infers anyone's religion, and exercises never grade personal belief.

The experience is calm, welcoming, respectful, discreet and grounded in sources you can trace. Arabic and English are the launch languages, and Arabic is fully right-to-left.

**Platform requirement (owner, 2026-10-04):** the learner app must also run responsively on web. This applies to each phase as its screens are built, alongside native mobile fidelity. Support narrow browser windows, tablet and desktop widths, landscape and window resizing in both languages; use the constraints and verification matrix in [03 §4](03_DESIGN_SYSTEM.md). Web is not deferred to Tier C.

Taglines (already in the prototype's strings): *Learn Islam step by step, from your first question to real understanding.* / *تعلّم الإسلام خطوة بخطوة، من أول سؤال إلى فهم متين.*

## The four parts of the product

1. **Journey and lessons.** A winding path of units and short lessons. Lessons combine a real-life hook, a prediction, illustrated stories, teaching cards with evidence, varied interactive exercises, listen-and-recite, and a completion with mastery and a small real-life challenge. Unfamiliar terms are underlined and open an explanation; they feed a personal glossary and spaced review.
2. **Raqeeb (رقيب).** A source-based assistant for questions, explanations and authenticity checks. It cites sources and abstains or refers to a specialist when appropriate. Identity: a lantern. It is separate from the companion character.
3. **Community.** Streaks, daily quests, achievements, a weekly league (promotion only, no demotion zone), friends, and friendly challenges (duel and group live quiz).
4. **Reviewer tools.** The content factory console (two human gates, blind tests, metrics). It is not part of the learner app's demo.

The **companion** (a faceless traveller in an emerald cloak carrying the ember) is an optional, replaceable Flutter/Rive character that reacts to what happens: greets, encourages, celebrates. It is never part of the API.

## Full app scope (screens)

IDs come from `docs/contract/04_FRONTEND/FRONTEND_HANDOFF.md` §2 so you can cross-reference it. The tiers are explained below.

| ID | Screen | Tier | Prototype source |
|---|---|---|---|
| S1 | Splash and bootstrap (guest auth, `401` recovery, `426` update screen) | A | `features/splash/splash_screen.dart` |
| S2 | Onboarding: 7 pages, plus the curiosity page (built, off in the demo) | A | `features/onboarding/onboarding_flow.dart` |
| S3 | Journey (Roadmap): Today card, Review card, node popovers, Soft Lock sheet, path switcher, unit guide sheet | A (Review card, guide: B) | `features/journey/journey_screen.dart`, `journey_widgets.dart` |
| S22 | Discover (bottom-bar tab 1, replacing the Review tab): standalone lessons grouped by unit | A | none; built from the prototype's review-hub and community layouts |
| S4 | Session player (lesson; review/pretest/unit test kinds) | A for lesson, B for other kinds | `features/lesson/lesson_screen.dart`, `steps/`, `exercises/` |
| S4a | Lesson intro | A | `features/lesson/lesson_intro_screen.dart` |
| S5 | Lesson complete / session result | A | `features/lesson/lesson_complete_screen.dart` |
| S5b | Streak celebration (after completion when the streak was extended) | A | `features/streak/streak_screen.dart` |
| S6 | Lesson reader (re-read a completed lesson) | B | reuse step views, no exercises |
| S7 | Sources drawer | A | sources sheets in lesson / Raqeeb |
| S8 | Term card sheet | A | `widgets/term_text.dart` (`TermSheet`) |
| S9 | My glossary ("Your words", opened from Profile) | B | `features/review/review_screen.dart` (words section) |
| S10 | Raqeeb conversations list | B | new list in the Raqeeb visual language |
| S11 | Raqeeb chat | A | `features/raqeeb/raqeeb_screen.dart` |
| S12 | Profile, settings, about, delete account | A (delete: B) | `features/profile/profile_screen.dart`, `features/settings/*` |
| S13 | League | B | `features/community/community_screen.dart` |
| S14 | Friends (list, invite, accept, remove) | B | community screen friends section |
| S15–S17 | Challenge lobby, live play, result | B on the fake socket; live socket C | `features/community/live_challenge_screen.dart` |
| S18 | Streak calendar | B | `features/streak/streak_screen.dart` |
| S19 | Daily quests | B | community screen quests |
| S20 | Achievements | B | `features/profile/achievements_screen.dart` |
| S21 | Card review session (flip cards), opened from the Journey's Review card | B | `features/review/review_session_screen.dart` |
| — | Generated scene renderer (`packages/qabas_scene`): every Unit 0 visual is an animated scene | A | none; the prototype only has hand-coded builtin scenes |
| — | Blocking update screen (`426`) | A | new, in the night-sky style of splash |
| R1–R6 | Reviewer console (sign-in, runs, Gate 1/2, blind test, metrics dashboard): same design language, no gamification | B (Phase 14) | none; built from the design system, two-pane on tablet/web |

## Tiers for the two-day build

| Tier | Meaning | What must exist |
|---|---|---|
| **A — must demo** | Core learner flow at full prototype fidelity, in mock mode and wired to live as soon as each endpoint exists | Finished UI, BLoC, use cases, repository, mock handler, live data source, ARB in en + ar, loading/empty/error states, companion reactions |
| **B — should** | Next most valuable screens; build after Tier A is solid | Same bar as A. It is fine to ship with mock data if the backend endpoint is late. |
| **C — architecture-ready** | Required by the full product, not by the demo | Interfaces, routes and safe fallbacks so the feature can be added later without restructuring. No dead UI buttons: hide entry points instead. |

Tier A flow (the demo spine): **Splash → onboarding (7 pages, Explorer) → journey (Unit 0) → lesson intro → lesson 0.1 with live animated scenes → completion → streak celebration → journey updated (0.2 unlocked; Soft Lock on later lessons) → Discover (lesson 1.1) → Raqeeb question and answer → language switch to Arabic (live RTL)**. The Salah reference lesson is opened only from the developer menu (backend reply, 2026-10-04: it keeps its legacy fixture IDs and is not part of the published journey).

What sits in Tier C and why:

- **Real-time challenge socket against the live backend**: build the socket adapter to the protocol (API §8), test it against the fake socket, and connect it live only if the backend's coordinator is ready.
- **Async duels, release-bundle CI scan.**
- **Raqeeb's lantern as a Rive animation and more guide characters cast per lesson** are scheduled as Phase 16, after the demo.

**Demo-build decisions (owner, 2026-10-04):** the "Review draft only" notices in the Unit 0 drafts are hidden; no "mock" or "demo" labels are shown; the curiosity onboarding page is switched off; recitation shows its unavailable state and skip (no checker or licensed audio exists, and a pass is never simulated).

## Explicitly out of scope (do not build)

From the product requirements: per-user generated lessons, free-text answer grading, personal fatwa generation, Quran memorisation/tajweed modes, learner-to-learner chat, **push notifications**, languages beyond ar/en, prayer-time calculation/location/clock services, URL inputs or device-audio listening in Raqeeb, photo or avatar uploads, account linking or recovery. The backend stores **no** companion behaviour and **no** local preferences (sound, haptics, reduced motion, discreet reminders, story/reveal progress).

## Product decisions with defaults

These are open product decisions (`docs/contract/00_REVIEW/STATUS_AND_OPEN_DECISIONS.md`). Implement the default; don't block on them.

| ID | Question | Client default |
|---|---|---|
| P-01 | Synthetic league members | Render whatever the server sends; never fabricate members client-side |
| P-02 | Guests have no account recovery | Accept. On `401`, explain gently that the session ended and start a new guest (no loop) |
| P-03 | League week is Sunday–Saturday in Asia/Riyadh | Show `ends_in_seconds` from the server; never compute week boundaries locally |
| P-04 | Legal/privacy baseline | About page states content is pending specialist review and that questions are processed by AI services; no other legal UI |
| P-05 | Raqeeb release thresholds | Backend concern; client renders every class, abstention, referral and failure |
| P-06 | Raqeeb daily cap, 4-character friend codes, blocking update screen | Show `429` with retry time; accept codes as entered (trim, uppercase); the `426` screen blocks |
| P-07 | How the Salah reference is used in production (it spans curriculum slots 3.1 and 3.2) | Keep it as the UI-fidelity fixture (`les_u1_l3`/`unit_1`), opened only from the developer menu; never on the journey or in Discover |
| P-08 | Learner-facing video | None: visuals are builtins, images and declarative scenes |

## Content and imagery policy (binding on every screen)

- No depiction of God, prophets, historical companions, angels, paradise or hell: no faces, bodies, silhouettes or symbolic human shapes for them.
- Ordinary modern people (the companion, avatars) have **completely blank faces**.
- Illustrations contain no letters, names, calligraphy or scripture. Text is drawn by Flutter as UI or approved overlays (calligraphy medallions are separate approved SVG overlays).
- Quran text is `text_uthmani` rendered verbatim in the Quran font (`AmiriQuran`), always RTL even in the English UI, never truncated mid-ayah, never stylised. Quran audio comes only from the reciter file in the payload and is never TTS.
- Honorifics (ﷺ, عليه السلام) are rendered as sent.
- Mistakes are met warmly: "not quite" uses warm clay, never alarming red. The flame guides; it is never aggressive fire.
- Avoid neon, mystical effects, crescent-and-star or mosque-silhouette clichés, and loud gamification.
- Every religious claim shown comes from the backend with its source. The client never generates or edits religious content.
