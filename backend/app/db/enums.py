"""Enumerated column values, derived from the vendored contract wherever the contract defines them.

The database stores enums as text with named CHECK constraints (easy to extend with an
expand/contract migration). ``tests/db/test_enum_sync.py`` checks these tuples against the
contract and the migrated CHECK constraints, so the three cannot drift apart.
"""

from __future__ import annotations

import types
import typing
from typing import Any, Literal

from pydantic import BaseModel

from app.contract import models as C


def literal_values(source: Any, field: str | None = None) -> tuple[Any, ...]:
    """Values of a ``Literal`` (optionally a model field's annotation, unwrapping ``Optional``)."""
    annotation = source.model_fields[field].annotation if field else source
    if isinstance(source, type) and issubclass(source, BaseModel) and field is None:
        raise TypeError("field required for a model")
    origin = typing.get_origin(annotation)
    if origin in (typing.Union, types.UnionType):
        args = [a for a in typing.get_args(annotation) if a is not type(None)]
        assert len(args) == 1, annotation
        annotation = args[0]
    assert typing.get_origin(annotation) is Literal, annotation
    return tuple(typing.get_args(annotation))


# Users and community
ROLE = literal_values(C.User, "role")
LANGUAGE = literal_values(C.User, "language")
TRACK = literal_values(C.User, "track")
FAMILIARITY = literal_values(C.User, "familiarity")
DAILY_GOAL_MINUTES = literal_values(C.User, "daily_goal_minutes")
XP_REASON = literal_values(C.XpReason)
QUEST_KIND = literal_values(C.Quest, "kind")

# Content
LESSON_TYPE = literal_values(C.JLesson, "lesson_type")
EXERCISE_TYPE = literal_values(C.ExerciseType)
SOURCE_KIND = literal_values(C.SourceKind)
SOURCE_PROVIDER = literal_values(C.Provider)
CLAIM_STATUS = literal_values(C.Claim, "status")
CLAIM_BASIS = literal_values(C.Claim, "basis")
SENTENCE_ROLE = literal_values(C.SentenceRole)
TERM_STATE = literal_values(C.TermCard, "state")

# Sessions and recitation
SESSION_KIND = literal_values(C.Session, "kind")
SESSION_MODE = literal_values(C.Session, "mode")
SESSION_STATUS = literal_values(C.Session, "status")
FEEDBACK_MODE = literal_values(C.Session, "feedback_mode")
RECITATION_STATUS = literal_values(C.RecitationCheck, "status")

# Reviewer gates
GATE1_DECISION = literal_values(C.Gate1, "decision")
GATE2_DECISION = literal_values(C.Gate2, "decision")
REVIEW_DECISION = tuple(dict.fromkeys(GATE1_DECISION + GATE2_DECISION))

# Backend-internal values (not part of the public contract).
VARIANT = TRACK  # a lesson variant is named after the track it serves
EXERCISE_PURPOSE = ("lesson", "pretest", "unit_test", "duel")  # data model §4.2
ASSESSMENT_EXCLUDED_TYPES = ("recite_verse", "flashcard")       # backend §6.2: not in pretest/unit_test/duels
DUEL_TYPES = ("multiple_choice", "true_false", "verse_meaning")  # backend §11.1
DUEL_ONLY_TYPES = ("true_false",)                                # API §7.15
MISCONCEPTION_STATUS = ("inactive", "active", "resolved")        # inactive: evidence below activation (D-21)
SCENE_STATUS = ("draft", "published")
CONTENT_ORIGIN = ("factory", "gold_import", "test_fixture")
SCENE_ASSET_MIME = ("image/svg+xml", "image/webp", "image/png", "image/jpeg")
FEEDBACK_BY_KIND = {"lesson": "immediate", "review": "immediate", "pretest": "none", "unit_test": "end"}
