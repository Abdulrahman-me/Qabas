"""Contract identity headers and 426 client_outdated (API §3.2, decision D-15)."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.contract import models


def _error(response_json: object) -> models.ErrorBody:
    return models.ErrorEnvelope.model_validate(response_json).error


def test_missing_contract_header_is_outdated(bare_client: TestClient) -> None:
    response = bare_client.get("/v1/anything")
    assert response.status_code == 426
    error = _error(response.json())
    assert error.code == "client_outdated"
    assert error.details == {"min_contract": 10, "min_app_version": "1.0.0"}
    assert response.headers["Qabas-Contract"] == "10"


@pytest.mark.parametrize("value", ["9", "abc", "", "10.0"])
def test_old_or_invalid_revision_is_outdated(bare_client: TestClient, value: str) -> None:
    response = bare_client.get("/v1/anything", headers={"Qabas-Contract": value, "Qabas-Client": "ios/1.0.0"})
    assert response.status_code == 426


def test_missing_client_header_is_outdated(bare_client: TestClient) -> None:
    response = bare_client.get("/v1/anything", headers={"Qabas-Contract": "10"})
    assert response.status_code == 426


@pytest.mark.parametrize("value", ["android", "desktop/1.0.0", "ios/1.0", "web/v1.2.3"])
def test_malformed_client_header_is_validation_error(bare_client: TestClient, value: str) -> None:
    response = bare_client.get("/v1/anything", headers={"Qabas-Contract": "10", "Qabas-Client": value})
    assert response.status_code == 400
    error = _error(response.json())
    assert error.code == "validation_error"
    assert error.details == {"field": "Qabas-Client"}


def test_app_below_minimum_version_is_outdated(bare_client: TestClient) -> None:
    response = bare_client.get("/v1/anything", headers={"Qabas-Contract": "10", "Qabas-Client": "web/0.9.9"})
    assert response.status_code == 426


@pytest.mark.parametrize("client_value", ["android/1.0.0", "ios/2.3.4-beta.1", "web/1.0.0+build.7"])
def test_supported_client_reaches_routing(bare_client: TestClient, client_value: str) -> None:
    response = bare_client.get("/v1/anything", headers={"Qabas-Contract": "11", "Qabas-Client": client_value})
    assert response.status_code == 404  # passed the identity check; route does not exist yet
    assert response.headers["Qabas-Contract"] == "10"


def test_operational_paths_are_exempt(bare_client: TestClient) -> None:
    assert bare_client.get("/health/live").status_code == 200
    assert bare_client.get("/openapi.json").status_code == 200


def test_request_id_is_returned(client: TestClient) -> None:
    response = client.get("/health/live", headers={"X-Request-ID": "abcdef12-3456"})
    assert response.headers["X-Request-ID"] == "abcdef12-3456"
    generated = client.get("/health/live", headers={"X-Request-ID": "bad id!"}).headers["X-Request-ID"]
    assert generated != "bad id!" and len(generated) == 32


def test_cors_exposes_contract_header(settings_with_cors_client: TestClient) -> None:
    response = settings_with_cors_client.options(
        "/v1/anything",
        headers={"Origin": "https://app.example.test", "Access-Control-Request-Method": "GET",
                 "Access-Control-Request-Headers": "Authorization, Qabas-Contract, Qabas-Client"},
    )
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "https://app.example.test"
    blocked = settings_with_cors_client.options(
        "/v1/anything", headers={"Origin": "https://evil.example.test", "Access-Control-Request-Method": "GET"})
    assert "access-control-allow-origin" not in blocked.headers


@pytest.fixture
def settings_with_cors_client() -> TestClient:
    from app.config import Environment, Settings
    from app.main import create_app

    app = create_app(Settings(app_env=Environment.test, cors_allowed_origins=["https://app.example.test"]))
    return TestClient(app, raise_server_exceptions=False)
