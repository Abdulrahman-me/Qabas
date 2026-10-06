"""Private model outputs. Public messages remain revision 10 contract models."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.contract import models as C
from app.factory.schemas import _schema


class Closed(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Quote(Closed):
    text: str
    kind_guess: Literal["quran", "hadith", "claim"]


class Classified(Closed):
    question_class: C.QuestionClass
    confidence: float = Field(ge=0, le=1, allow_inf_nan=False)
    language: Literal["ar", "en"]
    quotes: list[Quote]
    retrieval_queries: list[str]
    concept_hint: str | None
    standalone: bool
    canonical_question: str


class Claim(Closed):
    text: str
    supported: bool
    source_ids: list[str]
    note: str


class Verified(Closed):
    claims: list[Claim]


class Core(Closed):
    blocks: list[C.AnswerBlock]
    citations: list[C.Citation]


class Rewritten(Closed):
    paragraphs: list[C.ABParagraph]


class RewriteCheck(Closed):
    same_meaning: bool
    new_claims: bool


class Guarded(Closed):
    violations: list[Literal["personal_ruling", "unsupported_claim", "unattributed_view", "picked_winner"]]


class Extracted(Closed):
    extracted_text: str = Field(max_length=30_000)
    description: str = Field(max_length=2000)


class Summary(Closed):
    summary: str = Field(max_length=2000)


class Equivalent(Closed):
    same_question: bool
    reason: str = Field(max_length=1000)


class MemorySafe(Closed):
    depersonalised: bool
    contains_private_details: bool


class Baseline(Closed):
    question_class: C.QuestionClass
    abstained: bool
    blocks: list[C.AnswerBlock]
    citations: list[C.Citation]


class Judge(Closed):
    verdict: Literal["correct", "partial", "incorrect"]
    missing_points: list[str]


class FactualSentence(Closed):
    text: str
    factual: bool
    supported: bool
    citation_refs: list[int]


class Grounding(Closed):
    sentences: list[FactualSentence]


def exported() -> dict[str, Any]:
    return {f"raqeeb_{name}": (lambda m=model, n=name: _schema(m, f"raqeeb_{n}"))
            for name, model in {"classify": Classified, "verify": Verified, "write": Core,
                                "rewrite": Rewritten, "rewrite_check": RewriteCheck, "guard": Guarded,
                                "extract": Extracted, "summary": Summary, "equivalence": Equivalent,
                                "memory_safe": MemorySafe, "baseline": Baseline, "judge": Judge,
                                "grounding": Grounding}.items()}
