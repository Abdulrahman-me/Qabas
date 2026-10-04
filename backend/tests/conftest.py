from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.config import Environment, Settings
from app.main import create_app

CONTRACT_HEADERS = {"Qabas-Contract": "10", "Qabas-Client": "android/1.0.0"}


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
