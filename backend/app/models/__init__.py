"""All ORM models; importing this package registers every table on ``Base.metadata``."""

from app.models.community import DailyActivity, Quest, XpEvent
from app.models.content import (
    Claim,
    Concept,
    Exercise,
    ExerciseVersion,
    Lesson,
    LessonVersion,
    Misconception,
    SceneAsset,
    SceneVersion,
    SentenceRecord,
    Source,
    Term,
    Unit,
)
from app.models.learner import (
    LearnerConcept,
    LearnerLesson,
    LearnerMisconception,
    LearnerTerm,
    LearnerUnit,
    LearningSession,
    RecitationCheckRecord,
    SessionAnswer,
)
from app.models.platform import EffectLedger, OutboxEvent, ReviewDecision
from app.models.users import AuthSession, DeletionJob, IdempotencyKey, User

__all__ = [
    "AuthSession", "Claim", "Concept", "DailyActivity", "DeletionJob", "EffectLedger", "Exercise",
    "ExerciseVersion", "IdempotencyKey", "LearnerConcept", "LearnerLesson", "LearnerMisconception",
    "LearnerTerm", "LearnerUnit", "LearningSession", "Lesson", "LessonVersion", "Misconception",
    "OutboxEvent", "Quest", "RecitationCheckRecord", "ReviewDecision", "SceneAsset", "SceneVersion",
    "SentenceRecord", "SessionAnswer", "Source", "Term", "Unit", "User", "XpEvent",
]
