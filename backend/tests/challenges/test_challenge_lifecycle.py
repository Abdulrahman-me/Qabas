"""Challenge lifecycle over REST (API §6.10, backend §11.1, §11.4): creation shapes and opponents, question
selection tiers with pinned versions and no repeats, invitations, accept/decline, the group lobby and bot fill,
expiry sweeps, the Phase 20 boundary for unstarted live duels, idempotency, rate limits, privacy and deletion."""

from __future__ import annotations

import asyncio
import uuid
from datetime import timedelta
from urllib.parse import parse_qs, urlsplit

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select, text

from app.contract import models as C
from app.models import Duel, DuelPlayer, DuelQuestion
from app.runtime import Resources
from app.services.challenges import bot, coordinator, duels, selection
from app.services.platform import deletion
from app.services.platform.auth_sessions import utcnow
from tests.challenges import support as S

pytestmark = pytest.mark.integration
EN = {"Accept-Language": "en"}


def create_body(opponent: str = "bot", friends: list[str] | None = None, preset: str = "duel",
                bot_fill: bool = False) -> dict[str, object]:
    return {"preset": preset, "opponent_type": opponent, "friend_user_ids": friends or [], "bot_fill": bot_fill}


async def test_bot_duel_is_ready_with_seven_pinned_distinct_questions(world: tuple[TestClient, Resources]) -> None:
    api, resources = world
    a, ha = await S.signed_in(resources, display_name="Seeker 4")
    response = api.post("/v1/duels", json=create_body(), headers=ha | EN)
    assert response.status_code == 201, response.text
    duel = C.Duel.model_validate(response.json())
    assert (duel.status, duel.mode, duel.preset, duel.opponent_type) == ("ready", "live", "duel", "bot")
    assert duel.config.model_dump() == duels.PRESETS["duel"]
    assert [(p.user_id, p.display_name, p.is_me, p.is_bot, p.status) for p in duel.players] == [
        (a, "Seeker 4", True, False, "joined"), (bot.BOT_IDS[0], "Coach", False, True, "joined")]
    assert duel.players[1].avatar_key == "traveler_bot" and duel.result is None
    url = urlsplit(duel.ws_url)
    assert (url.scheme, url.netloc, url.path) == ("ws", "testserver", f"/v1/ws/duels/{duel.duel_id}")
    assert len(parse_qs(url.query)["ticket"][0]) >= 43
    arabic = api.get(f"/v1/duels/{duel.duel_id}", headers=ha | {"Accept-Language": "ar"}).json()
    assert arabic["players"][1]["display_name"] == "المدرّب"
    async with resources.sessionmaker() as db:
        rows = (await db.execute(select(DuelQuestion).where(DuelQuestion.duel_id == duel.duel_id)
                                 .order_by(DuelQuestion.question_index))).scalars().all()
        assert [r.question_index for r in rows] == list(range(7)) and len({r.exercise_id for r in rows}) == 7
        types = set((await db.execute(text("SELECT DISTINCT e.type FROM exercises e JOIN duel_questions q ON "
                                           "q.exercise_id = e.id"))).scalars())
        assert types <= {"multiple_choice", "true_false", "verse_meaning"}
        assert all(r.issued_at is None for r in rows)                      # live timing belongs to Phase 20
    assert "answer_key" not in response.text and "email" not in response.text


