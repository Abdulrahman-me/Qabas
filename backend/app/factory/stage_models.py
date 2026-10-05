"""Structured outputs of the factory stages that are not a contract model as they stand (factory §13.1).

Every model is closed and fully required (nullable instead of optional), so its JSON schema is a strict
structured-output schema. The shapes keep the model away from what code owns: it refers to verified evidence only
by the ids it was given (code inserts the canonical Qur'an/hadith text, grades and sources), it writes plain text
that code turns into contract spans, and it never supplies ids for registry objects it cannot see.
"""

from __future__ import annotations

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.contract import models as C

Lang = Literal["ar", "en"]
Variant = Literal["explorer", "new_muslim"]
Tool = Literal["observation", "inference", "testimony", "historical_evidence", "causal_reasoning", "comparison"]


class Closed(BaseModel):
    model_config = ConfigDict(extra="forbid")


# ---------------------------------------------------------------- 2 decompose
class DecomposedClaim(Closed):
    claim_id: str = Field(pattern=r"^c[0-9]{1,3}$")
    text_ar: str = Field(min_length=1)
    arc_step_id: str
    kind: Literal["factual", "historical", "theological", "religious", "reasoning"]
    basis: Literal["source", "reasoning"]
    reasoning_tool: Tool | None


class StoryEvent(Closed):
    event_id: str = Field(pattern=r"^e[0-9]{1,3}$")
    arc_step_id: str
    order: int = Field(ge=0)
    claim_id: str


class Decomposition(Closed):
    claims: list[DecomposedClaim]
    story_events: list[StoryEvent]
    issues: list[str]


# ---------------------------------------------------------------- 3 retrieve
class RetrievalRequest(Closed):
    request_id: str = Field(pattern=r"^r[0-9]{1,3}$")
    claim_id: str
    tool: Literal["quran_reference", "quran_text", "hadith_search", "tafsir", "hadeethenc_hadith",
                  "islamhouse_item"]
    reference: str | None                    # quran_reference "2:255" / "2:255-256"
    text: str | None                         # quran_text / hadith_search query text
    book: Literal["mukhtasar", "saadi", "ibn_kathir", "tabari", "baghawi", "muyassar"] | None
    item_id: str | None                      # hadeethenc / islamhouse record id
    language: Lang | None


class RetrievalPlan(Closed):
    requests: list[RetrievalRequest]
    issues: list[str]


# ---------------------------------------------------------------- 4 verify_evidence
class EvidenceJudgement(Closed):
    candidate_id: str
    supports: bool
    verifier_note: str = Field(min_length=1)
    semantic_review: C.SemanticReview | None


class ReasoningJudgement(Closed):
    tool: Tool
    premises: list[str] = Field(min_length=1)
    inference: str = Field(min_length=1)


class ClaimVerdict(Closed):
    claim_id: str
    status: Literal["supported", "dropped"]
    evidence: list[EvidenceJudgement]
    reasoning: ReasoningJudgement | None


class Verification(Closed):
    claims: list[ClaimVerdict]
    issues: list[str]


# ---------------------------------------------------------------- 5 write (Arabic) and 7a localize (English)
class WSentence(Closed):
    sentence_id: str = Field(pattern=r"^s_[0-9a-z_]{1,40}$")
    text: str = Field(min_length=1)
    role: Literal["claim", "framing", "hypothetical", "instruction", "question"]
    claim_ids: list[str]


class WOption(Closed):
    option_id: str = Field(pattern=r"^o_[0-9a-z_]{1,40}$")
    text: str = Field(min_length=1)


class WHook(Closed):
    block_id: str
    type: Literal["hook"]
    situation: str = Field(min_length=1)
    question: str = Field(min_length=1)
    cta: str | None
    visual_brief: str = Field(min_length=1)


class WPredict(Closed):
    block_id: str
    type: Literal["predict"]
    prompt: str = Field(min_length=1)
    options: list[WOption] = Field(min_length=2, max_length=4)
    reveal: str = Field(min_length=1)
    visual_brief: str | None


class WBeat(Closed):
    beat_id: str
    narration: list[WSentence] = Field(min_length=1)
    quote_evidence_id: str | None            # a verified evidence id; code inserts the verbatim text
    quote_meaning: str | None
    visual_brief: str = Field(min_length=1)
    figures: list[str]                       # approved medallion bindings, never image-model depictions


class WStory(Closed):
    block_id: str
    type: Literal["story"]
    label: str = Field(min_length=1)
    title: str | None
    sourced: bool                            # false = a fictional teaching scenario (asserts nothing, no quotes)
    origin_title: str | None
    beats: list[WBeat] = Field(min_length=1)


class WPoint(Closed):
    point_id: str
    sentence: WSentence


class WTeach(Closed):
    block_id: str
    type: Literal["teach"]
    eyebrow: str | None
    title: str = Field(min_length=1)
    style: Literal["standard", "summary"]
    evidence_id: str | None
    points: list[WPoint] = Field(min_length=1, max_length=5)
    visual_brief: str | None


class WParagraph(Closed):
    block_id: str
    type: Literal["paragraph"]
    sentences: list[WSentence] = Field(min_length=1)


class WCallout(Closed):
    block_id: str
    type: Literal["callout"]
    variant: Literal["tip", "note"]
    text: str = Field(min_length=1)


