"""Pinned py-fsrs scheduler; one persisted UTC card per concept, updated only at finish."""

import json
from collections import defaultdict
from datetime import UTC, datetime
from typing import Any

from fsrs import Card, Rating, Scheduler

from app.models import LearnerConcept, SessionAnswer

SCHEDULER = Scheduler(enable_fuzzing=False)
RATINGS = {"again": Rating.Again, "hard": Rating.Hard, "good": Rating.Good, "easy": Rating.Easy}


def ratings(exercises: dict[str, dict[str, Any]], answers: list[SessionAnswer]) -> dict[str, Rating]:
    practiced: dict[str, list[SessionAnswer]] = defaultdict(list)
    for answer in answers:
        if not answer.is_retry and answer.correct is not None:
            for concept in exercises[answer.exercise_id]["concept_ids"]:
                practiced[concept].append(answer)
    result = {}
    for concept, rows in practiced.items():
        cards = [r for r in rows if exercises[r.exercise_id]["type"] == "flashcard"]
        if cards:
            # Worst rating wins when authored content has multiple cards for the same concept.
            result[concept] = min(RATINGS[r.answer["rating"]] for r in cards if r.answer)
        elif any(r.correct is False for r in rows):
            result[concept] = Rating.Again
        elif all(r.elapsed_ms is not None for r in rows) and sum(r.elapsed_ms or 0 for r in rows) / len(rows) < 6000:
            result[concept] = Rating.Easy
        else:
            result[concept] = Rating.Good
    return result


def update(row: LearnerConcept, rating: Rating, now: datetime) -> None:
    card = Card.from_json(json.dumps(row.fsrs_card)) if row.fsrs_card else Card(due=now.astimezone(UTC))
    card, _ = SCHEDULER.review_card(card, rating, review_datetime=now.astimezone(UTC))
    row.fsrs_card = dict(card.to_dict())
    row.due_at = card.due
    row.first_practiced_at = row.first_practiced_at or now
    row.last_reviewed_at = now
