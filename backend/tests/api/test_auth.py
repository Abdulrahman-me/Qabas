"""Guest and reviewer authentication, revocable sessions and lockouts (API §6.1, backend §5, AD-20)."""

from __future__ import annotations

import hashlib
import hmac
import unicodedata
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from pydantic import SecretStr

from app.config import Settings
from app.contract import models as C
from app.main import create_app
from app.registries import guest_name_words, selectable_avatar_keys
from app.services.platform import passwords
from tests.api.helpers import bearer, execute, query
from tests.conftest import CONTRACT_HEADERS, TEST_PEPPER

pytestmark = pytest.mark.integration


def new_guest(api: TestClient, timezone: str = "Asia/Riyadh") -> C.AuthResp:
    response = api.post("/v1/auth/guest", json={"timezone": timezone})
    assert response.status_code == 201, response.text
    return C.AuthResp.model_validate(response.json())


def error_code(response_json: object) -> str:
    return C.ErrorEnvelope.model_validate(response_json).error.code


# --- guests -------------------------------------------------------------------------------------

def test_guest_creation_returns_a_contract_user(api: TestClient) -> None:
    auth = new_guest(api)
    user = auth.user
    assert user.role == "learner" and user.language == "ar" and user.track == "explorer"
    assert user.daily_goal_minutes == 10 and user.timezone == "Asia/Riyadh"
    assert user.onboarding_completed is False and user.private_profile is True and user.goal_anchor is None
    assert user.avatar_key in selectable_avatar_keys()
    word, number = user.display_name.split(" ")
    assert word in guest_name_words("ar")
    assert all(unicodedata.name(ch).startswith("ARABIC-INDIC DIGIT") for ch in number)
    assert user.user_id.startswith("usr_") and user.created_at.endswith("Z")


@pytest.mark.parametrize("body", [{"timezone": "Mars/Olympus"}, {"timezone": "localtime"}, {"timezone": "Factory"},
                                  {"timezone": "posixrules"}, {"timezone": "../etc/passwd"}, {},
                                  {"timezone": "UTC", "religion": "x"}])
def test_guest_creation_validates_input(api: TestClient, body: dict[str, str]) -> None:
    response = api.post("/v1/auth/guest", json=body)
    assert response.status_code == 400
    assert error_code(response.json()) == "validation_error"


def test_only_the_token_hmac_is_stored(api: TestClient, integration_settings: Settings) -> None:
    auth = new_guest(api)
    rows = query(integration_settings.database_url, "SELECT token_hmac, expires_at FROM auth_sessions")
    assert len(rows) == 1
    expected = hmac.new(TEST_PEPPER.encode(), auth.access_token.encode(), hashlib.sha256).digest()
    assert bytes(rows[0]["token_hmac"]) == expected
    assert auth.access_token.encode() not in bytes(rows[0]["token_hmac"])
    assert rows[0]["expires_at"] is None  # guests: no fixed expiry


def test_token_authenticates_and_bad_tokens_are_rejected(api: TestClient) -> None:
    auth = new_guest(api)
    me = api.get("/v1/me", headers=bearer(auth.access_token))
    assert me.status_code == 200 and me.json()["user_id"] == auth.user.user_id
    for headers in ({}, bearer("not-a-real-token"), {"Authorization": f"Basic {auth.access_token}"}):
        response = api.get("/v1/me", headers=headers)
        assert response.status_code == 401
        assert error_code(response.json()) == "unauthorized"
        assert response.headers["WWW-Authenticate"] == "Bearer"


def test_guest_creation_is_rate_limited_per_address(api: TestClient) -> None:
    for _ in range(10):
        new_guest(api)
    response = api.post("/v1/auth/guest", json={"timezone": "UTC"})
    assert response.status_code == 429
    envelope = C.ErrorEnvelope.model_validate(response.json())
    assert envelope.error.code == "rate_limited" and envelope.error.details["retry_after_ms"] > 0
    assert int(response.headers["Retry-After"]) >= 1


def test_revocation_takes_effect_immediately(api: TestClient, integration_settings: Settings) -> None:
    auth = new_guest(api)
    assert api.get("/v1/me", headers=bearer(auth.access_token)).status_code == 200
    execute(integration_settings.database_url, "UPDATE auth_sessions SET revoked_at = now()")
    assert api.get("/v1/me", headers=bearer(auth.access_token)).status_code == 401


def test_inactive_guest_sessions_expire_after_180_days(api: TestClient, integration_settings: Settings) -> None:
    auth = new_guest(api)
    url = integration_settings.database_url
    execute(url, "UPDATE auth_sessions SET last_used_at = now() - interval '181 days'")
    assert api.get("/v1/me", headers=bearer(auth.access_token)).status_code == 401
    assert query(url, "SELECT revoked_at FROM auth_sessions")[0]["revoked_at"] is not None


