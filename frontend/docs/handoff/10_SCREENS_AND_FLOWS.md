# 10 — Screens and flows

For each screen: the route, prototype source and screenshots, the BLoC, use cases, endpoints, states and character placement. Visual details always come from the prototype file named. The session player has its own document ([11](11_SESSION_PLAYER.md)). Tiers (A/B/C) are defined in [01](01_PRODUCT_AND_SCOPE.md). The standard loading/empty/error patterns are in [12](12_STATES_AND_ERRORS.md).

## The demo spine (Tier A)

What the judges see (run with `config/demo.json`):

```
Splash ─► (no token) POST /auth/guest ─► Onboarding ×7 (Explorer) ─► POST /onboarding ─► Journey (Unit 0)
   └────► (token) GET /me ─► onboarding_completed ? Journey : Onboarding
Journey ─tap 0.1─► popover ─Start─► Lesson intro (POST /sessions) ─► Session player: lesson 0.1 with live animated scenes
   ─► POST …/finish ─► Lesson complete ─► Streak celebration ─► Journey (0.1 done, 0.2 unlocked; tap 0.3 → Soft Lock sheet)
Discover tab ─► lesson 1.1 ─► same lesson player
Raqeeb tab ─► ask ─► stage indicator (poll) ─► sourced answer
Profile ─► Settings ─► Language: العربية ─► whole app switches to RTL instantly
```

The Salah reference lesson is not part of this flow: it opens only from the developer menu (A-23). The draft notices are hidden and nothing is labelled as mock (owner decisions, 2026-10-04).

---

## S1 · Splash and bootstrap — Tier A

- **Route** `/splash` (initial). **Prototype** `features/splash/splash_screen.dart` (dotted path draws up toward a flame that kindles; logo; tagline).
- **BLoC** `AppSessionBloc` (app-wide). Events: `AppStarted`, `GuestSessionRequested`, `SessionEndedAcknowledged`, `AuthEventReceived`. Status: `unknown → authenticating → needsOnboarding | ready`, plus `sessionEnded`, `outdated`, `failure`.
- **Use cases** `LoadCurrentUser` (`GET /me`), `CreateGuestSession` (`POST /auth/guest`, stores the token), `ClearSession`.
- **Behaviour** Play the prototype animation while bootstrapping. Navigate when **both** the animation's minimum duration and bootstrap are done. Warm up the character file and sounds during the splash (as the prototype does in `main.dart`). Error: stay on the splash with an error line and a Retry button. Never loop.
- **426** → `/update-required`: night sky, flame mark, title, body, gold button opening the store URL from `AppConfig` (strings in ARB).
- **401 later in the app** → the "Your session ended" sheet (companion `encourage`, Continue) → new guest → onboarding.

## S2 · Onboarding (7 pages; 8 with the curiosity page) — Tier A

