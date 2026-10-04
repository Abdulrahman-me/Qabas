"""Readiness against the real native Postgres and Redis (backend/.env or CI environment)."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.config import Environment, Settings, get_settings
from app.main import create_app

pytestmark = pytest.mark.integration


def test_ready_with_real_services() -> None:
    with TestClient(create_app()) as client:
        response = client.get("/health/ready")
    assert response.status_code == 200, response.json()
    assert response.json() == {"status": "ready", "checks": {"database": "ok", "redis": "ok"}}


def test_not_ready_reports_failing_dependency_without_secrets(monkeypatch: pytest.MonkeyPatch) -> None:
    broken = Settings(app_env=Environment.test, redis_url="redis://127.0.0.1:1/0",
                      database_url="postgresql+asyncpg://nobody:topsecret@127.0.0.1:1/none")
    get_settings.cache_clear()
    monkeypatch.setattr("app.api.health.get_settings", lambda: broken)
    with TestClient(create_app(broken)) as client:
        response = client.get("/health/ready")
    assert response.status_code == 503
    body = response.json()
    assert body["status"] == "unavailable"
    assert body["checks"]["database"].startswith("unavailable")
    assert body["checks"]["redis"].startswith("unavailable")
    assert "topsecret" not in response.text
