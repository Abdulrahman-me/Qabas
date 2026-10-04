"""Deterministic answer validation, grading and evaluation building (backend §6.3, API §7). No LLM, no I/O.

Everything here works on the *served* learner exercise (exactly what the session snapshot shows, including a
quick review's 20 s timer) plus the private key and feedback of the pinned exercise version. Contract helpers
(``contextual``) supply the shape checks, key comparison and mastery arithmetic so the backend can't drift
from the contract's own validators.

Outcomes:
* ``answer: null`` (a timed exercise ran out) -> incorrect; every per-item result is false.
* ``{"skipped": true}`` (skippable recitation) and ``{"unavailable": true}`` (``map_place`` that cannot render)
  -> ``correct: null``: neutral, nothing disclosed, no mastery change.
* ``flashcard`` -> ``rating != "again"``; ``recite_verse`` -> the bound recitation check passed. Neither type
  discloses a ``correct_answer`` or ``details``.
* Everything else -> exact comparison with the private key; ``correct_answer`` is the key and ``details`` the
  per-type extras (§7).
"""

from __future__ import annotations

import copy
from collections import Counter
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from pydantic import ValidationError

from app.contract import contextual
from app.contract import models as C
from app.errors import ApiError, ErrorCode

NEUTRAL = ({"skipped": True}, {"unavailable": True})
NO_KEY_TYPES = ("flashcard", "recite_verse")
NOT_RETRYABLE = ("flashcard", "recite_verse")


@dataclass(frozen=True)
class Identity:
    exercise_id: str
    is_retry: bool


@dataclass(frozen=True)
class Graded:
    correct: bool | None
    correct_answer: dict[str, Any] | None
    details: dict[str, Any] | None


def invalid(message: str, **details: Any) -> ApiError:
    return ApiError(ErrorCode.validation_error, message, details)


# ---------------------------------------------------------------------------------------------- identity

def parse_identity(body: Any) -> Identity:
    """Read only ``exercise_id`` and ``is_retry`` (API §6.5 step 3): a recorded identity must replay before
    anything else in the body is inspected."""
    if not isinstance(body, dict):
        raise invalid("The request body must be a JSON object.", field="body")
    exercise_id, is_retry = body.get("exercise_id"), body.get("is_retry")
    if not isinstance(exercise_id, str) or not exercise_id:
        raise invalid("exercise_id is required.", field="exercise_id")
    if not isinstance(is_retry, bool):
        raise invalid("is_retry must be true or false.", field="is_retry")
    return Identity(exercise_id, is_retry)


# ---------------------------------------------------------------------------------------------- validation

def validate_submission(exercise: dict[str, Any], body: dict[str, Any], kind: str) -> dict[str, Any]:
    """Full validation of a fresh attempt against the served exercise (API §6.5 step 6) -> AnswerSubmit dict."""
    try:
        submitted: dict[str, Any] = C.AnswerSubmit.model_validate(body).model_dump(mode="json")
    except ValidationError as exc:
        field = str(exc.errors()[0]["loc"][0]) if exc.errors() and exc.errors()[0]["loc"] else "body"
        raise invalid("The answer does not match the expected format.", field=field) from None
    answer = body.get("answer")  # the raw answer: union coercion must not reshape what the learner sent
    submitted["answer"] = answer
    if exercise["type"] == "categorize" and answer is not None:
        _check_assignments(exercise, answer)
    try:
        # original_correct=False: retry eligibility was already decided from the stored first attempt.
        contextual.validate_attempt(exercise, submitted, kind, original_correct=False)
    except ValidationError:
        raise invalid("The answer does not match this exercise.", field="answer") from None
    except ValueError as exc:
        raise invalid(_message(str(exc)), field=_field(str(exc))) from None
    return submitted


def _field(message: str) -> str:
    return "elapsed_ms" if "elapsed_ms" in message or "deadline" in message else "answer"


def _message(message: str) -> str:
    known = {
        "timeout requires a timed exercise": "This exercise has no time limit; an answer is required.",
        "timeout cannot precede the served deadline": "A timeout cannot be reported before the time limit.",
        "elapsed_ms cannot be negative": "elapsed_ms cannot be negative.",
        "this recitation cannot be skipped": "This recitation cannot be skipped.",
    }
    return known.get(message, "The answer refers to something that was not served in this exercise.")


def _check_assignments(exercise: dict[str, Any], answer: Any) -> None:
    """Backend §6.3 ``categorize`` validation before grading, with a ``details.reason`` (decision D-58)."""
    if not isinstance(answer, dict) or set(answer) != {"assignments"} or not isinstance(answer["assignments"], list):
        raise invalid("Assign every item to a category.", field="answer", reason="duplicate_or_missing_item")
    payload = exercise["payload"]
    rows = answer["assignments"]
    if not all(isinstance(r, dict) and isinstance(r.get("item_id"), str) and isinstance(r.get("category_id"), str)
               for r in rows):
        raise invalid("Assign every item to a category.", field="answer", reason="duplicate_or_missing_item")
    items = [r["item_id"] for r in rows]
    served = [i["item_id"] for i in payload["items"]]
    if Counter(items) != Counter(served):
        raise invalid("Each item must be assigned exactly once within capacity.", field="answer",
                      reason="duplicate_or_missing_item")
    categories = {c["category_id"]: c for c in payload["categories"]}
    if any(r["category_id"] not in categories for r in rows):
        raise invalid("An item was assigned to a category that was not served.", field="answer",
                      reason="unknown_category")
    for category_id, count in Counter(r["category_id"] for r in rows).items():
        capacity = categories[category_id]["capacity"]
        if capacity is not None and count > capacity:
            # day_arc holds exactly one item per slot, so an over-full slot leaves another one missing.
            reason = "duplicate_or_missing_item" if payload["presentation"] == "day_arc" else "over_capacity"
            raise invalid("Each item must be assigned exactly once within capacity.", field="answer", reason=reason)