- **Route** `/welcome`. **Prototype** `features/onboarding/onboarding_flow.dart`; screenshots `01`–`08`.
- **Pages** (1) language (English / العربية); (2) welcome (companion hero, tagline); (3) who: *curious about Islam* (`explorer`), *recently embraced Islam* (`new_muslim`), plus **"Prefer not to say"** (`undisclosed`; new, styled as a third `_NightOption`); (4) familiarity none / some / good; (5) daily goal 5 / 10 / 15 / 20 min (`_Bars`); (6) privacy: private profile (default on), discreet reminders (local only); (7) ready ("your path is ready").
- **Curiosity page** (new, built in Phase 3, **off in the demo** via `CURIOSITY_ONBOARDING=false`): page 4, "What would you most like to understand?", with the six goal anchors as `_NightOption`s (skippable). After a choice, the bridge text for that anchor × track × language. Copy comes from `assets/onboarding/curiosity.json`, not ARB: it is reviewed product content, and most of it is still `null`. The page is shown only when the flag is on **and** the question and all six labels exist in the current language; a missing bridge is skipped. The choice is `goal_anchor`; it never changes the start unit or order, and nothing about religion is asked or inferred. Companion: `correct` on a choice.
- **BLoC** `OnboardingBloc`. State: `page`, `language`, `trackChoice?`, `goalAnchor?`, `familiarity?`, `dailyGoal`, `privateProfile`, `discreetReminders`, `submitting`, `failure?`. Events: `PageAdvanced`, `PageBack`, `LanguagePicked`, `TrackPicked`, `FamiliarityPicked`, `GoalPicked`, `PrivacyToggled`, `RemindersToggled`, `OnboardingSubmitted`.
- **Language** applies **immediately** through `LocaleCubit` (the rest of onboarding renders in that language and direction).
- **Submit** on the last page: `CompleteOnboarding` → `POST /onboarding {track_choice, language, familiarity, daily_goal_minutes, private_profile, goal_anchor}` (`goal_anchor` is `null` when the page is off or skipped) → `AppSessionBloc` gets the updated user → the router goes to `/journey`. Discreet reminders are saved to `PreferencesStore` only. Pages 2, 6's reminders and 7 send nothing.
- **Character** (guide): `greet` on appear; who → `correct`; familiarity → `encourage`; goal and privacy choices → `correct`; ready page → `celebrate` + `Sensory.complete`. Speech bubbles (`SpeechBubble`) with the prototype's wording. The hero character is large on pages 1, 2 and 7, small on question pages (zoom 1.4).
- **Errors** submit failure → inline error above the button with Retry; the answers are kept.

## S3 · Journey (Roadmap) — Tier A

