"""Onboarding and profile (API §6.1-6.2): curiosity onboarding without any religion question (AD-33)."""

from __future__ import annotations

from typing import Any

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.contract import models as C
from tests.api.helpers import bearer, execute, onboarding_body, query, seed_units

pytestmark = pytest.mark.integration


def guest_token(api: TestClient) -> str:
    response = api.post("/v1/auth/guest", json={"timezone": "Asia/Riyadh"})
    assert response.status_code == 201
    return str(response.json()["access_token"])


def onboard(api: TestClient, token: str, **overrides: Any) -> C.OnboardingResp:
    response = api.post("/v1/onboarding", json=onboarding_body(**overrides), headers=bearer(token))
    assert response.status_code == 200, response.text
    return C.OnboardingResp.model_validate(response.json())


@pytest.mark.parametrize(("choice", "track", "start"), [
    ("explorer", "explorer", "unit_0"), ("undisclosed", "explorer", "unit_0"), ("new_muslim", "new_muslim", "unit_1"),
])
def test_track_choice_maps_to_track_and_start_unit(api: TestClient, integration_settings: Settings,
                                                   choice: str, track: str, start: str) -> None:
    seed_units(integration_settings.database_url)
    result = onboard(api, guest_token(api), track_choice=choice, language="en", familiarity="some",
                     daily_goal_minutes=15, private_profile=False)
    assert result.user.track == track and result.start_unit_id == start
    assert result.user.onboarding_completed is True and result.user.language == "en"
    assert result.user.familiarity == "some" and result.user.daily_goal_minutes == 15
    assert result.user.private_profile is False
    assert result.next_step == C.NextStep(type="pretest", reason="new_unit_pretest", unit_id=start, lesson_id=None,
                                          title="A quick check before you start", due_reviews_count=0)


def test_goal_anchor_changes_neither_start_nor_next_step(api: TestClient, integration_settings: Settings) -> None:
    seed_units(integration_settings.database_url)
    without = onboard(api, guest_token(api))
    with_anchor = onboard(api, guest_token(api), goal_anchor="who_was_muhammad")
    assert with_anchor.user.goal_anchor == "who_was_muhammad"
    assert with_anchor.start_unit_id == without.start_unit_id
    assert with_anchor.next_step == without.next_step


def test_unpublished_start_unit_means_no_step_yet(api: TestClient, integration_settings: Settings) -> None:
    # Nothing published anywhere: every unit of the path is coming soon (D-38, D-44).
    seed_units(integration_settings.database_url, unit0_coming_soon=True, unit1_coming_soon=True)
    result = onboard(api, guest_token(api))
    assert result.start_unit_id == "unit_0"
    assert result.next_step == C.NextStep(type="journey_complete", reason="all_done", unit_id=None, lesson_id=None,
                                          title=None, due_reviews_count=0)


@pytest.mark.parametrize("override", [
    {"goal_anchor": "not_a_registered_anchor"},
    {"religion": "anything"},          # no endpoint accepts a religion/worldview field
    {"track_choice": "muslim"},
    {"daily_goal_minutes": 7},
])
def test_onboarding_rejects_invalid_input(api: TestClient, integration_settings: Settings,
                                          override: dict[str, Any]) -> None:
    seed_units(integration_settings.database_url)
    response = api.post("/v1/onboarding", json=onboarding_body(**override), headers=bearer(guest_token(api)))
    assert response.status_code == 400
    assert C.ErrorEnvelope.model_validate(response.json()).error.code == "validation_error"


def test_onboarding_requires_all_contract_fields(api: TestClient, integration_settings: Settings) -> None:
    seed_units(integration_settings.database_url)
    body = onboarding_body()
    del body["goal_anchor"]  # required, nullable
    assert api.post("/v1/onboarding", json=body, headers=bearer(guest_token(api))).status_code == 400


def test_no_religion_field_anywhere_in_the_user_contract() -> None:
    fields = set(C.User.model_fields) | set(C.OnboardingReq.model_fields) | set(C.MePatch.model_fields)
    assert not {f for f in fields if any(word in f for word in ("relig", "faith", "belief", "worldview"))}


def test_get_and_patch_me(api: TestClient) -> None:
    token = guest_token(api)
    patched = api.patch("/v1/me", json={"language": "en", "daily_goal_minutes": 20, "display_name": "  Sara   K ",
                                         "avatar_key": "traveler_07", "timezone": "Europe/London",
                                         "private_profile": False, "goal_anchor": "why_pray"},
                        headers=bearer(token))
    assert patched.status_code == 200, patched.text
    user = C.User.model_validate(patched.json())
    assert (user.language, user.daily_goal_minutes, user.display_name, user.avatar_key, user.timezone) == (
        "en", 20, "Sara K", "traveler_07", "Europe/London")
    assert user.private_profile is False and user.goal_anchor == "why_pray"
    assert C.User.model_validate(api.get("/v1/me", headers=bearer(token)).json()) == user


@pytest.mark.parametrize("body", [
    {}, {"language": None}, {"display_name": "A"}, {"display_name": "x" * 25}, {"avatar_key": "traveler_bot"},
    {"avatar_key": "unknown"}, {"timezone": "Nowhere/City"}, {"goal_anchor": "nope"}, {"track": "muslim"},
    {"email": "x@example.test"},
])
def test_patch_me_validation(api: TestClient, body: dict[str, Any]) -> None:
    response = api.patch("/v1/me", json=body, headers=bearer(guest_token(api)))
    assert response.status_code == 400, response.text


def test_track_change_keeps_progress(api: TestClient, integration_settings: Settings) -> None:
    url = integration_settings.database_url
    seed_units(url)
    token = guest_token(api)
    user_id = onboard(api, token).user.user_id
    execute(url, "INSERT INTO curriculum_slots (lesson_id, unit_id, index, working_title) "
                 "VALUES ('les_u1_l1', 'unit_1', 0, '{}')")
    execute(url, "INSERT INTO lessons (id, unit_id, index, lesson_type, estimated_minutes) "
                 "VALUES ('les_u1_l1', 'unit_1', 0, 'concept', 8)")
    execute(url, "INSERT INTO learner_lessons (user_id, lesson_id, completed_at) VALUES ($1, 'les_u1_l1', now())",
            user_id)
    response = api.patch("/v1/me", json={"track": "new_muslim"}, headers=bearer(token))
    assert response.status_code == 200 and response.json()["track"] == "new_muslim"
    kept = query(url, "SELECT lesson_id FROM learner_lessons WHERE user_id = $1", user_id)
    assert [r["lesson_id"] for r in kept] == ["les_u1_l1"]
