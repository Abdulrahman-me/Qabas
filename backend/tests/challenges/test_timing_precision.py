"""Server-measured times keep exact millisecond boundaries for human and seeded bot play."""
from datetime import timedelta

import pytest

from app.services.challenges.play import _ms


def test_every_millisecond_in_a_duel_question_is_preserved():
    for expected in range(15_001):
        assert _ms(timedelta(milliseconds=expected)) == expected


@pytest.mark.parametrize(("microseconds", "expected"), [
    (-1, 0), (0, 0), (999, 0), (1000, 1), (1001, 1),
    (4_006_999, 4006), (4_007_000, 4007), (14_999_999, 14999), (15_000_000, 15000),
])
def test_submillisecond_time_is_floored_and_negative_time_clamped(microseconds, expected):
    assert _ms(timedelta(microseconds=microseconds)) == expected
