# 12 — Loading, empty, error, retry and blocking states

Every screen that fetches or sends data has designed states for loading, empty, error and retry. They use the prototype's calm language: a quiet flame instead of a spinner, warm clay instead of red, and the companion where a moment needs warmth. The prototype has almost none of these screens (its data is local), so they're built from existing components ([13](13_COMPONENTS.md)) and follow the rules below.

## 1. Principles

1. **Never a bare spinner.** Loading uses a quiet `FlameMark` or a soft skeleton of the screen's own layout. Anything that waits longer than about 1 s gets a **label** saying what is happening. This is mandatory for Raqeeb stages (API §6.8, UI rule 10).
2. **Keep content visible.** A refresh or retry never blanks content that's already on screen: show `refreshing` subtly and report failures inline or in a snackbar.
3. **Never lose the learner's work.** Failed submits keep the answer, text, attachments or onboarding choices, and Retry resends the same thing.
4. **Warm, specific, actionable.** Say what happened in plain words, then what to do. Use `retry`/clay tones, never red. Don't show error codes, stack traces or server internals (the one exception is `validation_error.message`, which is user-facing by contract).
5. **Every failure state has an action** (Retry, Go back, Continue, Open settings). No dead ends.
6. **No flash.** Show the loading view only if loading takes more than 200 ms (`DelayedLoading`); cross-fade between states with `AnimatedSwitcher` (`QMotion.normal`, `emphasized`).
7. **Accessible.** Errors and status changes are announced (`Semantics(liveRegion: true)`); focus moves to the error's action; all state text comes from ARB.

## 2. Standard state components (`core/design_system/components/states/`)

| Component | Use | Look (build from existing parts) |
|---|---|---|
| `QLoadingView(tone: night\|light, label?)` | Full-screen or section loading | Night: `NightSky` + centred `FlameMark` (glow 1.2). Light: `morningMint` + a skeleton of soft `surfaceSunk` blocks shaped like the screen's cards (gentle 1.2 s opacity pulse; static under reduced motion). An optional label in `bodyMedium` `slate` appears after 1 s. |
| `QInlineLoading(label?)` | Inside cards and buttons | Small `FlameMark` (18–24 px) + label |
| `QEmptyView(title, body, action?, art: companion\|unitArt\|lantern)` | Nothing to show yet | Companion (`encourage` or `greet`) or the relevant brand art, `headlineSmall` title, `bodyMedium` body, one `QButton` |
| `QErrorView(failure, onRetry, tone: night\|light)` | A full-screen or section fetch failed | 56 px circle in `retrySoft` with a `cloud_off_rounded`/`refresh_rounded` icon in `retryInk`, title, body, `QButton(tone: light)` (night tone on dark screens) |
| `QInlineError(message, onRetry?)` | A failed action inside a screen (submit, send, load more) | One line in `retryInk` with a "Try again" link; inside the lesson, it sits directly above the action bar |
| `showQSnack(context, message, {action})` | Transient notices (saved, copied, refresh failed while content is shown) | Theme snackbar (floating, `deepInk`, radius 16) |
| `QOfflineBanner` | Requests are failing with `NetworkFailure` | Slim `surfaceSunk` banner under the app bar: "You're offline. We'll keep what you've done." It disappears on the next successful request. |
| `QBlockingScreen` | `426` update required | Night sky, `FlameMark`, `QText.displaySmall` title, body, gold button (store URL from `AppConfig`) |
| `SessionEndedSheet` | `401` (learner) | `showQSheet`: companion `encourage`, title, body, Continue → new guest → onboarding |

Pages switch on the BLoC status with one helper, so every screen behaves the same:

```dart
StatusSwitcher(
  status: state.status,                      // LoadStatus
  hasData: state.journey != null,
  loading: () => const QLoadingView(tone: QTone.night),
  empty: () => QEmptyView(title: l10n.journeyEmptyTitle, body: l10n.journeyEmptyBody,
                          action: (l10n.commonRetry, () => bloc.add(const JourneyRefreshed()))),
  failure: () => QErrorView(failure: state.failure!, onRetry: () => bloc.add(const JourneyRequested())),
  builder: () => JourneyView(state: state),  // shown whenever data exists, even while refreshing or after a refresh failure
)
```

