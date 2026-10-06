"""Stale operational receipts cannot override the owner-selected seven-day disclosure."""
import json

import pytest

from app.config import Environment, Settings
from app.errors import ApiError
from app.raqeeb.intake import retention_days


@pytest.mark.parametrize("days", [7, 30, 1, True, None])
def test_operational_policy_must_match_the_owner_selected_period(tmp_path, days):
    path = tmp_path / "input-policy.yaml"
    path.write_text(json.dumps({"schema": "qabas.raqeeb_input_policy/1", "status": "approved",
                               "approved_by": "Synthetic reviewer", "approved_on": "2026-10-06",
                               "report": "synthetic-test", "private_storage": "synthetic-private-storage",
                               "learner_disclosure": "synthetic-test", "attachment_retention_days": days}),
                    encoding="utf-8")
    settings = Settings(app_env=Environment.staging, auth_token_pepper="p" * 32, storage_signing_key="k" * 32,
                        raqeeb_input_policy_path=path, _env_file=None)
    if days == 7:
        assert retention_days(settings) == 7
    else:
        with pytest.raises(ApiError, match="pending approval"):
            retention_days(settings)


def test_owner_choice_does_not_approve_pending_operational_policy():
    settings = Settings(app_env=Environment.staging, auth_token_pepper="p" * 32, storage_signing_key="k" * 32,
                        _env_file=None)
    with pytest.raises(ApiError, match="pending approval"):
        retention_days(settings)
