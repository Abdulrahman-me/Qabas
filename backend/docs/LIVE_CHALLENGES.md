# Live challenges (Phase 20)

The revision 10 `GET/POST /v1/duels` domain is unchanged. `/v1/ws/duels/{id}` adds live transport over the same
pinned questions, deterministic grader, bot, result transaction and reward ledger. It has no Raqeeb/model dependency.
The durable coordinator is implemented; O-04 still approves the deployment. Phase 21 owns load/outage drills and
the joint Flutter integration gate on the deployed topology, not a replacement single-process implementation.

## Connection and protocol

Create, get and accept return a fresh `ws_url` with a caller/session/duel/language-bound, cryptographically random,
single-use 60-second ticket. Redis stores its SHA-256 key, never the original nonce. Consume atomically at upgrade;
then revalidate the ordinary learner session and challenge seat in PostgreSQL. An invalid, expired or consumed ticket
is HTTP 401; a nonparticipant is HTTP 403. REST lookup keeps its 404 non-enumeration rule. Native clients may omit
Origin; browser origins must be in CORS configuration. Bearer headers or URL bearer tokens do not replace tickets.
History and state events contain an unticketed endpoint. An idempotent create replays its original response exactly:
fetch GET for a fresh ticket before every reconnect. Each device needs its own ticket.

Only `ready {}`, `answer {question_index, answer}` and `ping {}` are accepted. All server events validate through
`WsEvent`, including the initial `state`, lobby status, player readiness, 3-second countdown, question, private
`answer_received`, opponent submission notice, question result, disconnect/reconnect, group `player_left`, finished
summary, error and pong. No event-sequence extension is added to the closed contract. An open-question reconnect
receives state and the current question. A finished reconnect receives state and finished, then closes normally.

Questions last 15 seconds in the seven-question duel and 10 seconds in the three-question group. Reveal lasts
3000/2200 ms respectively. All timestamps preserve the exact stored instant. Receipt time is captured on the server
before database waits; a submission at the deadline is eligible, later submissions are ignored. The first valid
answer wins across devices; duplicates cannot change it. No opponent correctness or current-question points are
revealed before closure; no future question/key leaves the server. Reconnect includes only the caller's locked
answer, submitted-player IDs, closed totals/results and the current persisted deadline. Client clocks never grade.

## Durable authority, leases and delivery

PostgreSQL is the authority: existing duel status/phase/epoch and pinned questions plus persisted countdown,
question/reveal deadlines, participant readiness/disconnection, durable connection receipts and an append-only
coordinate-only event journal. Each closed shared question has immutable public score coordinates, without raw
answers, so deleting one learner's private submissions does not erase the other players' score history.

Any API instance may own a socket. A coordinator acquires `duel:{id}:owner` with an atomic 5000 ms Redis lease and
renews every second. Epoch allocation uses Redis INCR with the persisted database epoch as a floor, including after
Redis data loss. Row locks serialize transitions; exact ownership/epoch checks run before writes and before commit.
Database triggers reject stale phase, question timing, bot/timeout answer and outbound journal writes (`QB008`).
Timing and result snapshots are set once. Live completion requires all shared questions closed; the Phase 19 result
transaction publishes ranking, rewards, quests and league effects once, followed by achievement outbox processing.

Input receipts commit before owner consumption. Outbound coordinates commit in the same transaction as the state
change, and only then trigger pub/sub wakeup. Every socket instance tails the ordered database journal, polling at
most once per second if a wakeup was missed. Thus a crash between commit and publish cannot lose a transition.
Redis `duel:{id}` is a viewer/language-specific read-through snapshot with a DB-derived identity; authorization and
public profile/deletion changes are checked before a cache hit. Redis cannot authorize, reset a timer or grant XP.

Local 200 ms pulses merely wake the owner. On takeover, reload persisted state: close a past deadline, preserve an
unexpired deadline and resume reveal. Do not regenerate questions or restart a timer. Bot choices/due times reuse
Phase 19's seeded model (70% expected correctness, median 6 seconds, 1.5–14 seconds). A group bot due after the
10-second deadline times out. A retry or takeover cannot change its choice or insert a second answer.

The last disconnected device starts a 10-second grace period; another active device keeps the learner present.
Reconnect during grace resumes. After grace the learner keeps previously earned points and remaining questions
score zero; subsequent reconnect is read-only. A crashed API's durable socket receipt expires after 30 seconds of
inactivity, and grace starts at that recorded expiry, not when a later worker notices it. A nonempty connected quorum
may close early; an empty quorum does not finish instantly during grace. Account deletion expires an open game
without rewards and masks the removed profile immediately.

## Running, recovery and abuse controls

Use `uv run python scripts/run_api.py --host 127.0.0.1 --port 8000 --workers 2` for the bounded Uvicorn launcher.
Run the ordinary Celery worker/beat as documented in README. Every API scans open live rooms (bounded pages of 100);
`maintenance.recover_live_challenges` is a one-second beat fallback that claims ownerless rooms. Duplicate startup,
beat redelivery and concurrent instances are safe. Redis ownership loss stops writes; recovery follows Redis return.
No sticky-session requirement. `live_coordinator` readiness reports `ok` or `draining`; shutdown rejects upgrades,
closes sockets with 1012, releases leases and leaves database state for another owner. Clients fetch a fresh ticket.

Defaults: 4 simultaneous sockets per learner across rooms, 30 upgrades per minute, 5 messages/second per socket,
16 KiB frames, 32 pending outbound events, 5-second send limit and 30-second idle close. Invalid/unsupported frames
produce a contract error and keep the socket usable; oversized frames close 1009. Slow consumers close and restore
from a fresh state. Ordinary challenge creation, friendship, eligibility and rate-limit rules remain REST-owned.
Connection/frame/send bounds are validated settings; operational tuning is O-10/Phase 21. Correct answers and
credentials are never logged. Uvicorn error-log upgrade URLs redact all query content and transport debug-frame
logging is disabled. Reverse proxies **must omit/redact WebSocket query strings** in their access/error logs too.

Deployment prerequisites remain O-04/O-09: TLS/WSS, proxy WebSocket forwarding and timeout above the heartbeat
cadence, synchronized NTP clocks, PostgreSQL/Redis availability, least-privilege application/worker roles, draining
and restore practice. Clients should send contract `ping` below the idle interval. Recovered open challenges remain
auditable; restore/delete re-purge and production topology/load monitoring are Phase 21 acceptance gates.

## Validation and product boundaries

CI uses native PostgreSQL/Redis, the contract's explicit test curriculum and server-controlled test clocks; no paid,
model, source or media provider calls. Tests cover the public four-player script, all seven bot questions, exact
deadline/duplicate answers, two devices/two API instances, takeover/fencing, Redis loss, commit-before-publish,
failed result transaction, grace/absence, private-answer purge, tickets, rate limits and draining.

The Phase 19 first-five-rewarded-challenges-per-local-day cap remains conservative and **requires owner
confirmation** (D-195/F-192); repeat play remains available. This phase neither approves that product choice nor
changes Raqeeb, curriculum/mastery/lesson publication or external content/media approvals.
