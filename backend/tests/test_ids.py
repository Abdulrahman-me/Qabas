from __future__ import annotations

import re

import pytest

from app.db.ids import PREFIXES, new_id


def test_format_and_uniqueness() -> None:
    ids = {new_id("ses") for _ in range(2000)}
    assert len(ids) == 2000
    assert all(re.fullmatch(r"ses_[0-9A-HJKMNP-TV-Z]{26}", i) for i in ids)


def test_time_ordered() -> None:
    assert new_id("usr", now_ms=1_000) < new_id("usr", now_ms=2_000)


def test_contract_prefixes_only() -> None:
    assert {"usr", "ses", "les", "ex", "rchk", "scn"} <= PREFIXES
    with pytest.raises(ValueError):
        new_id("user")
