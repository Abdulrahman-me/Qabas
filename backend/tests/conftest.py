from __future__ import annotations

import asyncio
from collections.abc import Iterator
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

import pytest
import redis
from alembic import command
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import SecretStr

from app.config import Environment, Settings, get_settings
from app.main import create_app
from tests.support.db import alembic_config, reset_schema, resolve_test_database_url, truncate_all

CONTRACT_HEADERS = {"Qabas-Contract": "10", "Qabas-Client": "android/1.0.0"}
TEST_PEPPER = "test-pepper-0123456789abcdef0123456789abcdef"


@pytest.fixture
def settings() -> Settings:
    return Settings(app_env=Environment.test, min_app_version="1.0.0")


@pytest.fixture
def app(settings: Settings) -> FastAPI:
    return create_app(settings)


@pytest.fixture
def client(app: FastAPI) -> Iterator[TestClient]:
    with TestClient(app, headers=CONTRACT_HEADERS, raise_server_exceptions=False) as test_client:
        yield test_client


@pytest.fixture
def bare_client(app: FastAPI) -> Iterator[TestClient]:
    """A client that sends no contract identity headers."""
    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client


# ----------------------------------------------------------------------------- real database/redis

@pytest.fixture(scope="session")
def migrated_url() -> Iterator[str]:
    """Fresh ``public`` schema, migrated base -> head -> base -> head (a round trip on every run)."""
    url = resolve_test_database_url()
    asyncio.run(reset_schema(url))
    config = alembic_config(url)
    command.upgrade(config, "head")
    command.downgrade(config, "base")
    command.upgrade(config, "head")
    yield url


def test_redis_url() -> str:
    """The configured Redis with database index 15, reserved for tests (flushed between tests)."""
    parts = urlsplit(get_settings().redis_url)
    return urlunsplit((parts.scheme, parts.netloc, "/15", "", ""))


test_redis_url.__test__ = False  # type: ignore[attr-defined]


@pytest.fixture
def integration_settings(migrated_url: str, tmp_path: Path) -> Settings:
    return Settings(
        app_env=Environment.test,
        database_url=migrated_url,
        redis_url=test_redis_url(),
        auth_token_pepper=SecretStr(TEST_PEPPER),
        storage_signing_key=SecretStr("test-signing-key"),
        local_storage_dir=tmp_path / "storage",
        min_app_version="1.0.0",
    )


@pytest.fixture
def clean_state(migrated_url: str) -> None:
    asyncio.run(truncate_all(migrated_url))
    client = redis.Redis.from_url(test_redis_url())
    try:
        client.flushdb()
    finally:
        client.close()


@pytest.fixture
def api(integration_settings: Settings, clean_state: None) -> Iterator[TestClient]:
    """The real app against the real test database and Redis, starting from an empty state."""
    with TestClient(create_app(integration_settings), headers=CONTRACT_HEADERS,
                    raise_server_exceptions=False) as test_client:
        yield test_client
