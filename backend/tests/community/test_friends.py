"""Friends (backend §10.4, API §6.9): single-use 7-day invite codes unique among unexpired invites, mutual friendship
on accept, brute-force limits per learner and per address, privacy of private friends, online status, races on
one code and on mutual codes, idempotent invite creation and unfriending, and account deletion."""

from __future__ import annotations

import asyncio
import re
import uuid
from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select, text

from app.contract import models as C
from app.errors import ApiError
from app.models import FriendInvite, Friendship, User
from app.runtime import Resources
from app.services.community import friends
from app.services.platform import deletion
from app.services.platform.auth_sessions import utcnow
from app.services.platform.rate_limits import FAILURE_LIMITS, FailureCounter
from tests.community.support import earn, signed_in

pytestmark = pytest.mark.integration
EN = {"Accept-Language": "en"}


def invite(api: TestClient, headers: dict[str, str], **extra: str) -> dict[str, str]:
    response = api.post("/v1/friends/invites", headers=headers | extra)
    assert response.status_code == 201, response.text
    body: dict[str, str] = C.Invite.model_validate(response.json()).model_dump()
    return body


def accept(api: TestClient, headers: dict[str, str], code: str) -> tuple[int, dict[str, object]]:
    response = api.post("/v1/friends/invites/accept", json={"code": code}, headers=headers)
    return response.status_code, response.json()


def friend_ids(api: TestClient, headers: dict[str, str]) -> list[str]:
    response = api.get("/v1/friends", headers=headers)
    assert response.status_code == 200, response.text
    return [item["user_id"] for item in C.EXPORTED["FriendPage"].model_validate(response.json()).model_dump()["items"]]


async def test_invite_accept_list_and_single_use(api: TestClient, resources: Resources) -> None:
    a, ha = await signed_in(resources, display_name="Seeker 1", avatar_key="traveler_04", language="ar")
    b, hb = await signed_in(resources)
    c, hc = await signed_in(resources)
    made = invite(api, ha, **EN)
    assert re.fullmatch(r"QBS-[0-9A-HJKMNP-TV-Z]{4}", made["code"]) and made["invite_id"].startswith("inv_")
    assert made["share_text"] == f"Join me on Qabas! Use the code {made['code']}"
    expires = datetime.fromisoformat(made["expires_at"].replace("Z", "+00:00"))
    assert timedelta(days=6, hours=23) < expires - utcnow() <= timedelta(days=7)
    assert invite(api, ha)["share_text"].startswith("انضم إليّ في قبس!")            # learner language (ar)

    status, body = accept(api, hb, made["code"].lower())                      # typed in lower case
    assert status == 200, body
    friend = C.Friend.model_validate(body)
    assert (friend.user_id, friend.display_name, friend.avatar_key) == (a, "Seeker 1", "traveler_04")
    assert friend_ids(api, ha) == [b] and friend_ids(api, hb) == [a]       # mutual

    status, body = accept(api, hc, made["code"])                              # single use
    assert status == 409 and body["error"]["code"] == "invite_invalid"
    second = invite(api, ha)
    status, body = accept(api, hb, second["code"])
    assert status == 409 and body["error"]["code"] == "already_friends"
    assert accept(api, hc, second["code"])[0] == 200                          # already_friends left it unused
    assert sorted(friend_ids(api, ha)) == sorted([b, c])


