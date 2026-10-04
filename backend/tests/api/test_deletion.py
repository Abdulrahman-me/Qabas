"""``DELETE /me``: immediate revocation, then a complete, idempotent purge (API §6.2, AD-21)."""

from __future__ import annotations

import asyncio

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.runtime import Resources
from app.services.platform import deletion, outbox
from app.services.platform.storage import Bucket, user_prefix
from tests.api.helpers import bearer, execute, execute_many, query

pytestmark = pytest.mark.integration

LEARNER_TABLES = ("auth_sessions", "sessions", "learner_concepts", "learner_lessons", "learner_units", "xp_events",
                  "daily_activity", "quests", "recitation_checks", "idempotency_keys")


def give_learner_data(url: str, user_id: str) -> None:
    """Synthetic learning state touching every purged table."""
    statements: list[tuple[str, tuple[object, ...]]] = [
        ("INSERT INTO units (id, index, title, subtitle, tracks) VALUES ('unit_9', 9, '{}', '{}', ARRAY['explorer']) "
         "ON CONFLICT DO NOTHING", ()),
        ("INSERT INTO concepts (id, unit_id, title) VALUES ('con_del', 'unit_9', '{}') ON CONFLICT DO NOTHING", ()),
        ("INSERT INTO lessons (id, unit_id, index, lesson_type, estimated_minutes) "
         "VALUES ('les_del', 'unit_9', 1, 'concept', 8) ON CONFLICT DO NOTHING", ()),
        ("INSERT INTO learner_concepts (user_id, concept_id, mastery) VALUES ($1, 'con_del', 0.5)", (user_id,)),
        ("INSERT INTO learner_lessons (user_id, lesson_id, completed_at) VALUES ($1, 'les_del', now())", (user_id,)),
        ("INSERT INTO learner_units (user_id, unit_id, started_at) VALUES ($1, 'unit_9', now())", (user_id,)),
        ("INSERT INTO xp_events (user_id, reason, xp, ref_type, ref_id, week_key, local_date) "
         "VALUES ($1, 'lesson_complete', 10, 'session', 'ses_x', '2026-W40', current_date)", (user_id,)),
        ("INSERT INTO daily_activity (user_id, local_date, minutes) VALUES ($1, current_date, 5)", (user_id,)),
        ("INSERT INTO quests (user_id, local_date, slot, kind, goal, reward_xp) "
         "VALUES ($1, current_date, 1, 'earn_xp', 30, 10)", (user_id,)),
        ("INSERT INTO sessions (id, user_id, kind, mode, feedback_mode, language, variant, items_snapshot, "
         "served_exercises, contract_revision) VALUES ($2, $1, 'review', 'cards', 'immediate', 'ar', 'explorer', "
         "'{}', '[]', 10)", (user_id, f"ses_{user_id[4:]}")),
        ("INSERT INTO recitation_checks (id, user_id, surah, ayah, checked_text_sha256, status, passed, words, "
         "summary) VALUES ($2, $1, 1, 1, $3, 'unclear', false, '[]', '{}')",
         (user_id, f"rchk_{user_id[4:]}", "0" * 64)),
        ("INSERT INTO idempotency_keys (user_id, key, request_hash, response_status, response_body) "
         "VALUES ($1, 'k', $2, 201, '{}')", (user_id, "1" * 64)),
    ]
    execute_many(url, statements)


def counts(url: str, user_id: str) -> dict[str, int]:
    sql = " UNION ALL ".join(f"SELECT '{t}' AS t, count(*) AS n FROM {t} WHERE user_id = $1" for t in LEARNER_TABLES)
    return {r["t"]: r["n"] for r in query(url, sql, user_id)}


def relay(settings: Settings) -> int:
    async def main() -> int:
        resources = Resources.create(settings)
        deletion.configure_storage(resources.storage)
        try:
            return await outbox.relay(resources.sessionmaker)
        finally:
            await resources.close()

    return asyncio.run(main())


def test_delete_me_revokes_immediately_and_purges(api: TestClient, integration_settings: Settings) -> None:
    url = integration_settings.database_url
    auth = api.post("/v1/auth/guest", json={"timezone": "Asia/Riyadh"}).json()
    token, user_id = auth["access_token"], auth["user"]["user_id"]
    give_learner_data(url, user_id)
    storage = api.app.state.resources.storage  # type: ignore[attr-defined]
    storage.put(Bucket.private, f"{user_prefix(user_id)}attachments/a1.png", b"png", "image/png")

    response = api.delete("/v1/me", headers=bearer(token))
    assert response.status_code == 204 and response.content == b""
    assert api.get("/v1/me", headers=bearer(token)).status_code == 401       # old token: 401
    assert api.delete("/v1/me", headers=bearer(token)).status_code == 401
    job = query(url, "SELECT completed_at FROM deletion_jobs WHERE user_id = $1", user_id)
    assert len(job) == 1 and job[0]["completed_at"] is None
    assert query(url, "SELECT kind FROM outbox_events WHERE event_key = $1", f"user:{user_id}:purge")

    assert relay(integration_settings) == 1
    assert counts(url, user_id) == dict.fromkeys(LEARNER_TABLES, 0)
    assert not storage.exists(Bucket.private, f"{user_prefix(user_id)}attachments/a1.png")
    user = query(url, "SELECT display_name, goal_anchor, deleted_at FROM users WHERE id = $1", user_id)[0]
    assert user["display_name"] == "deleted" and user["goal_anchor"] is None and user["deleted_at"] is not None
    job = query(url, "SELECT completed_at, steps FROM deletion_jobs WHERE user_id = $1", user_id)[0]
    assert job["completed_at"] is not None and "purge" in job["steps"]
    assert relay(integration_settings) == 0  # processed once; nothing left


def test_reviewers_cannot_delete_themselves(api: TestClient, integration_settings: Settings) -> None:
    from tests.api.test_auth import add_reviewer, login

    add_reviewer(integration_settings.database_url)
    token = login(api, "reviewer@example.test").json()["access_token"]
    response = api.delete("/v1/me", headers=bearer(token))
    assert response.status_code == 403
    assert api.get("/v1/me", headers=bearer(token)).status_code == 200


def test_repurge_after_restore(api: TestClient, integration_settings: Settings) -> None:
    url = integration_settings.database_url
    auth = api.post("/v1/auth/guest", json={"timezone": "UTC"}).json()
    user_id = auth["user"]["user_id"]
    api.delete("/v1/me", headers=bearer(auth["access_token"]))
    relay(integration_settings)
    # Simulate restoring a backup taken before the deletion: the data and the account are back.
    execute(url, "UPDATE users SET deleted_at = NULL, display_name = 'Restored' WHERE id = $1", user_id)
    give_learner_data(url, user_id)

    async def repurge() -> int:
        resources = Resources.create(integration_settings)
        try:
            async with resources.sessionmaker() as db, db.begin():
                return await deletion.repurge_all(db, resources.storage)
        finally:
            await resources.close()

    assert asyncio.run(repurge()) == 1
    assert counts(url, user_id) == dict.fromkeys(LEARNER_TABLES, 0)
    assert query(url, "SELECT deleted_at FROM users WHERE id = $1", user_id)[0]["deleted_at"] is not None
