# 05 — Networking and API integration

The binding contract is `docs/contract/03_API/API_REQUIREMENTS.md` (revision 10). This document says how the Flutter client implements it. Section numbers like "API §6.5" refer to that file.

## 1. The client stack

```
BLoC → use case → repository → <Feature>RemoteDataSource → ApiClient → Dio
                                                                   │ interceptors: contract headers → auth → idempotency → retry → errors → (debug) redacted log
                                                                   └ HttpClientAdapter: RoutingAdapter ─┬─ live: IOHttpClientAdapter → backend
                                                                                                         └─ mock: MockBackend (07)
```

Only `core/network/` touches Dio. Data sources use `ApiClient`:

```dart
final class ApiClient {
  Future<T> get<T>(String path, {Map<String, Object?>? query, required T Function(Map<String, dynamic>) decode});
  Future<T> post<T>(String path, {Object? body, required T Function(Map<String, dynamic>) decode, String? idempotencyKey});
  Future<void> postNoContent(String path, {Object? body, String? idempotencyKey});   // 204 endpoints
  Future<T> patch<T>(String path, {required Object body, required T Function(Map<String, dynamic>) decode});
  Future<void> delete(String path);
  Future<T> postMultipart<T>(String path, {required FormData form, required T Function(Map<String, dynamic>) decode, required String idempotencyKey, void Function(int sent, int total)? onProgress});
}
```

`ApiClient.create(config, …)` builds Dio with:

| Option | Value |
|---|---|
| `baseUrl` | `API_BASE_URL` including `/v1` (local backend `http://localhost:8000/v1`; Android emulator `http://10.0.2.2:8000/v1`) |
| Timeouts | connect 10 s; receive 20 s; multipart send 60 s; recitation receive 20 s (the server waits up to 15 s for ASR) |
| Response type | JSON; `204` handled by `postNoContent`/`delete` |
| Adapter | `RoutingAdapter(live: IOHttpClientAdapter(), mock: sl<MockBackend>(), groups: config.liveGroups)` |

## 2. Required headers (API §3.2)

| Header | When | Value |
|---|---|---|
| `Authorization: Bearer <token>` | Every request except `POST /auth/guest` and `POST /auth/reviewer` | From `TokenStore` (flutter_secure_storage). **Never** in a URL or log. |
| `Qabas-Contract` | Every request | `10` |
| `Qabas-Client` | Every request | `<ios\|android\|web>/<app semver>` (from `package_info_plus` or `AppConfig.appVersion`) |
| `Accept-Language` | Every request | Current `LocaleCubit` language (`ar`/`en`). A session's content language is fixed at creation; resume returns the stored snapshot regardless. |
| `Content-Type` | JSON bodies, or multipart for Raqeeb messages and recitation checks | Set by Dio |
| `Idempotency-Key` | **Required:** `POST /raqeeb/conversations/{id}/messages`, `POST /recitation/checks`. **Recommended:** `POST /raqeeb/conversations`, `/friends/invites`, `/duels` | UUID v4, generated **once per user action** by the BLoC and passed down; reused for automatic retries of that action; a fresh key for a new action (for example "Retry" after a failed Raqeeb answer) |

Each response carries `Qabas-Contract: <server revision>`. Log it once at startup (debug) so contract mismatches are obvious.

## 3. Interceptors (in order)

