"""All ORM models; importing this package registers every table on ``Base.metadata``."""

from app.models.community import DailyActivity, Quest, XpEvent
from app.models.content import (
    Claim,
    Concept,
    CurriculumSlot,
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
from app.models.factory import FactoryRun
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
from app.models.media import MediaAssetRecord, MediaJob
from app.models.metrics import BlindPair, BlindResponse, MetricLearnerFact, MetricUnitFact
from app.models.platform import EffectLedger, OutboxEvent, ReviewDecision
from app.models.raqeeb import BenchmarkRun, RaqeebConversation, RaqeebMessage
from app.models.users import AuthSession, DeletionJob, IdempotencyKey, User

__all__ = [
    "AuthSession", "BenchmarkRun", "BlindPair", "BlindResponse", "Claim", "Concept", "CurriculumSlot", "DailyActivity",
    "DeletionJob", "EffectLedger", "Exercise",
    "ExerciseVersion", "FactoryRun", "IdempotencyKey", "LearnerConcept", "LearnerLesson", "LearnerMisconception",
    "LearnerTerm", "LearnerUnit", "LearningSession", "Lesson", "LessonVersion", "MediaAssetRecord", "MediaJob",
    "MetricLearnerFact", "MetricUnitFact", "Misconception",
    "OutboxEvent", "Quest", "RaqeebConversation", "RaqeebMessage", "RecitationCheckRecord", "ReviewDecision",
    "SceneAsset", "SceneVersion",
    "SentenceRecord", "SessionAnswer", "Source", "Term", "Unit", "User", "XpEvent",
]