## 3. Failure → message (ARB keys)

Map in `core/l10n/failure_messages.dart` (`FailureMessage of(Failure f, AppLocalizations l10n) → (title, body, actionLabel)`). Feature-specific wording can override the generic text for a code.

| Failure / conflict code | Title key | Body (English intent) | Action |
|---|---|---|---|
| `NetworkFailure` | `errorNetworkTitle` | "No connection. Check your internet and try again." | Retry |
| `ServerFailure` | `errorServerTitle` | "Something went wrong on our side." | Retry |
| `UpstreamUnavailableFailure` | `errorSourcesTitle` | "Sources are temporarily unavailable, try again shortly." (API §3.4) | Retry (after `retryAfter` when given) |
| `RateLimitedFailure` | `errorRateLimitedTitle` | "Let's pause for a moment. You can try again in {time}." Raqeeb daily cap: "You've asked a lot today. Raqeeb will be ready again tomorrow." | Retry when the time passes |
| `ValidationFailure` | — | the server `message`, inline at the field or action | Edit |
| `NotFoundFailure` | `errorNotFoundTitle` | "We couldn't find this." | Go back |
| `NotFoundFailure(reason: no_league_this_week)` | `communityNoLeagueTitle` | "Earn embers to join this week's league." | Start a lesson |
| `ForbiddenFailure` | `errorForbiddenTitle` | "This isn't available for your account." | Go back |
| `PayloadTooLargeFailure` | `errorTooLargeTitle` | the limit from [05](05_NETWORKING_AND_API.md) §7 (for example "Images can be up to 8 MB") | Choose another |
| `UnsupportedMediaFailure` | `errorFileTypeTitle` | the accepted types | Choose another |
| `UnexpectedFailure` | `errorGenericTitle` | "Something unexpected happened." (log details in debug) | Retry |
| `nothing_to_review` | `reviewCaughtUpTitle` | **empty state**, not an error: "All caught up. New cards arrive as you learn." | Continue the journey |
| `answer_in_progress` | — | composer disabled with "Raqeeb is still answering…" | — |
| `out_of_order`, `session_finished`, `session_not_active` | `sessionOutOfSyncTitle` | "This lesson moved on in another place. Let's pick up where it is." | Reload the session (resume) |
| `retry_not_allowed` | — | silently skip that retry (client logic error; log it) | — |
| `recitation_check_mismatch` | `recitationMismatchTitle` | "Let's record that verse again." | Record again |
| `duel_not_joinable` | `challengeNotJoinableTitle` | "This challenge has already started or ended." | Back to community |
| `invite_invalid` | `friendsInviteInvalid` | "That code doesn't work. Check it and try again." | Edit |
| `already_friends` | `friendsAlreadyFriends` | "You're already friends." | OK |
| `idempotency_conflict` | `errorGenericTitle` | treated as unexpected (client bug: a key was reused for a different body) | Retry with a new action |
| `review_stale`, `run_not_at_gate` | reviewer console (Tier C) | "This run changed. Reload and review again." | Reload |
| `ClientOutdatedFailure` | — | global `QBlockingScreen` | Update |
| `UnauthorizedFailure` | — | global `SessionEndedSheet` | Continue |

## 4. Screen-by-screen

