"""Learner-facing tests on the contract's synthetic test curriculum, loaded through the real pipeline.

The curriculum is loaded once per module; each test starts with no users, sessions or learner state.
Tests that publish new content versions use ``fresh_curriculum`` instead.
"""

from __future__ import annotations

import asyncio
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
import redis
from fastapi.testclient import TestClient
from pydantic import SecretStr

from app.config import Environment, Settings
from app.content.test_curriculum import load_test_curriculum
from app.main import create_app
from app.runtime import Resources
from tests.conftest import CONTRACT_HEADERS, TEST_PEPPER, test_redis_url
from tests.support.db import truncate_all, truncate_learner_state


def make_settings(url: str, storage: Path) -> Settings:
    return Settings(app_env=Environment.test, database_url=url, redis_url=test_redis_url(),
                    auth_token_pepper=SecretStr(TEST_PEPPER), storage_signing_key=SecretStr("test-signing-key"),
                    local_storage_dir=storage, min_app_version="1.0.0")


async def _load(settings: Settings) -> None:
    resources = Resources.create(settings)
    try:
        async with resources.sessionmaker() as db, db.begin():
            await load_test_curriculum(db, settings)
    finally:
        await resources.close()


def load_curriculum(settings: Settings) -> None:
    asyncio.run(truncate_all(settings.database_url))
    asyncio.run(_load(settings))


@pytest.fixture(scope="module")
def curriculum_settings(migrated_url: str, tmp_path_factory: pytest.TempPathFactory) -> Settings:
    settings = make_settings(migrated_url, tmp_path_factory.mktemp("storage"))
    load_curriculum(settings)
    return settings


def _clear_learners(settings: Settings) -> None:
    asyncio.run(truncate_learner_state(settings.database_url))
    client = redis.Redis.from_url(test_redis_url())
    try:
        client.flushdb()
    finally:
        client.close()


@pytest.fixture
def learn_api(curriculum_settings: Settings) -> Iterator[TestClient]:
    """The real app over the loaded test curriculum, with no learners yet."""
    _clear_learners(curriculum_settings)
    with TestClient(create_app(curriculum_settings), headers=CONTRACT_HEADERS,
                    raise_server_exceptions=False) as client:
        yield client


@pytest.fixture
def fresh_curriculum(migrated_url: str, tmp_path: Path) -> Iterator[tuple[TestClient, Settings]]:
    """A freshly loaded curriculum this test may change (new versions); reloaded for the next module user."""
    settings = make_settings(migrated_url, tmp_path / "storage")
    load_curriculum(settings)
    _clear_learners(settings)
    with TestClient(create_app(settings), headers=CONTRACT_HEADERS, raise_server_exceptions=False) as client:
        yield client, settings
    asyncio.run(truncate_all(migrated_url))


def bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def learner(client: TestClient, *, track: str = "explorer", language: str = "ar") -> dict[str, str]:
    """A new onboarded learner; returns auth headers."""
    response = client.post("/v1/auth/guest", json={"timezone": "Asia/Riyadh"})
    assert response.status_code == 201, response.text
    headers = bearer(response.json()["access_token"])
    body: dict[str, Any] = {"track_choice": track, "language": language, "familiarity": None,
                            "daily_goal_minutes": 10, "private_profile": True, "goal_anchor": None}
    response = client.post("/v1/onboarding", json=body, headers=headers)
    assert response.status_code == 200, response.text
    return headers


def user_id(client: TestClient, headers: dict[str, str]) -> str:
    return str(client.get("/v1/me", headers=headers).json()["user_id"])