async def test_own_expired_unknown_and_ineligible_codes_are_invalid(api: TestClient, resources: Resources) -> None:
    _, ha = await signed_in(resources)
    _, hb = await signed_in(resources)
    own = invite(api, ha)["code"]
    assert accept(api, ha, own)[1]["error"]["code"] == "invite_invalid"     # type: ignore[index]
    old = invite(api, ha)["code"]
    async with resources.sessionmaker() as db, db.begin():
        await db.execute(text("UPDATE friend_invites SET created_at = now() - interval '8 days', "
                              "expires_at = now() - interval '1 day' WHERE code = :c"), {"c": old})
    synthetic = await signed_in(resources, is_synthetic=True)
    async with resources.sessionmaker() as db, db.begin():
        db.add(FriendInvite(id="inv_SYNTHETIC0000000000000000", code="QBS-SYN0", inviter_id=synthetic[0],
                            created_at=utcnow(), expires_at=utcnow() + timedelta(days=1)))
    for code in (old, "QBS-SYN0", "QBS-ZZZZ", "not a code", ""):
        status, body = accept(api, hb, code)
        assert (status, body["error"]["code"]) == (409, "invite_invalid"), (code, body)  # type: ignore[index]
    assert friend_ids(api, hb) == []


async def test_failed_codes_are_limited_per_learner(api: TestClient, resources: Resources) -> None:
    _, ha = await signed_in(resources)
    _, hb = await signed_in(resources)
    good = invite(api, ha)["code"]
    for _ in range(10):
        assert accept(api, hb, "QBS-0000")[0] == 409
    response = api.post("/v1/friends/invites/accept", json={"code": good}, headers=hb)
    assert response.status_code == 429 and response.json()["error"]["code"] == "rate_limited"
    assert int(response.headers["Retry-After"]) > 0 and response.json()["error"]["details"]["retry_after_ms"] > 0
    assert accept(api, ha, "QBS-0000")[0] == 409                              # another learner is not blocked


async def test_failed_codes_are_limited_per_address(api: TestClient, resources: Resources) -> None:
    _, ha = await signed_in(resources)
    good = invite(api, ha)["code"]
    for _ in range(10):                                                        # 10 learners x 10 failures
        _, headers = await signed_in(resources)
        for _ in range(10):
            assert accept(api, headers, "QBS-0000")[0] == 409
    _, fresh = await signed_in(resources)
    status, body = accept(api, fresh, good)
    assert status == 429 and body["error"]["code"] == "rate_limited"         # type: ignore[index]


async def test_successful_and_already_friends_attempts_are_not_failures(api: TestClient, resources: Resources) -> None:
    _, ha = await signed_in(resources)
    _, hb = await signed_in(resources)
    assert accept(api, hb, invite(api, ha)["code"])[0] == 200
    for _ in range(12):
        assert accept(api, hb, invite(api, ha)["code"])[1]["error"]["code"] == "already_friends"  # type: ignore[index]


async def test_invite_creation_is_idempotent_and_rate_limited(api: TestClient, resources: Resources) -> None:
    _, ha = await signed_in(resources)
    key = {"Idempotency-Key": str(uuid.uuid4())}
    first = invite(api, ha, **key)
    assert invite(api, ha, **key) == first                                    # a retry returns the same invite
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(FriendInvite)) == 1
    for _ in range(19):
        invite(api, ha)
    response = api.post("/v1/friends/invites", headers=ha)
    assert response.status_code == 429 and response.json()["error"]["code"] == "rate_limited"
    assert invite(api, ha, **key) == first                                    # replay does not consume the limit


async def test_codes_are_regenerated_on_collision_with_an_unexpired_invite(
        resources: Resources, monkeypatch: pytest.MonkeyPatch) -> None:
    a = (await signed_in(resources))[0]
    codes = iter(["QBS-AAAA", "QBS-AAAA", "QBS-BBBB", "QBS-CCCC"])
    monkeypatch.setattr(friends, "new_code", lambda: next(codes))
    async with resources.sessionmaker() as db, db.begin():
        user = await db.get(User, a)
        assert user is not None
        made = [await friends.create_invite(db, user, "en", utcnow()) for _ in range(2)]
    assert [m["code"] for m in made] == ["QBS-AAAA", "QBS-BBBB"]
    async with resources.sessionmaker() as db, db.begin():                    # an expired code may be reused
        await db.execute(text("UPDATE friend_invites SET created_at = now() - interval '8 days', "
                              "expires_at = now() - interval '1 day' WHERE code = 'QBS-BBBB'"))
    codes2 = iter(["QBS-AAAA", "QBS-BBBB"])
    monkeypatch.setattr(friends, "new_code", lambda: next(codes2))
    async with resources.sessionmaker() as db, db.begin():
        user = await db.get(User, a)
        assert user is not None
        assert (await friends.create_invite(db, user, "en", utcnow()))["code"] == "QBS-BBBB"