class WEvidence(Closed):
    block_id: str
    type: Literal["evidence"]
    evidence_id: str
    caption: str | None


class WExerciseSlot(Closed):
    block_id: str
    type: Literal["exercise_slot"]
    intent: str = Field(min_length=1)        # what the graded exercise placed here must test


WBlock = Annotated[WHook | WPredict | WStory | WTeach | WParagraph | WCallout | WEvidence | WExerciseSlot,
                   Field(discriminator="type")]


class WReviewTopic(Closed):
    topic_id: str
    title: str = Field(min_length=1)
    concept_ids: list[str] = Field(min_length=1)


class WCompletion(Closed):
    challenge: str | None
    review_topics: list[WReviewTopic]
    check_in: str | None


class WVariant(Closed):
    variant: Variant
    title: str = Field(min_length=1)
    subtitle: str | None
    blocks: list[WBlock] = Field(min_length=1)
    completion: WCompletion


class WArcStep(Closed):
    step_id: str
    block_ids: list[str] = Field(min_length=1)


class WriterDraft(Closed):
    variants: list[WVariant] = Field(min_length=1)
    arc_map: list[WArcStep]
    issues: list[str]


# ---------------------------------------------------------------- 6 exercises
class XOption(Closed):
    option_id: str = Field(pattern=r"^o_[0-9a-z_]{1,40}$")
    text: str = Field(min_length=1)
    misconception_id: str | None             # a misconception this distractor represents (existing or planned)
    feedback: str | None                     # scenario: per-option feedback


class XPair(Closed):
    left_id: str
    left: str
    right_id: str
    right: str


class XCategory(Closed):
    category_id: str
    label: str


class XItem(Closed):
    item_id: str
    text: str
    category_id: str | None                  # categorize: the correct category


class XSegment(Closed):
    kind: Literal["text", "blank"]
    text: str | None
    blank_id: str | None


class XWord(Closed):
    word_id: str
    text: str
    fills_blank_id: str | None               # the blank this word correctly fills, if any


class XExercise(Closed):
    exercise_id: str = Field(pattern=r"^x[0-9]{1,3}$")
    purpose: Literal["lesson", "pretest", "unit_test", "duel"]
    type: Literal["multiple_choice", "true_false", "true_false_reason", "scenario", "match_pairs", "fill_blank",
                  "categorize", "order_steps", "spot_error", "which_evidence", "verse_meaning", "flashcard"]
    slot_block_id: str | None                # lesson exercises: the writer's exercise slot it fills
    concept_ids: list[str] = Field(min_length=1)
    prompt: str = Field(min_length=1)
    layer: Literal["understand", "apply", "remember"] | None
    myth_statement: str | None               # framing: myth (states the misconception plainly)
    targets_misconception_id: str | None
    explanation: str = Field(min_length=1)
    evidence_ids: list[str]                  # verified evidence ids this item relies on
    statement: str | None                    # true_false / true_false_reason
    correct_value: bool | None
    situation: str | None                    # scenario
    options: list[XOption] | None            # multiple_choice / scenario / verse_meaning / true_false_reason reasons
    correct_option_id: str | None
    pairs: list[XPair] | None                # match_pairs
    categories: list[XCategory] | None       # categorize (buckets)
    items: list[XItem] | None
    steps: list[XOption] | None              # order_steps (in the correct order) / spot_error segments
    segments: list[XSegment] | None          # fill_blank
    words: list[XWord] | None
    evidence_option_ids: list[str] | None    # which_evidence: verified evidence ids offered as options
    verse_evidence_id: str | None            # verse_meaning
    front: str | None                        # flashcard
    back: str | None


class XMisconception(Closed):
    misconception_id: str                    # an existing id, or "new_<n>" for one the plan proposed
    concept_id: str | None
    title: str = Field(min_length=1)
    card: str = Field(min_length=1)


class ExerciseSet(Closed):
    exercises: list[XExercise]
    misconceptions: list[XMisconception]
    issues: list[str]


# ---------------------------------------------------------------- 7 glossary
class GTerm(Closed):
    term_id: str = Field(pattern=r"^t[0-9]{1,3}$")
    text_ar: str = Field(min_length=1)
    arabic: str | None
    transliteration: str = Field(min_length=1)
    basic_ar: str = Field(min_length=1)
    intermediate_ar: str | None
    example_ar: str = Field(min_length=1)
    concept_id: str | None


class Glossary(Closed):
    terms: list[GTerm]
    issues: list[str]


# ---------------------------------------------------------------- 7a localize
class LText(Closed):
    id: str                                  # the id of the Arabic element this English text localizes
    text: str = Field(min_length=1)


class Localization(Closed):
    texts: list[LText]
    issues: list[str]


# ---------------------------------------------------------------- 10 qa (model reviewers)
class ModelIssue(Closed):
    severity: Literal["blocker", "warning", "info"]
    kind: Literal["unsupported_sentence", "fatwa_like", "consistency", "sensitive", "pedagogy", "belief_grading",
                  "circular_reasoning", "localization", "scholarly_review"]
    sentence_id: str | None
    exercise_id: str | None
    message: str = Field(min_length=1)


class ModelReview(Closed):
    issues: list[ModelIssue]