- **Route** `/journey` (shell tab 0, night-toned bottom bar). **Prototype** `features/journey/journey_screen.dart`, `journey_widgets.dart`; screenshots `09`, `10`, `38`, `57`.
- **BLoC** `JourneyBloc`. State: `status`, `journey`, `nextStep`, `stats` (for the chips and Today card), `openPopover?`, `refreshing`, `failure?`. Events: `JourneyRequested`, `JourneyRefreshed`, `NodeTapped`, `PopoverDismissed`, `TrackSwitchRequested(track)`. It refreshes on `SessionCompleted` and `ProfileChanged`.
- **Use cases** `GetJourney` (`GET /journey`), `GetNextStep` (`GET /journey/next`), `GetStats` (`GET /me/stats`), `UpdateProfile(track)` (`PATCH /me`).
- **Layout** (keep the prototype exactly): app bar with the path chip (track name + switch sheet) and stat chips (streak `current`, embers = `xp_total`); the night sky brightening toward dawn as progress grows; **Today card** (next step title + "Continue", daily goal progress `minutes_today / minutes`); one `UnitBanner` per unit (title, subtitle, art from `art_key`, guidebook button when `has_guide`); the winding dotted `JourneyPathPainter` path; nodes by type (concept lesson → flame, story → book, practice → practice glyph, unit test → lantern checkpoint); the current node with the bobbing **START** bubble and the companion standing beside it (`greet`); `coming_soon` units dimmed; the horizon at the end ("The path keeps unfolding").
- **Access is by prerequisites, not position** (API §6.3). A lesson later in the path can be `available` while an earlier one is `locked`; render exactly the server's `state`.
- **Node states** `locked` (dim; tapping opens the **Soft Lock sheet**), `available`/`in_progress` (tappable), `completed` (lit). The current node is `journey.current`. A unit in `skipped` state renders as completed.
- **Soft Lock sheet** (new; `showQSheet` in the quit-sheet style, companion `encourage`): a warm explanation that one earlier idea makes this lesson easier, the `soft_lock.prerequisites` titles, and a primary button opening `soft_lock.start_with` (its intro). No "skip lesson" action, ever. The same sheet appears when `POST /sessions` returns `409 prerequisite_unmet` (built from `details.prerequisite_lesson_ids` and `details.start_with_lesson_id`, with titles looked up in the cached journey).
- **Review card** (new, where the old Review tab's deck went): below the Today card, shown only when `next_step.due_reviews_count > 0`, in the prototype review deck's style ("N cards are ready", "Start review"). It opens the card review (Phase 12).
- **Track membership:** Explorers see Unit 0 (Explorer-only) and Units 1–10; New Muslims see Units 1–10. Switching to New Muslim removes Unit 0 from the journey and keeps every completed lesson.
- **Popover** (`_Popover`, anchored): kind chip, lesson title, `estimated_minutes`, `+xp embers`, then "Start lesson" → `/lesson/:lessonId/intro`. Unit test checkpoint: "Take the unit test" (Tier B) and "Skip unit" when `can_skip`. Units without unit tests in the data (`can_skip=false`) show no test or skip action.
- **Path switch** → `UpdateProfile(track)` → refetch the journey (progress is kept server-side).
- **Unit guide sheet** (Tier B) → `GET /units/{id}/guide` → sections of sentences with terms (SpanText) and sources.
- **States** loading: night sky + quiet flame shimmer of nodes (no spinner); empty (no units): companion + "Your path is being prepared" + Retry; error: night-toned error card + Retry, keeping the sky.
- **Invitations badge** (Tier B): poll `GET /duels/invitations` every 15 s while visible.
- **Demo data:** `assets/mocks/demo_curriculum/curriculum.json`: Unit 0 (12 lessons, Explorer only; 0.1 open, the rest behind Soft Locks), Unit 1 (lesson 1.1, standalone), Units 2–10 coming soon. Coming-soon units with no approved Arabic title show their English working title (A-30).

## S22 · Discover — Tier A (bottom-bar tab 1)

- **Route** `/discover` (shell tab index 1; it replaces the prototype's Review tab). No prototype screen: design it from the prototype's review-hub and community layouts (light background, `SectionHeader` per unit, `QCard` lesson rows with the journey's node glyph, title, minutes and `+xp`, a completed tick).
- **Data** the same `GET /journey` response: lessons with `standalone_eligible = true`, grouped by unit, completed ones marked. One general notice at the top: some lessons normally come later in the path, and earlier units can make them easier. No other copy varies by surface.
- **BLoC** `DiscoverBloc` over `GetJourney` (shares the journey repository cache); refreshes on `SessionCompleted` and `ProfileChanged`.
- **Opening a lesson** goes to exactly the same route and `POST /sessions {kind: lesson, lesson_id}` as the journey: same player, version, wording and exercises. Completion shows on the Journey too.
- **States** loading skeleton rows; empty: companion + "New lessons to explore will appear here" (with a button to the Journey); error: `QErrorView`.
- **Demo data:** only lesson 1.1 is standalone, so Discover shows that one lesson.
- **Tab icon:** a Material Rounded filled/outlined pair that reads as "explore freely" and differs from the Journey's compass (for example `travel_explore`); confirm it with the owner in the Phase 4 screenshots.

## S4a · Lesson intro — Tier A

- **Route** `/lesson/:lessonId/intro`. **Prototype** `features/lesson/lesson_intro_screen.dart`; screenshot `11`.
- **BLoC** `LessonIntroBloc`: `StartLessonSession(lessonId)` → `POST /sessions {kind: lesson, lesson_id}` (200 = resume an active session, 201 = new). It also reads the unit/lesson index, `estimated_minutes` and `xp` from the cached journey.
- **Shows** title, subtitle, unit and lesson index, minutes, reward, **interactions = `counts.interactions`**, objectives, **sources = `source_count`**, the "specialist reviewed" badge when `reviewed_by` is set (`_TrustRow`), the companion (`greet`, size 150, aspect 0.78, zoom 1.25), and a "Start" button → `/session/:sessionId`. For a resumed session the button reads "Continue".
- **Empty facts are hidden, not shown as zero:** when `source_count` is 0 (every Unit 0 draft) the sources figure and the sources drawer entry are hidden; when `reviewed_by` is null the specialist badge is hidden. `409 prerequisite_unmet` from `POST /sessions` opens the Soft Lock sheet (S3).
- **States** loading: layout skeleton with the companion; error: retry card.

## S4 · Session player — Tier A (lesson), B (review / pretest / unit test)

See [11_SESSION_PLAYER.md](11_SESSION_PLAYER.md).

## S5 · Lesson complete / session result — Tier A

- **Route** `/session/:sessionId/result`. **Prototype** `features/lesson/lesson_complete_screen.dart` (`_StatTile`, `_MasteryCard`); screenshot `36`.
- **BLoC** `SessionResultBloc`: loads the `SessionResult` cached by the session repository, or calls `FinishSession` again (idempotent: it returns the stored result).
- **Shows** (lesson kind) the companion `complete` with the ember glow; "Lesson complete!" (`QText.display`); three count-up tiles **Embers = `xp.total`**, **Accuracy = `score.percent`**, **Time = `duration`**; the mastery card with **Understanding** and **Applying** bars from `layers` and **Remembering** as the "In review" placeholder; "Coming back in review" with `completion.review_topics` and their timing chips; "Today's small challenge" (`completion.challenge`) and "Tomorrow we'll ask" (`completion.check_in`); "Next on your path" from `next_step`; a gold Continue button.
- **Continue** → if `streak.extended_today` → `/streak?celebrate=1`; otherwise `/journey`. Publish `SessionCompleted` and `TermsMastered(result.termsMastered)` on the event bus when the result arrives.
- **Other kinds**: review → score, XP, streak, next step; pretest → a thank-you and the next step (no score); unit test → pass/fail against `pass_percent`, XP, unlocks and the `review_items` answer review list.

## S5b · Streak celebration — Tier A · S18 Streak calendar — Tier B

- **Route** `/streak` (`?celebrate=1` from the result). **Prototype** `features/streak/streak_screen.dart` (`_RollingNumber`, `_WeekRow`, `_DayDot`, `_MonthCalendar`); screenshot `37`.
- **BLoC** `StreakBloc`: `GetActivity` (`GET /me/activity`, the last 35 days by default) and the streak from the session result or the stats.
- **Celebration** rolls the number from `current − 1` to `current`, lights today's dot in the week row, plays the companion `streak` + `Sensory.streak`, and shows the "keep your flame warm" text plus the "Rest days" explanation. **Calendar** (from Profile): the last five weeks with qualifying days.

## S6 · Lesson reader — Tier B

`/reader/:lessonId` → `GET /lessons/{id}`: the same block views as the player with exercises removed and `predict` shown with its reveal; teach cards show all points; stories are navigable by beats. No progress bar or feedback.

## S7 · Sources drawer · S8 Term card — Tier A

- **Sources drawer** (`showQSheet`): every `Source` of the current lesson/session, displayed ones first ("مصادر هذا الدرس" / "Sources for this lesson"), with kind, title, reference, excerpt and an "Open" link when `url` is set. **Long-press any sentence** → a mini sheet with only that sentence's `source_ids`.
- **Term card** (`TermSheet` in `widgets/term_text.dart`): eyebrow "Your dictionary", the level tag, heading (`text`), transliteration, **canonical Arabic** (`arabic`: Amiri 34/1.3 RTL, omitted when null), definition, example, source reference, pronunciation play button when a URL exists, and "Learn more" → the lesson. On open: `MarkTermOpened` (fire and forget).

## S9 · My glossary ("Your words") — Tier B

Opened from the **"Your words" row in Profile** (it moved there from the old Review tab). `/glossary` → `GlossaryBloc` with filter chips all / new / learning / mastered (`GET /glossary?state=`), cursor paging, a `RingProgress` mastery ring per term (prototype review screen "Your words"), and tap → term sheet. Empty state: "Words you meet in lessons will appear here."

## S21 card review — Tier B (there is no Review tab any more)

- **Entry**: the Journey's **Review card** (S3), shown when `next_step.due_reviews_count > 0`, styled like the prototype's review deck card (`features/review/review_screen.dart` `_DeckCard`, screenshot `39`). "Start review" → `StartReviewSession(cards)` → `/review/session/:id`. `409 nothing_to_review` → the card disappears and a snackbar says "All caught up".
- **Card review** (prototype `review_session_screen.dart`, screenshots `40`–`42`): 3D flip cards (`flashcard` exercises), then rating buttons Again / Hard / Good / Easy → `SubmitAnswer({rating})` → next card; then finish → "Review complete" with the companion `celebrate`. **Intentional difference:** the prototype shows fake interval hints under the ratings ("1 min, 1 day…"). The contract provides no intervals, so production shows the rating labels only. Note this in the PR.
- **Quick review** (`mode: quick`): a session with a 20 s draining timer per exercise (colour shifts to clay in the last 5 s); timeout submits `answer: null`.

## S10 · Raqeeb conversations — Tier B · S11 Raqeeb chat — Tier A

- **Routes** `/raqeeb` (tab: latest conversation, or the welcome state), `/raqeeb/c/:id`, `/raqeeb/history`. **Prototype** `features/raqeeb/raqeeb_screen.dart`; screenshots `43`–`46`.
- **BLoC** `RaqeebChatBloc`. State: `conversation?`, `messages` (user + assistant), `composer` (text, attachments, recording state), `assistantActivity` (idle / recording / processing / answering), `pendingMessageId?`, `stage?`, `failure?`. Events: `ComposerChanged`, `AttachmentAdded/Removed`, `RecordingStarted/Stopped`, `MessageSent`, `SuggestionTapped`, `RetryRequested`, `AnswerRated`, `ConversationOpened`.
- **Flow** On the first send, create the conversation (`StartConversation`, optional lesson context when opened from a lesson), then `SendRaqeebMessage` (multipart, a new `Idempotency-Key`) → show the user bubble immediately → `WatchAssistantMessage` polling → stage label + subtle animation (`_TypingDots` style; **never an unlabeled spinner for more than 1 s**) → completed answer. The composer is disabled while an answer is processing (`409 answer_in_progress`).
- **Welcome state** (prototype `_Welcome`): lantern identity, "Your trusted guide to reliable answers", the four trust points, and "Try asking" suggestion chips (bundled ARB questions sent as text).
- **Answer rendering** (prototype `_AnswerBubble`, `_CitedText`, `_SourceCard`, `_VerificationCard`, `_SpecialistCard`): a collapsible "What I understood from your message" row (transcript, image text, document summary); the classification chip (`classification.label`); blocks in order: paragraph (SpanText with `citation` superscripts → scroll to the source and `term` underlines → term sheet), evidence card, verification cards (status palette from [03](03_DESIGN_SYSTEM.md) §2, `not_found` never styled as fabricated), differing views (intro + views with holders), referral card (calm, target name, description, "Open" when `url` exists); numbered citations list; "Learn more" lesson chips → lesson intro; thumbs up/down → `RateAnswer`.
- **Failed** (`status: failed` or the 90 s timeout): a gentle error bubble with "Try again" (a new message and key).
- **Attachments** (Tier B): image (up to 3, gallery or camera), document (PDF or DOCX, 1), voice (hold or tap to record, 60 s max with a timer; the character is `listening` while recording). Validate the §7 limits in [05](05_NETWORKING_AND_API.md) before sending.
- **Intentional difference:** the prototype's "Ask a specialist privately → sent" is simulated. Production shows the referral's targets with "Open" links only, because the contract has no private-message endpoint.
- **Character** (assistant role, lantern): `thinking` while processing, `speaking` briefly as the answer appears, `listening` while recording.

## S12 · Profile, settings, about — Tier A (delete account: B)

- **Profile** `/profile` (prototype `features/profile/profile_screen.dart`, screenshot `53`): night header with the companion (`greet`, 170), display name (editable → `PATCH /me {display_name}`, 2–24 chars), track tag, "Joined <month year>" (`created_at`); the Statistics grid (streak, total embers, words mastered `terms.mastered`, lessons `lessons_completed`, league name/rank or "No league yet", badges `unlocked/total`); the achievements row (4 badges + "See all"); the **"Your words" row** (new home of the review screen's words section: mastered count and a short preview of terms with their `RingProgress`, "See all" → `/glossary`); friends (Tier B). `ProfileBloc`: `LoadCurrentUser`, `GetStats`, `GetAchievements`.
- **Settings** `/settings` (prototype `settings_screen.dart`, screenshot `55`): language (→ `LocaleCubit` instantly + `PATCH /me {language}`), path (track), daily goal, reminders (discreet; local), sound, haptics, reduce motion (local, `PreferencesCubit`), private profile (`PATCH /me`), the curiosity question (`PATCH /me {goal_anchor}`; shown only when `CURIOSITY_ONBOARDING` is on and its copy exists), characters on/off (local), "Delete account" (Tier B: confirmation sheet → `DELETE /me` → clear token and local state → splash). There is no "Reset demo progress" in production builds (developer menu only). The developer menu (long-press the avatar; dev and demo builds) also holds the Salah preview launcher and the Unit 0 lesson picker ([07 §5](07_MOCKS_AND_BACKEND_SYNC.md)).
- **About** `/about` (prototype `about_screen.dart`, screenshot `56`): the name's meaning and the verse behind it (Surah Taha 20:10). The verified text is already in the app: `Scripture.taha10` and `Scripture.taha10Segment` in `lib/shared/content/bundled_scripture.dart` (never retype Quran text); show it with its reference. Add the statement that content is pending specialist review and that questions are processed by AI services (P-04).
- **Achievements** `/achievements` (Tier B, prototype `achievements_screen.dart`, screenshot `54`): badge grid by `achievement_key` (bundled painters; unknown → generic), locked/unlocked with `progress`.

## S13 · League · S19 Quests · S14 Friends — Tier B

- **Community tab** `/community` (prototype `community_screen.dart`, screenshots `47`–`48`). `CommunityBloc`: `GetCurrentLeague`, `GetDailyQuests`; `FriendsBloc`: `GetFriends`, `CreateInvite`, `AcceptInvite`, `RemoveFriend`.
- **League** header (tier badge and name from the server, "ends in" from `ends_in_seconds`), the promotion zone highlighted (no demotion zone), member rows with avatar, name, XP and "you" highlight; private members appear with a generic name and the default avatar exactly as sent. `404 no_league_this_week` → "Earn embers to join this week's league".
- **Quests** three rows with `RingProgress`/progress bar, goal, reward, completed state, "resets in".
- **Friends** list (online dot enables "Challenge"); invite sheet with the code (`stat` style), share button (`share_plus`, `share_text`); accept-code field (trim, uppercase); errors `invite_invalid`, `already_friends`.

## S15–S17 · Challenges — Tier B on the fake socket, C live

- **Prototype** `features/community/live_challenge_screen.dart` (phases lobby → countdown → question → reveal → results; screenshots `49`–`52`).
- `ChallengeLobbyBloc`: `CreateChallenge` (bot duel, friend duel, group up to 3 friends with `bot_fill`), invitations accept/decline. `LiveChallengeBloc`: connects through `DuelSocketFactory` with `Duel.ws_url`, maps server events to phases, sends `ready`/`answer`/`ping`, computes timers from the server clock offset, and reconnects with a freshly fetched `Duel`. Draining timer bar (15 s duel, 10 s group; colour shift in the last 5 s / 3 s). The result shows the winner(s), points, correct counts, XP and per-question explanations; the companion `celebrate` if won, otherwise `encourage`.
- Async fallback (C): after 60 s pending, "Play now; your friend plays later" → async endpoints.

## R1–R6 · Reviewer console — Phase 14

Routes under `/reviewer/*`, visible only when `role = reviewer`; entry from the developer menu (dev/demo) and the hidden `/reviewer/login`. It is a work tool for content reviewers: **the same design language as the learner app but no gamification** (no embers, streaks, celebrations or companion), denser, two-pane on tablet and web. Screens: R1 sign-in, R2 runs list and new run, R3 Gate 1 plan review, R4 Gate 2 draft review (learner renderers in preview mode, Arabic and English side by side, evidence panel, arc map, QA report, visuals; Approve / Request changes / Reject), R5 blind test, R6 metrics dashboard. Gate decisions echo `review_digest` and handle `409 review_stale`. The full spec is in `docs/PHASES.md` Phase 14.