async def _accept(resources: Resources, uid: str, code: str) -> str:
    try:
        async with resources.sessionmaker() as db, db.begin():
            user = await db.get(User, uid)
            assert user is not None
            await friends.accept(db, user, code, utcnow())
        return "ok"
    except friends.InvalidInvite:
        return "invalid"
    except ApiError as exc:
        return exc.code.value


async def test_one_code_accepted_concurrently_is_consumed_once(resources: Resources) -> None:
    a = (await signed_in(resources))[0]
    takers = [(await signed_in(resources))[0] for _ in range(6)]
    async with resources.sessionmaker() as db, db.begin():
        user = await db.get(User, a)
        assert user is not None
        code = (await friends.create_invite(db, user, "en", utcnow()))["code"]
    outcomes = await asyncio.gather(*(_accept(resources, uid, code) for uid in takers))
    assert sorted(outcomes) == ["invalid"] * 5 + ["ok"]
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(Friendship)) == 1


async def test_mutual_codes_accepted_concurrently_make_one_friendship(resources: Resources) -> None:
    a, b = (await signed_in(resources))[0], (await signed_in(resources))[0]
    codes = {}
    for uid in (a, b):
        async with resources.sessionmaker() as db, db.begin():
            user = await db.get(User, uid)
            assert user is not None
            codes[uid] = (await friends.create_invite(db, user, "en", utcnow()))["code"]
    outcomes = await asyncio.gather(_accept(resources, a, codes[b]), _accept(resources, b, codes[a]))
    assert sorted(outcomes) == ["already_friends", "ok"]
    async with resources.sessionmaker() as db:
        assert await db.scalar(select(func.count()).select_from(Friendship)) == 1
        used = await db.scalar(select(func.count()).select_from(FriendInvite).where(FriendInvite.used_at.is_not(None)))
        assert used == 1                                                       # the losing invite stays unused


async def test_private_friends_hide_progress_and_online_uses_last_seen(api: TestClient, resources: Resources) -> None:
    a, ha = await signed_in(resources, private_profile=True)
    b, hb = await signed_in(resources)
    assert accept(api, hb, invite(api, ha)["code"])[0] == 200
    await earn(resources, a, 10, utcnow())
    await earn(resources, b, 25, utcnow())
    async with resources.sessionmaker() as db, db.begin():
        await db.execute(text("UPDATE users SET last_seen_at = now() - interval '30 seconds' WHERE id = :u"), {"u": a})
        await db.execute(text("UPDATE users SET last_seen_at = now() - interval '2 minutes' WHERE id = :u"), {"u": b})
    # (sessions were just created, so the 30 s last-seen throttle keeps these values during the requests)
    seen_by_b = api.get("/v1/friends", headers=hb).json()["items"][0]
    seen_by_a = api.get("/v1/friends", headers=ha).json()["items"][0]
    assert (seen_by_b["user_id"], seen_by_b["xp_week"], seen_by_b["streak_current"]) == (a, None, None)
    assert seen_by_b["online"] is True
    assert (seen_by_a["user_id"], seen_by_a["xp_week"], seen_by_a["online"]) == (b, 25, False)
    assert seen_by_a["streak_current"] == 0
    assert set(seen_by_a) == {"user_id", "display_name", "xp_week", "streak_current", "online", "avatar_key"}