1. **ContractHeadersInterceptor**: adds `Qabas-Contract`, `Qabas-Client`, `Accept-Language`.
2. **AuthInterceptor**: adds the bearer token unless `options.extra['noAuth'] == true`.
3. **IdempotencyInterceptor**: copies `options.extra['idempotencyKey']` to the header.
4. **RetryInterceptor**: retries only safe requests. It retries GET, `POST /sessions` (server returns the existing active session), answers and finish (replayed by attempt or session identity), and any request with an idempotency key. It retries on connection errors, timeouts, `503` and `429` (honouring `details.retry_after_ms`) with backoff 0.5 s → 1 s → 2 s, at most 3 attempts. Never retry other `4xx`.
5. **ErrorInterceptor**: converts `DioException` into `ApiException { int? status; String code; String message; Map<String, Object?> details; }`, parsing the envelope `{"error": {"code", "message", "details"}}` (API §3.4). An unknown `code` keeps its string; mapping falls back to the HTTP status row.
6. **RedactingLogInterceptor**: debug builds only. Logs method, path, status and duration. Never logs `Authorization`, tokens, `ws_url`, request bodies of Raqeeb/recitation/answers, or attachment URLs.

## 4. Error mapping

| HTTP / `code` | `Failure` | Default client behaviour |
|---|---|---|
| no response / timeout | `NetworkFailure` | Inline error with Retry; keep cached content visible |
| 400 `validation_error` | `ValidationFailure(message, field)` | Show `message` inline next to the field or action (the server text is already user-facing) |
| 401 `unauthorized` | `UnauthorizedFailure` | Global handling, §5 |
| 403 `forbidden` | `ForbiddenFailure` | Generic "not available" state; reviewer routes are hidden for learners anyway |
| 404 `not_found` | `NotFoundFailure(reason)` | Generic not-found; `GET /leagues/current` with `reason = no_league_this_week` → league empty state |
| 409 (`nothing_to_review`, `out_of_order`, `retry_not_allowed`, `session_finished`, `session_not_active`, `recitation_check_mismatch`, `duel_not_joinable`, `invite_invalid`, `already_friends`, `run_not_at_gate`, `review_stale`, `idempotency_conflict`, `answer_in_progress`, `prerequisite_unmet`) | `ConflictFailure(code, details)` | Refresh the resource, then show the localised message for that code ([12](12_STATES_AND_ERRORS.md)); `nothing_to_review` → review empty state; `prerequisite_unmet` → the Soft Lock sheet (not an error), from `details.prerequisite_lesson_ids` and `details.start_with_lesson_id` |
| 413 | `PayloadTooLargeFailure` | Show the limit (§7) |
| 415 | `UnsupportedMediaFailure` | Show accepted types |
| 426 `client_outdated` | `ClientOutdatedFailure` | Global: blocking update screen |
| 429 `rate_limited` | `RateLimitedFailure(retryAfter)` | "Please wait" with the remaining time; Raqeeb daily cap message |
| 500 `internal_error` | `ServerFailure` | Retry button |
| 503 `upstream_unavailable` | `UpstreamUnavailableFailure(retryAfter)` | "Sources are temporarily unavailable, try again shortly"; recitation offers retry or skip |
| JSON decode error | `UnexpectedFailure` | Generic error; log the path and model name in debug (it signals contract drift: fix the DTO or raise it with the backend) |

## 5. Global auth and version handling

`ApiClient` publishes `AuthEvent`s on a stream that `AppSessionBloc` listens to:

- **401 for a learner** (API §3.4, non-looping): delete the token → `AppSessionBloc` emits `sessionEnded` → the page shows the localised "Your session ended" sheet → on Continue: `POST /auth/guest` → onboarding. If guest creation itself fails, stay on the splash with an error and a Retry button. Never redirect splash → 401 → splash. Count consecutive auth failures and stop after one automatic attempt.
- **401 for a reviewer**: clear the token, go to the reviewer login.
- **426**: emit `outdated` with `details.min_app_version`; the router redirects to `/update-required` and blocks everything else.
- **Bootstrap** (S1): token stored → `GET /me` → `onboarding_completed` ? journey : onboarding. No token → `POST /auth/guest {timezone}` (device IANA zone via `flutter_timezone`, falling back to `UTC`) → store the token → onboarding.
- **Delete account** (`DELETE /me` → 204): clear the token, local preferences and session resume data → splash. The old token now returns 401; don't call anything with it.

## 6. Polling (Raqeeb)