| Screen | Loading | Empty | Failure and recovery |
|---|---|---|---|
| Splash | The splash animation itself (never a second loader) | — | Guest creation or `GET /me` fails → error line + Retry under the logo. `426` → blocking screen. |
| Onboarding submit | The "Start" button shows `QInlineLoading` and is disabled | — | `QInlineError` above the button; the answers are kept |
| Journey | Night `QLoadingView` | "Your path is being prepared" + Retry | Night `QErrorView`; with data, a snackbar on refresh failure |
| Unit guide sheet | `QInlineLoading` inside the sheet | "No guide for this unit yet." | Inline error + Retry inside the sheet |
| Lesson intro | Light skeleton with the companion | — | `QErrorView` + Retry; Back returns to the journey |
| Session player: answer submit | The Check button shows a small flame; the answer stays selected | — | `QInlineError` above the action bar: "We couldn't check that. Your answer is kept." + Try again (same body; the server replays duplicates safely) |
| Session player: finish | Full-screen night `QLoadingView` with the label "Saving your progress…" | — | `QErrorView` + Retry (finish is idempotent); never replay the lesson locally |
| Session player: visual fails | — | — | Built-in unknown key or failed image → `fallback_image` → neutral panel with `alt` (+ retry for images). Text, evidence and buttons always render. `map_place` that can't render → "Continue" submits `{unavailable: true}`. |
| Result page | Night loading; count-ups start after the data arrives | — | Re-calls finish (idempotent) on Retry |
| Raqeeb send | The user bubble appears immediately with a subtle "sending" state | Welcome state (trust points + suggestions) | Send fails → the bubble shows "Not sent · Try again" (same key on retry); poll `failed` or the 90 s timeout → a gentle assistant bubble "I couldn't finish this answer" + "Try again" (a new message and key) |
| Raqeeb processing | Stage label (localised) with the `_TypingDots` animation and the lantern `thinking` | — | — |
| Raqeeb history | Light skeleton rows | "Your questions will appear here." + Ask | `QErrorView` |
| Glossary | Light skeleton list | "Words you meet in lessons will appear here." | `QErrorView`; load-more failure → inline row with Retry |
| Journey Review card | Hidden while loading | Hidden when no cards are due; `nothing_to_review` → card disappears + "All caught up" snackbar | Card hidden (the journey still works) |
| Discover | Skeleton rows | "New lessons to explore will appear here" + button to the Journey | `QErrorView` |
| Soft Lock (`409 prerequisite_unmet`) | — | — | Not an error: the Soft Lock sheet with the prerequisite and a button to `start_with` |
| Scenes | The fallback still while the manifest loads | — | Unknown capability, checksum or download failure → `fallback_image` → `alt` placeholder; text and buttons always render |
| Profile | Night header immediately with the cached name; stats tiles as skeletons | — | Stats tiles show "—" + a snackbar with Retry |
| Settings change | Optimistic: apply locally (language, toggles) immediately | — | `PATCH /me` fails → revert the value + snackbar "Couldn't save. Try again." |
| Delete account | The confirm button shows `QInlineLoading` | — | Inline error in the sheet; the account stays |
| Community | Skeleton league rows and quest rows | No league yet → the empty state above; no friends → "Invite a friend to learn together" + Invite | Per-section `QErrorView` (the league and quests fail independently) |
| Challenge live | Lobby "Waiting for players…" | — | Socket drop → "Reconnecting…" banner (with backoff and a fresh `ws_url`), after 5 failures → "Connection lost" + Back. `opponent_disconnected` → that player's avatar dims with a countdown from `grace_ms`. |
| Recitation | "Listening…" while recording (rings animation); "Checking…" while waiting (≤ 15 s) | — | Microphone denied → explain + "Open settings" + Skip; `503` → "Recitation checking is busy" + Retry/Skip; `unclear` → the server `message` + Record again; audio URL missing → "Audio isn't available yet" (the learner can still record or skip) |

## 5. Offline and slow networks

- `NetworkFailure` turns on `QOfflineBanner` (published through `AppEventBus`) until the next successful request.
- Repositories keep the last successful journey, stats and profile in memory, so tab switches don't flash loaders. Persistent offline caching is out of scope.
- Retries follow [05](05_NETWORKING_AND_API.md) §3. The UI never auto-retries endlessly: after the interceptor gives up, show the failure state with a manual Retry.

## 6. Testing

- `bloc_test` for every data-fetching BLoC: success, empty, each failure type, retry after failure, refresh failure with existing data.
- Widget tests render each state of the main pages in English and Arabic.
- Developer-menu toggles ([07](07_MOCKS_AND_BACKEND_SYNC.md) §5) exercise `426`, `401`, `503`, `429`, offline and unknown visuals on a device before the demo.
