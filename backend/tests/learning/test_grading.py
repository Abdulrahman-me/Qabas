"""The grader reproduces every contract evaluation fixture (QUALITY §18.1 ``test_types``; API §7).

``fixtures/EVALUATION_CONTEXT.json`` gives, for each evaluation fixture, the served exercise, the submitted
body, the session kind, the private key, the six-decimal mastery before the answer and any recitation result.
Feedback copy (explanation, scenario option feedback, event dates, pin labels) is taken from the fixtures.
"""

from __future__ import annotations

import json
from decimal import Decimal
from typing import Any

import pytest

from app.contract import FIXTURES_DIR, contextual
from app.errors import ApiError
from app.services.learning import grading

CONTEXT: dict[str, dict[str, Any]] = json.loads((FIXTURES_DIR / "EVALUATION_CONTEXT.json").read_text(encoding="utf-8"))
CASES = sorted(k for k, v in CONTEXT.items() if v)
CONCEPT_TITLE = "مفهوم اختباري"


def _load(path: str) -> Any:
    return json.loads((FIXTURES_DIR / path).read_text(encoding="utf-8"))


def _feedback(folder: str) -> dict[str, Any]:
    """The pinned feedback of a specimen, collected from its correct and incorrect evaluations."""
    found: dict[str, Any] = {"option_feedback": [], "event_dates": [], "pin_labels": []}
    for path in sorted((FIXTURES_DIR / folder).glob("eval_*.json")):
        evaluation = json.loads(path.read_text(encoding="utf-8"))
        if "explanation" not in evaluation:   # eval_recorded_only.json: the none/end response
            continue
        found["explanation"] = evaluation["explanation"]
        details = evaluation["details"] or {}
        for item in details.get("option_feedback", []):
            if item not in found["option_feedback"]:
                found["option_feedback"].append(item)
        found["event_dates"] = details.get("event_dates", found["event_dates"])
        found["pin_labels"] = details.get("pin_labels", found["pin_labels"])
    return found


@pytest.mark.parametrize("case", CASES)
def test_evaluations_match_the_contract(case: str) -> None:
    ctx = CONTEXT[case]
    expected = _load(case)
    exercise, submitted, kind = ctx["exercise"], ctx["answer"], ctx["kind"]
    folder = case.rsplit("/", 1)[0]
    feedback = _feedback(folder)

    body = grading.validate_submission(exercise, submitted, kind)
    graded = grading.grade(exercise, body["answer"], ctx["private_key"], feedback,
                           recitation_passed=ctx["recitation_passed"])
    rule = grading.mastery_rule(exercise, body, kind, graded.correct)
    changes = []
    if rule not in ("none", "retry_incorrect"):
        for concept_id in exercise["concept_ids"]:
            before = Decimal(ctx["mastery_before"][concept_id])
            changes.append({"concept_id": concept_id, "title": CONCEPT_TITLE, "before": grading.report(before),
                            "after": grading.report(grading.mastery_after(before, rule))})
    xp = 3 if exercise["type"] == "recite_verse" and graded.correct is True else 0
    evaluation = grading.evaluation(exercise, graded, feedback, expected["source_ids"],
                                    misconception=expected["misconception"], mastery_changes=changes,
                                    xp_awarded=xp)

    if case.endswith("scenario/eval_timeout.json"):
        # The generator copies the wrong option's feedback into the timeout; no option was chosen (D-59).
        assert evaluation["details"] == {"option_feedback": []}
        evaluation["details"] = expected["details"]
    assert evaluation == expected
    mastery_before = {c: Decimal(v) for c, v in ctx["mastery_before"].items()}
    contextual.validate_evaluation(exercise, body, kind, evaluation, mastery_before,
                                   private_key=ctx["private_key"], recitation_passed=ctx["recitation_passed"])


@pytest.mark.parametrize("folder", ["categorize__buckets", "categorize__day_arc"])
def test_invalid_categorize_answers_have_a_reason(folder: str) -> None:
    exercise = _load(f"exercises/{folder}/exercise.json")
    with pytest.raises(ApiError) as exc:
        grading.validate_submission(exercise, _load(f"exercises/{folder}/answer_invalid.json"), "lesson")
    expected = _load(f"exercises/{folder}/error_invalid.json")["error"]
    assert (exc.value.code, exc.value.details["reason"]) == (expected["code"], expected["details"]["reason"])


def test_categorize_reasons() -> None:
    exercise = _load("exercises/categorize__buckets/exercise.json")
    items = [i["item_id"] for i in exercise["payload"]["items"]]

    def reason(assignments: list[dict[str, str]]) -> str:
        with pytest.raises(ApiError) as exc:
            grading.validate_submission(exercise, {"exercise_id": exercise["exercise_id"], "elapsed_ms": 10,
                                                   "is_retry": False, "answer": {"assignments": assignments}}, "lesson")
        return str(exc.value.details["reason"])

    assert reason([{"item_id": i, "category_id": "c_1"} for i in items[:-1]]) == "duplicate_or_missing_item"
    assert reason([{"item_id": i, "category_id": "c_9"} for i in items]) == "unknown_category"


@pytest.mark.parametrize("name", sorted(p.stem for p in (FIXTURES_DIR / "negative").glob("*__invalid.json")))
def test_negative_answers_are_rejected(name: str) -> None:
    folder = name.split("__invalid")[0]
    exercise = _load(f"exercises/{folder}/exercise.json")
    kind = "challenge" if exercise["type"] == "true_false" else "lesson"
    with pytest.raises(ApiError) as exc:
        grading.validate_submission(exercise, _load(f"negative/{name}.json"), kind)
    assert exc.value.code == "validation_error"


def test_timeouts_need_a_timer_and_the_full_time() -> None:
    exercise = _load("exercises/multiple_choice/exercise.json")
    untimed = {**exercise, "time_limit_ms": None}
    body = {"exercise_id": exercise["exercise_id"], "answer": None, "elapsed_ms": 30000, "is_retry": False}
    with pytest.raises(ApiError):
        grading.validate_submission(untimed, body, "lesson")
    with pytest.raises(ApiError):
        grading.validate_submission(exercise, {**body, "elapsed_ms": exercise["time_limit_ms"] - 1}, "review")
    assert grading.validate_submission(exercise, body, "review")["answer"] is None


@pytest.mark.parametrize("body", [[], "x", {"exercise_id": 3, "is_retry": False}, {"exercise_id": "e"},
                                  {"exercise_id": "e", "is_retry": "no"}])
def test_identity_parsing_reads_only_two_fields(body: Any) -> None:
    with pytest.raises(ApiError):
        grading.parse_identity(body)
    assert grading.parse_identity({"exercise_id": "e", "is_retry": True, "answer": object()}) == \
        grading.Identity("e", True)