Answers take 5–30 s. After `POST …/messages` returns `202 {user_message, assistant_message(processing)}`, the repository exposes `Stream<AssistantMessage> watch(messageId)`:

```dart
Stream<AssistantMessage> watch(String messageId) async* {
  final deadline = clock.now().add(const Duration(seconds: 90));
  while (true) {
    final m = await _remote.getMessage(messageId);            // GET /raqeeb/messages/{id}
    yield m.toEntity();
    if (m.status != 'processing') return;                     // completed | failed
    if (clock.now().isAfter(deadline)) throw const PollTimeout();
    await Future<void>.delayed(const Duration(milliseconds: 1000));
  }
}
```

The BLoC subscribes with `emit.forEach`, shows the localised stage label (`reading_inputs`, `classifying`, `retrieving`, `verifying`, `writing`, `adapting`) with a subtle animation, and on timeout or `failed` shows a retry action that **posts a new message with a new Idempotency-Key**. One answer can be in progress per conversation (`409 answer_in_progress` → keep the composer disabled). Never show an unlabeled spinner for more than 1 s.

Other polling: `GET /duels/invitations` every 15 s **only while the journey or community tab is visible** (pause on tab change and app background).

## 7. Multipart uploads and client-side limits (API §3.7)

Validate before sending; the server enforces the same limits.

| Upload | Fields | Types | Limit |
|---|---|---|---|
| Raqeeb message | `text` (≤ 2,000 chars), `audio`, `images` (repeatable), `document` | audio `audio/mp4` (m4a/AAC, mobile), `audio/webm` (Opus, web), `audio/wav`, `audio/mpeg`; images `image/jpeg`, `image/png`, `image/webp`; document PDF or DOCX | voice ≤ 60 s and 10 MB; ≤ 3 images, 8 MB each; 1 document, 10 MB. At least one field required. |
| Recitation check | `audio`, `surah`, `ayah`, optional `word_start` + `word_end`, optional `exercise_id` | same audio types | ≤ 30 s, 5 MB |

Use `record` (AAC/m4a on iOS/Android), `image_picker`, `file_picker`. Ask for microphone permission just-in-time, show elapsed and maximum time, and auto-stop at the maximum. Attachment URLs in responses are short-lived signed URLs (≤ 15 min): if an image fails to load, re-fetch the conversation. Recitation audio is never stored by the server; don't keep it either after the check returns.

## 8. Real-time challenges (API §8)

```dart
abstract interface class DuelSocket {
  Stream<WsEvent> get events;          // decoded server events
  void send(WsClientMessage message);  // ready | answer | ping
  Future<void> close();
}
abstract interface class DuelSocketFactory { Future<DuelSocket> connect(Uri wsUrl); }
```

- Connect **only** to `Duel.ws_url` exactly as returned by the server: it carries a single-use 60 s ticket. Never build socket URLs or put the access token in them. Never log the URL.
- Before **every** reconnect, fetch a fresh `Duel` (`GET /duels/{id}`) for a new ticket. Backoff 0.5 s → 1 s → 2 s, at most 5 tries. The `state` message restores the current question.
- Send `ready` after rendering the lobby, `ping` every 10 s, and `answer` once per question.
- Timers: compute `offset = server_ts(state) − localNow` at connect; remaining = `deadline_at − (now + offset)`. The server is authoritative (late answers score 0).
- Real implementation: `web_socket_channel` (`WebSocketDuelSocketFactory`). Mock: `FakeDuelSocketFactory` replays `group_ws_script.json` / a duel script with realistic delays ([07](07_MOCKS_AND_BACKEND_SYNC.md)).

## 9. Media