async def test_selection_prefers_mastered_then_completed_then_unit_one(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a, b = await S.make_user(resources), await S.make_user(resources)
    async with resources.sessionmaker() as db:
        usable, unit_one = await selection.eligible_pool(db)
    assert usable and unit_one and unit_one <= {i.exercise_id for i in usable}
    async with resources.sessionmaker() as db:
        fresh = await selection.choose(db, [a, b], 7, "duel_seed")
        again = await selection.choose(db, [a, b], 7, "duel_seed")
    assert [i.exercise_id for i in fresh] == [i.exercise_id for i in again]          # reproducible per duel
    assert {i.exercise_id for i in fresh} <= unit_one                                 # nobody knows anything yet
    concept = usable[0].concept_ids[0]
    async with resources.sessionmaker() as db, db.begin():
        for uid in (a, b):
            await db.execute(text("INSERT INTO learner_concepts (user_id, concept_id, mastery) VALUES (:u, :c, 0.6)"),
                             {"u": uid, "c": concept})
    async with resources.sessionmaker() as db:
        known = await selection.choose(db, [a, b], 7, "duel_seed")
        both = [i for i in usable if set(i.concept_ids) <= {concept}]
        assert {i.exercise_id for i in known[:min(7, len(both))]} <= {i.exercise_id for i in both}
        with pytest.raises(Exception, match="not enough challenge questions"):
            await selection.choose(db, [a], len(usable) + 1, "duel_seed")


async def test_friend_duel_invitation_accept_and_decline(world: tuple[TestClient, Resources]) -> None:
    api, resources = world
    a, ha = await S.signed_in(resources, display_name="Seeker 1")
    b, hb = await S.signed_in(resources)
    c, hc = await S.signed_in(resources)
    stranger, _ = await S.signed_in(resources)
    await S.befriend(resources, a, b)
    await S.befriend(resources, a, c)
    for body, reason in ((create_body("friend", [stranger]), "not_a_friend"),
                         (create_body("friend", [a]), "duplicate_or_self"),
                         (create_body("friend", [bot.BOT_IDS[0]]), "not_a_friend")):
        refused = api.post("/v1/duels", json=body, headers=ha)
        assert refused.status_code == 400 and refused.json()["error"]["details"]["reason"] == reason
    assert api.post("/v1/duels", json=create_body("friend", [b, c]), headers=ha).status_code == 400   # shape
    created = api.post("/v1/duels", json=create_body("friend", [b]), headers=ha)
    duel_id = created.json()["duel_id"]
    assert created.json()["status"] == "pending" and created.json()["players"][1]["status"] == "invited"
    again = api.post("/v1/duels", json=create_body("friend", [b]), headers=ha)
    assert again.status_code == 409 and again.json()["error"]["details"]["reason"] == "already_open"
    invites = api.get("/v1/duels/invitations", headers=hb).json()["items"]
    assert [(i["duel_id"], i["from"]) for i in invites] == [(duel_id, {"user_id": a, "display_name": "Seeker 1"})]
    assert api.get("/v1/duels/invitations", headers=hc).json()["items"] == []
    assert api.get(f"/v1/duels/{duel_id}", headers=hc).status_code == 404       # not a player: nothing revealed
    assert api.post(f"/v1/duels/{duel_id}/accept", headers=ha).status_code == 409   # the challenger
    accepted = api.post(f"/v1/duels/{duel_id}/accept", headers=hb)
    assert accepted.status_code == 200 and (accepted.json()["status"], accepted.json()["mode"]) == ("ready", "live")
    assert api.post(f"/v1/duels/{duel_id}/accept", headers=hb).json()["status"] == "ready"   # repeated accept
    assert api.post(f"/v1/duels/{duel_id}/decline", headers=hb).status_code == 409   # already joined
    second = api.post("/v1/duels", json=create_body("friend", [c]), headers=ha).json()["duel_id"]
    assert api.post(f"/v1/duels/{second}/decline", headers=hc).status_code == 204
    assert api.post(f"/v1/duels/{second}/decline", headers=hc).status_code == 204   # idempotent
    declined = api.get(f"/v1/duels/{second}", headers=ha).json()
    assert declined["status"] == "declined" and declined["players"][1]["status"] == "declined"
    assert api.post(f"/v1/duels/{second}/accept", headers=hc).status_code == 409


async def test_invitations_expire_and_unstarted_live_duels_close(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a, b = await S.make_user(resources), await S.make_user(resources)
    await S.befriend(resources, a, b)
    t = utcnow()
    pending = await S.create(resources, a, t, friends=[b])
    ready = await S.create(resources, a, t, opponent_type="bot")
    assert await duels.sweep(resources.sessionmaker, t + timedelta(seconds=119)) == 0
    assert await duels.sweep(resources.sessionmaker, t + timedelta(minutes=2)) == 2
    assert (await S.load(resources, pending))[0].status == "expired"
    assert (await S.load(resources, ready))[0].status == "expired"      # never started by a coordinator (Phase 20)
    with pytest.raises(Exception, match="no longer available"):
        await S.accept(resources, b, pending, t + timedelta(minutes=3))
    started = await S.create(resources, a, t + timedelta(minutes=5), opponent_type="bot")
    async with resources.sessionmaker() as db, db.begin():                 # a coordinator started it
        await coordinator.fencing_context(db, 1)
        await db.execute(text("UPDATE duels SET coordinator_epoch = 1, status = 'in_progress', phase = 'question' "
                              "WHERE id = :d"),
                         {"d": started})
    assert await duels.sweep(resources.sessionmaker, t + timedelta(minutes=30)) == 0
    assert (await S.load(resources, started))[0].status == "in_progress"   # live play is the coordinator's


async def test_group_lobby_start_rule_and_bot_fill(world: tuple[TestClient, Resources]) -> None:
    api, resources = world
    a, ha = await S.signed_in(resources)
    friends = [await S.make_user(resources) for _ in range(3)]
    for f in friends:
        await S.befriend(resources, a, f)
    t = utcnow()
    filled = await S.create(resources, a, t, preset="group", opponent_type="friends", friends=friends, bot_fill=True)
    await S.accept(resources, friends[0], filled, t + timedelta(seconds=10))
    await S.decline(resources, friends[1], filled, t + timedelta(seconds=20))
    assert (await S.load(resources, filled))[0].status == "pending"          # one friend has not answered
    assert await duels.sweep(resources.sessionmaker, t + timedelta(seconds=60)) == 1
    duel, players = await S.load(resources, filled)
    assert duel.status == "ready"
    shown = C.Duel.model_validate(api.get(f"/v1/duels/{filled}", headers=ha).json())
    assert [(p.user_id, p.is_bot) for p in shown.players] == [(a, False), (friends[0], False),
                                                               (bot.BOT_IDS[0], True), (bot.BOT_IDS[1], True)]
    assert shown.config.model_dump() == duels.PRESETS["group"]
    with pytest.raises(Exception, match="no longer available"):
        await S.accept(resources, friends[2], filled, t + timedelta(seconds=61))   # the lobby closed
    plain = await S.create(resources, a, t + timedelta(minutes=5), preset="group", opponent_type="friends",
                           friends=friends[:2])
    await S.accept(resources, friends[0], plain, t + timedelta(minutes=5, seconds=1))
    await S.decline(resources, friends[1], plain, t + timedelta(minutes=5, seconds=2))   # all responded: start now
    duel, players = await S.load(resources, plain)
    assert duel.status == "ready" and not any(p.is_bot for p in players)
    empty = await S.create(resources, a, t + timedelta(minutes=9), preset="group", opponent_type="friends",
                           friends=friends[2:], bot_fill=True)
    await duels.sweep(resources.sessionmaker, t + timedelta(minutes=10))
    assert (await S.load(resources, empty))[0].status == "expired"           # nobody joined: closed, no bots


async def test_creation_is_idempotent_rate_limited_and_serialized(world: tuple[TestClient, Resources]) -> None:
    api, resources = world
    a, ha = await S.signed_in(resources)
    b = await S.make_user(resources)
    await S.befriend(resources, a, b)
    key = {"Idempotency-Key": str(uuid.uuid4())}
    first = api.post("/v1/duels", json=create_body(), headers=ha | key)
    assert api.post("/v1/duels", json=create_body(), headers=ha | key).json() == first.json()
    conflict = api.post("/v1/duels", json=create_body("friend", [b]), headers=ha | key)
    assert conflict.status_code == 409 and conflict.json()["error"]["code"] == "idempotency_conflict"
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(Duel)) == 1
    t = utcnow()
    outcomes = await asyncio.gather(*(S.create(resources, a, t, friends=[b]) for _ in range(4)),
                                    return_exceptions=True)
    assert sum(isinstance(o, str) for o in outcomes) == 1                    # one open challenge per friend
    for _ in range(29):
        assert api.post("/v1/duels", json=create_body(), headers=ha).status_code == 201
    limited = api.post("/v1/duels", json=create_body(), headers=ha)
    assert limited.status_code == 429 and limited.json()["error"]["code"] == "rate_limited"   # 30 per hour


async def test_history_pages_and_viewer_result(world: tuple[TestClient, Resources]) -> None:
    api, resources = world
    _, ha = await S.signed_in(resources)
    made = [api.post("/v1/duels", json=create_body(), headers=ha).json()["duel_id"] for _ in range(3)]
    page = api.get("/v1/duels?limit=2", headers=ha).json()
    assert [d["duel_id"] for d in page["items"]] == made[::-1][:2] and page["next_cursor"] == made[1]
    rest = api.get(f"/v1/duels?limit=2&cursor={page['next_cursor']}", headers=ha).json()
    assert [d["duel_id"] for d in rest["items"]] == [made[0]] and rest["next_cursor"] is None
    C.EXPORTED["DuelPage"].model_validate(page)
    assert api.get("/v1/duels?cursor=usr_x", headers=ha).status_code == 400


async def test_account_deletion_closes_open_challenges(world: tuple[TestClient, Resources]) -> None:
    _, resources = world
    a, b, c, d = [await S.make_user(resources) for _ in range(4)]
    for f in (b, c, d):
        await S.befriend(resources, a, f)
    t = utcnow()
    duel_with_b = await S.create(resources, a, t, friends=[b])
    group = await S.create(resources, a, t, preset="group", opponent_type="friends", friends=[c, d])
    await S.accept(resources, c, group, t + timedelta(seconds=1))
    async_duel = await S.create(resources, c, t, friends=[a])
    await S.to_async(resources, c, async_duel, t + timedelta(seconds=61))
    await S.play_all(resources, c, async_duel, t + timedelta(seconds=62), correct={0})
    for gone in (b, d):
        async with resources.sessionmaker() as db:
            await deletion.request_deletion(db, await S.user(resources, gone), now=t + timedelta(seconds=70))
    assert (await S.load(resources, duel_with_b))[0].status == "expired"
    group_row, players = await S.load(resources, group)
    assert group_row.status == "ready" and [p.status for p in players] == ["joined", "joined", "declined"]
    member = await S.user(resources, a)
    async with resources.sessionmaker() as db:
        await deletion.request_deletion(db, member, now=t + timedelta(seconds=80))
    assert (await S.load(resources, async_duel))[0].status == "expired"     # closed without rewards
    assert (await S.load(resources, group))[0].status == "expired"
    async with resources.sessionmaker() as db, db.begin():
        await deletion.purge_user(db, resources.storage, a)
    async with resources.sessionmaker() as db:
        assert await db.scalar(text("SELECT count(*) FROM duel_answers WHERE user_id = :u"), {"u": a}) == 0
        assert await db.scalar(text("SELECT count(*) FROM duel_answers WHERE user_id = :u"), {"u": c}) == 7
        assert await db.scalar(text("SELECT count(*) FROM xp_events WHERE ref_type = 'duel'")) == 0
        assert await db.scalar(select(func.count()).select_from(DuelPlayer).where(DuelPlayer.user_id == a)) == 3