# ---------------------------------------------------------------------------------------------- grading

def grade(exercise: dict[str, Any], answer: Any, key: dict[str, Any] | None, feedback: dict[str, Any], *,
          recitation_passed: bool | None = None) -> Graded:
    typ = exercise["type"]
    if answer in NEUTRAL:
        return Graded(None, None, None)
    if typ == "flashcard":
        return Graded(answer["rating"] != "again", None, None)
    if typ == "recite_verse":
        if not isinstance(recitation_passed, bool):
            raise ValueError("a bound recitation check result is required")
        return Graded(recitation_passed, None, None)
    if key is None:
        raise ValueError(f"{exercise['exercise_id']}: no private key for a {typ} exercise")
    correct = bool(contextual.grade_answer(exercise, {"answer": answer}, key))
    return Graded(correct, copy.deepcopy(key), _details(exercise, answer or {}, key, feedback))


def _details(exercise: dict[str, Any], answer: dict[str, Any], key: dict[str, Any],
             feedback: dict[str, Any]) -> dict[str, Any] | None:
    typ, payload = exercise["type"], exercise["payload"]
    if typ == "true_false_reason":
        return {"value_correct": answer.get("value") == key["value"],
                "reason_correct": answer.get("reason_option_id") == key["reason_option_id"]}
    if typ in ("match_pairs", "fill_blank", "categorize"):
        if typ == "match_pairs":
            field, ident, chosen, result = "pairs", "left_id", "right_id", "pair_results"
            served = [x["item_id"] for x in payload["left"]]
        elif typ == "fill_blank":
            field, ident, chosen, result = "fills", "blank_id", "word_id", "blank_results"
            served = [x["blank_id"] for x in payload["segments"] if x["type"] == "blank"]
        else:
            field, ident, chosen, result = "assignments", "item_id", "category_id", "item_results"
            served = [x["item_id"] for x in payload["items"]]
        targets = {x[ident]: x[chosen] for x in key[field]}
        if set(targets) != set(served):
            raise ValueError(f"{exercise['exercise_id']}: the private key does not cover the served items")
        supplied = {x[ident]: x[chosen] for x in answer.get(field, [])}
        # One entry per item, in key order (a day_arc key lists the slots in day order).
        return {result: [{ident: i, "correct": supplied.get(i) == targets[i]} for i in targets]}
    if typ == "order_steps":
        supplied = answer.get("order", [])
        wrong = next((i for i, step in enumerate(key["order"]) if i >= len(supplied) or supplied[i] != step), None)
        return {"first_wrong_index": wrong}
    if typ == "timeline_order":
        # Revealed on a vertical timeline, so in the key's (chronological) order.
        dates = {d["event_id"]: d for d in feedback["event_dates"]}
        return {"event_dates": [copy.deepcopy(dates[e]) for e in key["order"]]}
    if typ == "map_place":
        return {"pin_labels": copy.deepcopy(feedback["pin_labels"])}
    if typ == "scenario":
        chosen_option = answer.get("option_id")
        # A timeout chose nothing, so there is no option feedback to show (decision D-59).
        return {"option_feedback": [copy.deepcopy(f) for f in feedback["option_feedback"]
                                    if f["option_id"] == chosen_option]}
    return None


# ---------------------------------------------------------------------------------------------- evaluation

def mastery_rule(exercise: dict[str, Any], submitted: dict[str, Any], kind: str, correct: bool | None) -> str:
    rule: str = contextual.mastery_rule(exercise, submitted, kind, correct)
    return rule


def mastery_after(before: Decimal, rule: str) -> Decimal:
    after: Decimal = contextual.update_mastery(before, rule)
    return after


def report(value: Decimal) -> float:
    reported: float = contextual.report_mastery(value)
    return reported


def evaluation(exercise: dict[str, Any], graded: Graded, feedback: dict[str, Any], source_ids: list[str], *,
               misconception: dict[str, Any] | None, mastery_changes: list[dict[str, Any]],
               xp_awarded: int) -> dict[str, Any]:
    """The ``AnswerEvaluation`` issued for an attempt; stored and replayed exactly as issued."""
    body = {"exercise_id": exercise["exercise_id"], "recorded": True, "correct": graded.correct,
            "correct_answer": graded.correct_answer, "details": graded.details,
            "explanation": copy.deepcopy(feedback["explanation"]), "source_ids": list(source_ids),
            "misconception": misconception, "mastery_changes": mastery_changes, "term_changes": [],
            "xp_awarded": xp_awarded}
    checked: dict[str, Any] = C.AnswerEvaluation.model_validate(body).model_dump(mode="json")
    return checked


def recorded_only(exercise_id: str) -> dict[str, Any]:
    """The response for feedback modes ``none`` and ``end`` (API §5.8)."""
    return {"exercise_id": exercise_id, "recorded": True}
