"""Every non-2xx response is the contract error envelope (API §3.4)."""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi import FastAPI, Query
from fastapi.testclient import TestClient

from app.contract import models
from app.errors import ApiError, ErrorCode, status_for
from tests.conftest import CONTRACT_HEADERS


def assert_envelope(response_json: object, code: str) -> models.ErrorEnvelope:
    envelope = models.ErrorEnvelope.model_validate(response_json)
    assert envelope.error.code == code
    return envelope


@pytest.fixture
def probe_client(app: FastAPI) -> Iterator[TestClient]:
    @app.get("/v1/_probe/raise/{code}")
    def raise_code(code: str) -> None:
        raise ApiError(ErrorCode(code), f"probe {code}", {"probe": True})

    @app.get("/v1/_probe/validate")
    def validate(limit: int = Query(..., ge=1, le=50)) -> dict[str, int]:
        return {"limit": limit}

    @app.get("/v1/_probe/crash")
    def crash() -> None:
        raise RuntimeError("database password=hunter2 leaked?")

    with TestClient(app, headers=CONTRACT_HEADERS, raise_server_exceptions=False) as client:
        yield client


@pytest.mark.parametrize("code", list(ErrorCode))
def test_each_code_maps_to_its_status(probe_client: TestClient, code: ErrorCode) -> None:
    response = probe_client.get(f"/v1/_probe/raise/{code.value}")
    assert response.status_code == status_for(code)
    envelope = assert_envelope(response.json(), code.value)
    assert envelope.error.details == {"probe": True}
    assert response.headers["Qabas-Contract"] == "10"


def test_status_table() -> None:
    assert status_for(ErrorCode.validation_error) == 400
    assert status_for(ErrorCode.prerequisite_unmet) == 409
    assert status_for(ErrorCode.review_stale) == 409
    assert status_for(ErrorCode.client_outdated) == 426
    assert status_for(ErrorCode.upstream_unavailable) == 503


def test_validation_error_is_400_without_input_echo(probe_client: TestClient) -> None:
    response = probe_client.get("/v1/_probe/validate", params={"limit": "secret-learner-text"})
    assert response.status_code == 400
    envelope = assert_envelope(response.json(), "validation_error")
    assert envelope.error.details["field"] == "limit"
    assert "secret-learner-text" not in response.text


def test_unknown_route_is_not_found(client: TestClient) -> None:
    response = client.get("/v1/does-not-exist")
    assert response.status_code == 404
    assert_envelope(response.json(), "not_found")


def test_wrong_method_is_not_found(probe_client: TestClient) -> None:
    response = probe_client.delete("/v1/_probe/validate")
    assert response.status_code == 404
    assert_envelope(response.json(), "not_found")


def test_unhandled_exception_is_500_without_details(probe_client: TestClient) -> None:
    response = probe_client.get("/v1/_probe/crash")
    assert response.status_code == 500
    assert_envelope(response.json(), "internal_error")
    assert "hunter2" not in response.text