- Images (`Visual.kind=image`, overlays): `cached_network_image`. Lay out with `image.width / image.height`; use `mime_type` from the payload (never infer from the URL); verify `sha256` where declared (scenes); a mismatch counts as a load failure → fallback.
- Content audio (reciter clips, narration, term pronunciation, MP3): `ContentAudioPlayer` in `core/audio/` (`just_audio` recommended for clip/seek with `audio.words` timings). Narration never autoplays; show a play control only when a URL exists. Quran is never TTS.
- Mock media: the Unit 0 sessions carry absolute `http://localhost:8765/media/…` URLs (the backend's local file server). In mock mode the resolver maps `http://localhost:8765/<path>` → bundled `assets/mocks/unit0/<path>`, so no server is needed and phones work. The contract fixtures use the scheme `mock-asset://<path>` (for example `mock-asset://audio/test_tone_112001.mp3`, `mock-asset://maps/hijaz_test.webp`). `ContentAudioPlayer` and the image loader resolve it to the bundled `assets/mocks/contract/mock_assets/<path>` in dev/demo builds (already in the app).

## 10. Endpoint → client map

"Tier" is the demo priority from [01](01_PRODUCT_AND_SCOPE.md). All repositories live in their feature's `domain/repositories/` (interface) and `data/repositories/` (impl).

| Endpoint | Data source method | Use case | Consumed by | Tier |
|---|---|---|---|---|
| `POST /auth/guest` | `AuthRemote.createGuest(timezone)` | `CreateGuestSession` | `AppSessionBloc` | A |
| `GET /me` | `AuthRemote.me()` | `LoadCurrentUser` | `AppSessionBloc`, `ProfileBloc` | A |
| `POST /onboarding` (with `goal_anchor`) | `OnboardingRemote.submit(req)` | `CompleteOnboarding` | `OnboardingBloc` | A |
| `PATCH /me` (partial body; omit unchanged fields; `goal_anchor` allowed) | `ProfileRemote.patchMe(patch)` | `UpdateProfile` | `SettingsBloc`, journey path switcher | A |
| `DELETE /me` | `ProfileRemote.deleteMe()` | `DeleteAccount` | `SettingsBloc` | B |
| `GET /me/stats` | `ProfileRemote.stats()` | `GetStats` | `ProfileBloc`, journey stat chips, review hub | A |
| `GET /me/achievements` | `ProfileRemote.achievements()` | `GetAchievements` | `ProfileBloc` (badge row), `AchievementsBloc` | A row / B screen |
| `GET /me/activity?from&to` | `StreakRemote.activity(range)` | `GetActivity` | `StreakBloc` | B |
| `GET /me/quests` | `CommunityRemote.quests()` | `GetDailyQuests` | `CommunityBloc` | B |
| `GET /me/concepts` | `ProfileRemote.concepts(cursor)` | `GetConceptMastery` | profile mastery list (optional) | C |
| `GET /journey` | `JourneyRemote.journey()` | `GetJourney` | `JourneyBloc` (Roadmap), `DiscoverBloc` (its `standalone_eligible` lessons) | A |
| `GET /journey/next` | `JourneyRemote.next()` | `GetNextStep` | `JourneyBloc` (Today card, Continue) | A |
| `GET /units/{id}/guide` | `JourneyRemote.guide(unitId)` | `GetUnitGuide` | `UnitGuideBloc` | B |
| `GET /lessons/{id}` | `ReaderRemote.lesson(id)` | `GetLessonForReading` | `ReaderBloc` | B |
| `POST /sessions` | `SessionRemote.create(req)` (200 = existing active, 201 = new; `409 prerequisite_unmet` → Soft Lock sheet; `404` for a lesson outside the learner's track) | `StartLessonSession`, `StartReviewSession`, `StartUnitAssessment` | `LessonIntroBloc`, `ReviewHubBloc`, `SessionPlayerBloc` | A (lesson), B (others) |
| `GET /sessions/{id}` | `SessionRemote.get(id)` | `ResumeSession` | `SessionPlayerBloc` | B |
| `POST /sessions/{id}/answers` | `SessionRemote.answer(id, submit)` | `SubmitAnswer` | `SessionPlayerBloc` | A |
| `POST /sessions/{id}/finish` | `SessionRemote.finish(id, durationMs)` | `FinishSession` | `SessionPlayerBloc`, `SessionResultBloc` | A |
| `POST /sessions/{id}/abandon` | `SessionRemote.abandon(id)` | `AbandonSession` | `SessionPlayerBloc` (quit sheet → leave) | B |
| `POST /recitation/checks` | `RecitationRemote.check(form, key)` | `CheckRecitation` | `RecitationBloc` inside the recite exercise | B (Tier A: listen + skip) |
| `GET /glossary?state&cursor&limit` | `GlossaryRemote.list(…)` | `GetGlossary` | `GlossaryBloc`, review hub words | B |
| `GET /glossary/{id}` | `GlossaryRemote.term(id)` | `GetTermCard` | `TermSheetCubit` when the term is not in the payload | B |
| `POST /glossary/{id}/opened` | `GlossaryRemote.opened(id)` | `MarkTermOpened` (fire and forget) | `TermSheetCubit` | A |
| `POST /raqeeb/conversations` | `RaqeebRemote.createConversation(context)` | `StartConversation` | `RaqeebChatBloc` | A |
| `GET /raqeeb/conversations` | `RaqeebRemote.conversations(cursor)` | `ListConversations` | `RaqeebHistoryBloc` | B |
| `GET /raqeeb/conversations/{id}` | `RaqeebRemote.conversation(id)` | `GetConversation` | `RaqeebChatBloc` | A |
| `POST /raqeeb/conversations/{id}/messages` | `RaqeebRemote.send(id, form, key)` | `SendRaqeebMessage` | `RaqeebChatBloc` | A (text), B (attachments) |
| `GET /raqeeb/messages/{id}` (poll) | `RaqeebRemote.message(id)` | `WatchAssistantMessage` | `RaqeebChatBloc` | A |
| `POST /raqeeb/messages/{id}/feedback` | `RaqeebRemote.feedback(id, req)` | `RateAnswer` | `RaqeebChatBloc` | B |
| `GET /leagues/current` | `CommunityRemote.league()` | `GetCurrentLeague` | `CommunityBloc` | B |
| `GET /friends` · `POST /friends/invites` · `POST /friends/invites/accept` · `DELETE /friends/{id}` | `FriendsRemote.*` | `GetFriends`, `CreateInvite`, `AcceptInvite`, `RemoveFriend` | `FriendsBloc` | B |
| `POST /duels` · `GET /duels/invitations` · `POST /duels/{id}/accept\|decline` · `GET /duels/{id}` · `GET /duels` | `ChallengeRemote.*` | `CreateChallenge`, `GetInvitations`, `AcceptChallenge`, `DeclineChallenge`, `GetChallenge`, `GetChallengeHistory` | `ChallengeLobbyBloc`, `LiveChallengeBloc` | B (mock) / C (live) |
| WebSocket `Duel.ws_url` | `DuelSocketFactory.connect` | `JoinLiveChallenge` | `LiveChallengeBloc` | B (fake) / C (live) |
| `POST /duels/{id}/async`, `…/async/next`, `…/async/answer` | `ChallengeRemote.*` | `PlayAsync*` | `AsyncChallengeBloc` | C |
| `POST /auth/reviewer`, `/admin/**` | `ReviewerRemote.*` | `Reviewer*` | reviewer feature | C |

## 11. Things the client must never do

- Parse IDs, infer layout from IDs or wording, or branch on Salah IDs, unit numbers or category positions.
- Grade answers, compute XP/mastery/streaks, or reshuffle arrays the server sent (banks are pre-ordered; render them in the given order).
- Send fields the contract doesn't define, or omit nullable request fields (send explicit `null`), **except** `PATCH /me`, which sends only the changed fields and never `null`.
- Call any AI or LLM provider. Raqeeb is backend-mediated; there are no model keys in the app.
