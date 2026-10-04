"""Scoring exclusions and deterministic FSRS ratings, independent of the database."""

from datetime import UTC, datetime
from decimal import Decimal

import pytest
from fsrs import Rating

from app.models import LearnerConcept, SessionAnswer
from app.services.learning import spaced
from app.services.learning.finish import score


@pytest.mark.parametrize(("correct", "elapsed", "expected"), [
    ([True], [5999], Rating.Easy), ([True], [6000], Rating.Good),
    ([True], [None], Rating.Good), ([True, False], [4000, 4000], Rating.Again),
])
def test_rating_threshold_and_any_wrong(correct: list[bool], elapsed: list[int | None], expected: Rating) -> None:
    exercises = {f"ex_{i}": {"type": "multiple_choice", "concept_ids": ["con_a"]} for i in range(len(correct))}
    rows = [SessionAnswer(exercise_id=f"ex_{i}", is_retry=False, correct=c, elapsed_ms=elapsed[i])
            for i, c in enumerate(correct)]
    assert spaced.ratings(exercises, rows) == {"con_a": expected}


@pytest.mark.parametrize("rating", ["again", "hard", "good", "easy"])
def test_flashcard_overrides_and_persisted_card(rating: str) -> None:
    exercises = {"ex_a": {"type": "multiple_choice", "concept_ids": ["con_a"]},
                 "ex_b": {"type": "flashcard", "concept_ids": ["con_a"]}}
    rows = [SessionAnswer(exercise_id="ex_a", is_retry=False, correct=False, elapsed_ms=2000),
            SessionAnswer(exercise_id="ex_b", is_retry=False, correct=True, answer={"rating": rating})]
    assert spaced.ratings(exercises, rows) == {"con_a": spaced.RATINGS[rating]}
    row = LearnerConcept(user_id="usr_a", concept_id="con_a", mastery=Decimal(".5"))
    now = datetime(2026, 10, 4, tzinfo=UTC)
    spaced.update(row, spaced.RATINGS[rating], now)
    card = row.fsrs_card
    assert card and row.due_at > now and row.first_practiced_at == now
    spaced.update(row, Rating.Good, row.due_at)
    assert row.fsrs_card and row.fsrs_card["card_id"] == card["card_id"]
    assert row.first_practiced_at == now


def test_neutral_and_retry_do_not_schedule_and_percent_rounds_half_up() -> None:
    rows = [SessionAnswer(exercise_id="ex_a", is_retry=False, correct=None),
            SessionAnswer(exercise_id="ex_a", is_retry=True, correct=True)]
    assert spaced.ratings({"ex_a": {"type": "map_place", "concept_ids": ["con_a"]}}, rows) == {}
    assert score([]) == {"correct": 0, "total": 0, "percent": 0}
    assert score([SessionAnswer(correct=True), *[SessionAnswer(correct=False) for _ in range(7)]])["percent"] == 13
