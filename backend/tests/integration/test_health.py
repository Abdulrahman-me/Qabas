"""Readiness against the real native Postgres and Redis."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app

pytestmark = pytest.mark.integration


def test_ready_with_real_services(api: TestClient) -> None:
    response = api.get("/health/ready")
    assert response.status_code == 200, response.json()
    assert response.json() == {"status": "ready", "checks": {
        "database": "ok", "redis": "ok", "live_coordinator": "ok"}}


def test_not_ready_reports_failing_dependency_without_secrets(integration_settings: Settings) -> None:
    broken = integration_settings.model_copy(update={
        "redis_url": "redis://127.0.0.1:1/0",
        "database_url": "postgresql+asyncpg://nobody:topsecret@127.0.0.1:1/none"})
    with TestClient(create_app(broken)) as client:
        response = client.get("/health/ready")
    assert response.status_code == 503
    body = response.json()
    assert body["status"] == "unavailable"
    assert body["checks"]["database"].startswith("unavailable")
    assert body["checks"]["redis"].startswith("unavailable")
    assert "topsecret" not in response.text