async def test_unfriend_is_mutual_and_idempotent(api: TestClient, resources: Resources) -> None:
    a, ha = await signed_in(resources)
    _, hb = await signed_in(resources)
    assert accept(api, hb, invite(api, ha)["code"])[0] == 200
    assert api.delete(f"/v1/friends/{a}", headers=hb).status_code == 204
    assert friend_ids(api, ha) == [] == friend_ids(api, hb)
    assert api.delete(f"/v1/friends/{a}", headers=hb).status_code == 204
    assert api.delete("/v1/friends/usr_UNKNOWN", headers=hb).status_code == 204


async def test_friend_list_pages(api: TestClient, resources: Resources) -> None:
    _, ha = await signed_in(resources)
    others = []
    for _ in range(3):
        uid, headers = await signed_in(resources)
        assert accept(api, headers, invite(api, ha)["code"])[0] == 200
        others.append(uid)
    first = api.get("/v1/friends?limit=2", headers=ha).json()
    assert [i["user_id"] for i in first["items"]] == sorted(others)[:2] and first["next_cursor"] == sorted(others)[1]
    rest = api.get(f"/v1/friends?limit=2&cursor={first['next_cursor']}", headers=ha).json()
    assert [i["user_id"] for i in rest["items"]] == sorted(others)[2:] and rest["next_cursor"] is None
    assert api.get("/v1/friends?limit=51", headers=ha).status_code == 400
    assert api.get("/v1/friends?cursor=ses_x", headers=ha).status_code == 400


async def test_account_deletion_removes_friendships_invites_and_league_seat(
        api: TestClient, resources: Resources) -> None:
    a, ha = await signed_in(resources)
    b, hb = await signed_in(resources)
    _, hc = await signed_in(resources)
    assert accept(api, hb, invite(api, ha)["code"])[0] == 200                 # a's invite used by b
    assert accept(api, hc, invite(api, hb)["code"])[0] == 200                 # b's invite used by c
    open_code = invite(api, hb)["code"]
    await earn(resources, b, 10, utcnow())
    assert api.delete("/v1/me", headers=hb).status_code == 204
    assert friend_ids(api, ha) == [] and friend_ids(api, hc) == []
    assert accept(api, hc, open_code)[1]["error"]["code"] == "invite_invalid"  # type: ignore[index]
    async with resources.sessionmaker() as db, db.begin():
        await deletion.purge_user(db, resources.storage, b)
    async with resources.sessionmaker() as db:
        for table in ("league_members", "learner_tiers", "learner_achievements"):
            assert await db.scalar(text(f"SELECT count(*) FROM {table} WHERE user_id = :u"), {"u": b}) == 0
        assert await db.scalar(text("SELECT count(*) FROM friend_invites WHERE inviter_id = :u OR used_by = :u"),
                               {"u": b}) == 0
        kept = (await db.execute(text("SELECT used_by, used_at FROM friend_invites WHERE inviter_id = :u"),
                                 {"u": a})).one()
        assert kept.used_by is None and kept.used_at is not None             # a's history keeps no id of b


async def test_guess_limit_holds_under_a_concurrent_burst(resources: Resources) -> None:
    counter = FailureCounter(resources.redis, resources.settings, "invite_accept_user",
                             FAILURE_LIMITS["invite_accept_user"])

    async def attempt() -> bool:
        try:
            await counter.reserve("usr_burst")
            return True
        except ApiError as exc:
            assert exc.code.value == "rate_limited" and exc.details["retry_after_ms"] > 0
            return False

    admitted = await asyncio.gather(*(attempt() for _ in range(30)))
    assert admitted.count(True) == 10                                        # never more than the limit
    ttl = await resources.redis.pttl(counter._key("usr_burst"))
    assert 0 < ttl <= 3600 * 1000
    await counter.release("usr_burst")                                       # a successful attempt gives one back
    assert await attempt() and not await attempt()
    await counter.release("usr_none")                                        # releasing nothing stays at zero
    assert await resources.redis.get(counter._key("usr_none")) is None