def test_last_seen_is_updated_with_throttling(api: TestClient, integration_settings: Settings) -> None:
    auth = new_guest(api)
    url = integration_settings.database_url
    execute(url, "UPDATE auth_sessions SET last_used_at = now() - interval '1 hour'")
    api.get("/v1/me", headers=bearer(auth.access_token))
    first = query(url, "SELECT u.last_seen_at, s.last_used_at FROM users u JOIN auth_sessions s ON s.user_id = u.id")[0]
    assert first["last_seen_at"] is not None
    api.get("/v1/me", headers=bearer(auth.access_token))
    second = query(url, "SELECT last_used_at FROM auth_sessions")[0]
    assert second["last_used_at"] == first["last_used_at"]  # within 30 s: not rewritten


def test_pepper_rotation_keeps_sessions_and_rehashes(api: TestClient, integration_settings: Settings) -> None:
    auth = new_guest(api)
    rotated = integration_settings.model_copy(update={
        "auth_token_pepper": SecretStr("new-pepper-abcdefabcdefabcdefabcdef"),
        "auth_token_pepper_previous": SecretStr(TEST_PEPPER)})
    with TestClient(create_app(rotated), headers=CONTRACT_HEADERS, raise_server_exceptions=False) as client:
        assert client.get("/v1/me", headers=bearer(auth.access_token)).status_code == 200
    stored = bytes(query(rotated.database_url, "SELECT token_hmac FROM auth_sessions")[0]["token_hmac"])
    assert stored == hmac.new(b"new-pepper-abcdefabcdefabcdefabcdef", auth.access_token.encode(),
                              hashlib.sha256).digest()


# --- reviewers ------------------------------------------------------------------------------------

REVIEWER_PASSWORD = "correct horse battery staple"


def add_reviewer(url: str, email: str = "reviewer@example.test", *, deactivated: bool = False) -> str:
    user_id = "usr_rev" + hashlib.sha256(email.encode()).hexdigest()[:8]
    execute(url, "INSERT INTO users (id, display_name, avatar_key, timezone, role, email, password_hash, "
                 "onboarding_completed, deactivated_at) VALUES ($1, 'Reviewer', 'traveler_01', 'Asia/Riyadh', "
                 "'reviewer', $2, $3, true, $4)",
            user_id, email, passwords.hash_password(REVIEWER_PASSWORD),
            datetime.now(UTC) if deactivated else None)
    return user_id


def login(api: TestClient, email: str, password: str = REVIEWER_PASSWORD) -> object:
    return api.post("/v1/auth/reviewer", json={"email": email, "password": password})


def test_reviewer_login_issues_a_12_hour_session(api: TestClient, integration_settings: Settings) -> None:
    add_reviewer(integration_settings.database_url)
    response = login(api, "Reviewer@Example.TEST")  # emails are case-insensitive
    assert response.status_code == 200, response.text
    auth = C.AuthResp.model_validate(response.json())
    assert auth.user.role == "reviewer"
    row = query(integration_settings.database_url, "SELECT created_at, expires_at FROM auth_sessions")[0]
    assert row["expires_at"] - row["created_at"] == timedelta(hours=12)
    assert api.post("/v1/onboarding", json={"track_choice": "explorer", "language": "ar", "familiarity": None,
                                            "daily_goal_minutes": 10, "private_profile": True, "goal_anchor": None},
                    headers=bearer(auth.access_token)).status_code == 403


def test_expired_reviewer_session_is_rejected(api: TestClient, integration_settings: Settings) -> None:
    add_reviewer(integration_settings.database_url)
    token = login(api, "reviewer@example.test").json()["access_token"]
    execute(integration_settings.database_url, "UPDATE auth_sessions SET expires_at = now() - interval '1 second'")
    assert api.get("/v1/me", headers=bearer(token)).status_code == 401


def test_login_failures_are_generic(api: TestClient, integration_settings: Settings) -> None:
    add_reviewer(integration_settings.database_url)
    add_reviewer(integration_settings.database_url, "gone@example.test", deactivated=True)
    responses = [login(api, "reviewer@example.test", "wrong password!!"), login(api, "nobody@example.test"),
                 login(api, "gone@example.test")]
    assert {r.status_code for r in responses} == {401}
    assert len({r.json()["error"]["message"] for r in responses}) == 1


def test_account_lockout_after_five_failures(api: TestClient, integration_settings: Settings) -> None:
    add_reviewer(integration_settings.database_url)
    for _ in range(5):
        assert login(api, "reviewer@example.test", "wrong password!!").status_code == 401
    locked = login(api, "reviewer@example.test")  # even the right password
    assert locked.status_code == 429
    assert locked.json()["error"]["details"]["retry_after_ms"] > 0


def test_address_lockout_spans_accounts(api: TestClient, integration_settings: Settings) -> None:
    add_reviewer(integration_settings.database_url)
    for i in range(5):
        login(api, f"guess{i}@example.test", "wrong password!!")
    assert login(api, "reviewer@example.test").status_code == 429


def test_learner_cannot_use_reviewer_login(api: TestClient) -> None:
    assert login(api, "learner@example.test").status_code == 401
