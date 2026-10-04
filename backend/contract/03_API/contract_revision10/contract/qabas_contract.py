"""Qabas API contract models — revision 10 candidate (final engineering review).

Revision 10 = revision 9 (reply8 display amendment) plus the final-review typing and
review-binding changes listed in ../CHANGES.md. Mirrors 03_API/API_REQUIREMENTS.md
(the contract). Used to:
  * validate every JSON example in the API requirements and every fixture (tools/validate.py),
  * export JSON Schema (contract/qabas_contract.schema.json) for OpenAPI/Dart model generation,
  * seed the backend's Pydantic request/response models.

Rules encoded here: extra keys are forbidden, and every response field is required
(nullable fields must be present with null), matching contract §3.3. Request bodies follow
the same rule except the partial-update body `MePatch`.
"""
from __future__ import annotations

from typing import Annotated, Any, Literal, Optional, Union

from pydantic import BaseModel, ConfigDict, Field, RootModel, StrictBool, model_validator


class M(BaseModel):
    model_config = ConfigDict(extra="forbid")


# ---------------------------------------------------------------- rich text
class SpanText(M):
    type: Literal["text"]
    text: str


class SpanStrong(M):
    type: Literal["strong"]
    text: str


class SpanTerm(M):
    type: Literal["term"]
    text: str
    term_id: str


class SpanCitation(M):
    type: Literal["citation"]
    ref: int


Span = Annotated[Union[SpanText, SpanStrong, SpanTerm, SpanCitation], Field(discriminator="type")]
Spans = list[Span]


class Sentence(M):
    sentence_id: str
    spans: Spans
    source_ids: list[str]


# ---------------------------------------------------------------- sources/evidence
SourceKind = Literal["quran", "hadith", "tafsir", "article", "book", "fatwa"]
Provider = Literal["tafsir_center", "quran_com", "hadeethenc", "quranenc", "islamhouse", "dorar"]


class Source(M):
    source_id: str
    kind: SourceKind
    provider: Provider
    title: str
    reference: str
    excerpt: str
    url: Optional[str]
    displayed: bool
    display_role: Optional[Literal["content", "activity"]]

    @model_validator(mode="after")
    def _role(self):
        if self.displayed != (self.display_role is not None):
            raise ValueError("display_role must be set iff displayed is true")
        return self


class Segment(M):
    word_start: int = Field(ge=1)
    word_end: int = Field(ge=1)

    @model_validator(mode="after")
    def _order(self):
        if self.word_end < self.word_start:
            raise ValueError("word_end < word_start")
        return self


class WordTiming(M):
    ayah: int
    position: int
    text: str
    start_ms: int
    end_ms: int


class Audio(M):
    reciter: str
    url: str
    words: Optional[list[WordTiming]]


class QuranBody(M):
    surah: int = Field(ge=1, le=114)
    surah_name: str
    ayah_start: int
    ayah_end: int
    segment: Optional[Segment]
    text_uthmani: str
    translation: Optional[str]
    translation_source: Optional[str]
    audio: Optional[Audio]


class HadithBody(M):
    text_ar: str
    translation: Optional[str]
    narrator: str
    collections: list[str]
    grade_label: str
    grade_category: Literal["authentic", "acceptable", "weak", "fabricated", "other"]
    grade_source: str
    excerpt: bool


class Evidence(M):
    evidence_id: str
    kind: Literal["quran", "hadith"]
    quran: Optional[QuranBody]
    hadith: Optional[HadithBody]

    @model_validator(mode="after")
    def _one(self):
        if not ((self.kind == "quran" and self.quran is not None and self.hadith is None)
                or (self.kind == "hadith" and self.hadith is not None and self.quran is None)):
            raise ValueError("kind=quran requires quran only; kind=hadith requires hadith only")
        return self


# ---------------------------------------------------------------- visuals
class Image(M):
    url: str
    mime_type: Literal["image/webp", "image/png", "image/jpeg"]
    width: int = Field(gt=0)
    height: int = Field(gt=0)


class Overlay(M):
    type: Literal["medallion"]
    asset_url: str
    label: str
    anchor: Literal["top_start", "top_end", "center", "bottom_start", "bottom_end"]
    size_pct: float = Field(gt=0, le=100)


class ViewBox(M):
    width: int = Field(gt=0)
    height: int = Field(gt=0)


class SceneRef(M):
    scene_id: str
    version: int = Field(ge=1)
    schema_version: Literal["qabas.scene/1"]
    url: str
    mime_type: Literal["application/json"]
    sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    view_box: ViewBox
    required_capabilities: list[str]


BUILTIN_PARAMS = {
    "river_house": {"beat": (0, 3)},
    "workplace": {},
    "day_arc": {"highlight": (-1, 4)},
    "pillars": {"highlight": (0, 4)},
}


def check_builtin_params(key: str, params: dict) -> None:
    spec = BUILTIN_PARAMS.get(key)
    if spec is None:
        raise ValueError(f"unknown built-in key {key}")
    if set(params) - set(spec):
        raise ValueError(f"unexpected params for {key}: {set(params) - set(spec)}")
    for name, (lo, hi) in spec.items():
        v = params.get(name)
        if not isinstance(v, int) or not lo <= v <= hi:
            raise ValueError(f"{key}.{name} must be int in [{lo},{hi}]")


class Visual(M):
    kind: Literal["builtin", "image", "scene"]
    key: Optional[Literal["river_house", "workplace", "day_arc", "pillars"]]
    version: Optional[int]
    params: Optional[dict[str, Any]]
    image: Optional[Image]
    scene: Optional[SceneRef]
    fallback_image: Optional[Image]
    fallback_params: Optional[dict[str, Any]]
    alt: str = Field(min_length=1)
    overlays: list[Overlay]

    @model_validator(mode="after")
    def _kind(self):
        k = self.kind
        if k == "builtin":
            if self.key is None or self.version != 1 or self.params is None or self.image or self.scene:
                raise ValueError("builtin: key, version=1, params required; image/scene null")
            check_builtin_params(self.key, self.params)
            if self.fallback_params is not None:
                raise ValueError("builtin: fallback_params must be null")
        elif k == "image":
            if self.fallback_params is not None:
                raise ValueError("image: fallback_params must be null")
            if self.key or self.version or self.params is not None or self.scene or self.fallback_image or not self.image:
                raise ValueError("image: image required; key/version/params/scene/fallback null")
        else:
            if self.key or self.version or self.params is None or self.image or not self.scene or not self.fallback_image:
                raise ValueError("scene: scene, params (may be {}), fallback_image required; key/version/image null")
            if self.fallback_params is None:
                raise ValueError("scene: fallback_params (the state the fallback was rendered at) is required")
            fb, vb = self.fallback_image, self.scene.view_box
            if abs(fb.width / fb.height - vb.width / vb.height) > 0.01:
                raise ValueError("scene fallback_image must have the scene view_box proportion")
        return self


# ---------------------------------------------------------------- terms
class TermCard(M):
    term_id: str
    text: str
    arabic: Optional[str]
    transliteration: str
    state: Literal["new", "learning", "mastered"]
    level: Literal["basic", "intermediate"]
    definition: Spans
    example: Spans
    pronunciation_audio_url: Optional[str]
    source_id: Optional[str]
    lesson_id: Optional[str]
    lesson_title: Optional[str]


class LocalizedText(M):
    ar: str
    en: str


class LocalizedSpans(M):
    ar: Spans
    en: Spans


class GlossaryDefinitions(M):
    basic: LocalizedSpans
    intermediate: Optional[LocalizedSpans]


class StoredGlossaryTerm(M):
    """Canonical content/factory glossary record, independent of learner state."""
    term_id: str
    text: LocalizedText
    arabic: Optional[str]
    transliteration: str
    definition: GlossaryDefinitions
    example: LocalizedSpans
    concept_id: Optional[str]
    lesson_id: Optional[str]
    source_id: Optional[str]
    pronunciation_audio_url: Optional[str]


EXERCISE_ART = {
    "starry_sky": "starrySky", "footprints": "footprints", "water_drop": "waterDrop",
    "prayer_rug": "prayerRug", "lantern": "lantern", "book": "book",
    "heart": "heart", "compass": "compass", "questions": "questions",
}
ExerciseArtKey = Literal[tuple(EXERCISE_ART)]


# ---------------------------------------------------------------- exercises
class Opt(M):
    option_id: str
    spans: Spans


class Item(M):
    item_id: str
    spans: Spans


class PMultipleChoice(M):
    options: list[Opt] = Field(min_length=2, max_length=4)


class PTrueFalseReason(M):
    statement: Spans
    reasons: list[Opt] = Field(min_length=2, max_length=4)


class PMatchPairs(M):
    left: list[Item] = Field(min_length=3, max_length=5)
    right: list[Item] = Field(min_length=3, max_length=5)


class PFlashcard(M):
    front: Spans
    back: Spans


class FBText(M):
    type: Literal["text"]
    text: str


class FBBlank(M):
    type: Literal["blank"]
    blank_id: str


class Word(M):
    word_id: str
    text: str


class PFillBlank(M):
    segments: list[Annotated[Union[FBText, FBBlank], Field(discriminator="type")]]
    word_bank: list[Word]


class Category(M):
    category_id: str
    label: str
    art_key: Optional[ExerciseArtKey]
    phase: Optional[Literal["dawn", "midday", "afternoon", "sunset", "night"]]
    capacity: Optional[int]


class CatItem(M):
    item_id: str
    spans: Spans
    secondary_label: Optional[str]


class PCategorize(M):
    presentation: Literal["buckets", "day_arc"]
    categories: list[Category]
    items: list[CatItem]

    @model_validator(mode="after")
    def _pres(self):
        if self.presentation == "day_arc":
            phases = [c.phase for c in self.categories]
            if phases != ["dawn", "midday", "afternoon", "sunset", "night"] or any(c.capacity != 1 for c in self.categories) or len(self.items) != 5:
                raise ValueError("day_arc: 5 ordered phases, capacity 1, 5 items")
            if any(c.art_key is not None for c in self.categories):
                raise ValueError("day_arc uses phase icons; bucket art_key must be null")
        else:
            if not 2 <= len(self.categories) <= 3 or any(c.phase or c.capacity for c in self.categories):
                raise ValueError("buckets: 2-3 categories, phase/capacity null")
        return self


class Seg(M):
    segment_id: str
    spans: Spans


class PSpotError(M):
    segments: list[Seg] = Field(min_length=2)


class EvOpt(M):
    option_id: str
    evidence: Evidence


class PWhichEvidence(M):
    claim: Spans
    options: list[EvOpt] = Field(min_length=2, max_length=4)


class Step(M):
    step_id: str
    spans: Spans
    secondary_label: Optional[str]


class POrderSteps(M):
    presentation: Literal["plain", "day_sequence"]
    steps: list[Step] = Field(min_length=3, max_length=7)


class PScenario(M):
    situation: Spans
    options: list[Opt] = Field(min_length=2, max_length=4)


class Event(M):
    event_id: str
    spans: Spans


class PTimelineOrder(M):
    events: list[Event] = Field(min_length=3, max_length=7)


class Pin(M):
    pin_id: str
    x_pct: float = Field(ge=0, le=100)
    y_pct: float = Field(ge=0, le=100)
    label: Optional[str]
    radius_pct: Optional[float] = Field(gt=0, le=25)
    anchor_id: Optional[str]


class Binding(M):
    pin_id: str
    set: dict[str, Any] = Field(min_length=1)


class AfterEvaluation(M):
    correct: Optional[dict[str, Any]]
    incorrect: Optional[dict[str, Any]]


class Interaction(M):
    bindings: list[Binding]
    reset_on_deselect: bool
    after_evaluation: Optional[AfterEvaluation]


class PMapPlace(M):
    presentation: Literal["hotspots", "map_pins"]
    visual: Visual
    question: Spans
    pins: list[Pin] = Field(min_length=3, max_length=6)
    interaction: Optional[Interaction]

    @model_validator(mode="after")
    def _labels(self):
        if self.presentation == "hotspots" and any(p.label is None for p in self.pins):
            raise ValueError("hotspots: every pin needs a label")
        if self.visual.kind == "scene":
            if self.presentation != "hotspots" or any(p.anchor_id is None for p in self.pins):
                raise ValueError("scene map_place: hotspots presentation and an anchor_id on every pin")
            if self.visual.fallback_params != self.visual.params:
                raise ValueError("scene map_place: fallback must be rendered at the exercise's authored state")
        ids = [p.pin_id for p in self.pins]
        if len(set(ids)) != len(ids):
            raise ValueError("duplicate pin ids")
        if self.interaction:
            if self.visual.kind == "image":
                raise ValueError("interaction bindings need a stateful (builtin/scene) visual")
            bound = [b.pin_id for b in self.interaction.bindings]
            if set(bound) - set(ids) or len(set(bound)) != len(bound):
                raise ValueError("bindings must reference distinct existing pins")
            if self.visual.kind == "builtin":
                for b in self.interaction.bindings:
                    check_builtin_params(self.visual.key, {**self.visual.params, **b.set})
        return self


class PReciteVerse(M):
    surah: int
    ayah: int
    word_start: Optional[int]
    word_end: Optional[int]
    text_uthmani: str
    audio: Audio
    transliteration: Optional[str]
    meaning: Optional[Spans]
    source_id: str
    max_duration_ms: int
    skippable: bool

    @model_validator(mode="after")
    def _seg(self):
        if (self.word_start is None) != (self.word_end is None):
            raise ValueError("word_start and word_end are both null or both set")
        if len(self.text_uthmani.split()) > 20:
            raise ValueError("recited text must be <= 20 words")
        return self


class PVerseMeaning(M):
    verse: Evidence
    options: list[Opt] = Field(min_length=2, max_length=4)


class PTrueFalse(M):
    statement: Spans


PAYLOADS: dict[str, type[M]] = {
    "multiple_choice": PMultipleChoice, "true_false_reason": PTrueFalseReason, "match_pairs": PMatchPairs,
    "flashcard": PFlashcard, "fill_blank": PFillBlank, "categorize": PCategorize, "spot_error": PSpotError,
    "which_evidence": PWhichEvidence, "order_steps": POrderSteps, "scenario": PScenario,
    "timeline_order": PTimelineOrder, "map_place": PMapPlace, "recite_verse": PReciteVerse,
    "verse_meaning": PVerseMeaning, "true_false": PTrueFalse,
}
ExerciseType = Literal[tuple(PAYLOADS)]  # type: ignore[valid-type]


class Scoring(M):
    accuracy: bool
    combo: bool
    layer: Optional[Literal["understand", "apply", "remember"]]


class Framing(M):
    kind: Literal["myth"]
    statement: Spans


class Exercise(M):
    exercise_id: str
    type: ExerciseType
    concept_ids: list[str]
    prompt: Spans
    time_limit_ms: Optional[int]
    scoring: Scoring
    framing: Optional[Framing]
    payload: dict[str, Any]

    @model_validator(mode="after")
    def _payload(self):
        PAYLOADS[self.type].model_validate(self.payload)
        if self.type == "recite_verse" and (self.scoring.accuracy or self.scoring.combo or self.scoring.layer):
            raise ValueError("recite_verse never counts in accuracy, combo, or layers")
        return self


# ---------------------------------------------------------------- blocks
class BParagraph(M):
    block_id: str
    type: Literal["paragraph"]
    sentences: list[Sentence]


class BEvidence(M):
    block_id: str
    type: Literal["evidence"]
    evidence: Evidence
    caption: Optional[Spans]


class BVisual(M):
    block_id: str
    type: Literal["visual"]
    visual: Visual
    caption: Optional[Spans]


class BCallout(M):
    block_id: str
    type: Literal["callout"]
    variant: Literal["tip", "note"]
    spans: Spans


class BHook(M):
    block_id: str
    type: Literal["hook"]
    situation: Spans
    question: Spans
    visual: Visual
    cta: Optional[str]


class Provenance(M):
    source_id: str
    provider: Provider
    reference: str
    grade_label: Optional[str]


class Beat(M):
    beat_id: str
    beat_index: int
    narration: list[Sentence]
    narration_audio_url: Optional[str]
    quote: Optional[Evidence]
    quote_meaning: Optional[Spans]
    visual: Visual


class Origin(M):
    title: str
    source_ids: list[str] = Field(min_length=1)
    show_card: bool


class BStory(M):
    """A narrative experience. Sourced story (Qur'an, authentic Sunnah, verified history): `origin` set.
    Teaching scenario (lesson-composition refinement): an explicitly fictional/everyday narrative with
    `origin`, `provenance` and every beat `quote` null; its narration asserts nothing (factory §13.2)."""
    block_id: str
    type: Literal["story"]
    label: str
    title: Optional[str]
    provenance: Optional[Provenance]
    beats: list[Beat] = Field(min_length=1)
    origin: Optional[Origin]  # null = fictional teaching scenario (lesson-composition refinement)

    @model_validator(mode="after")
    def _beats(self):
        if [b.beat_index for b in self.beats] != list(range(len(self.beats))):
            raise ValueError("beat_index must be contiguous from 0")
        for b in self.beats:
            if b.quote_meaning is not None and b.quote is None:
                raise ValueError("quote_meaning requires quote")
        if self.origin is None and (self.provenance is not None or any(b.quote is not None for b in self.beats)):
            raise ValueError("a teaching scenario (origin null) has no provenance and no quotes")
        return self


class TeachPoint(M):
    point_id: str
    sentence: Sentence
    visual_params: Optional[dict[str, Any]]


class BTeach(M):
    block_id: str
    type: Literal["teach"]
    eyebrow: Optional[str]
    title: Spans
    style: Literal["standard", "summary"]
    visual: Optional[Visual]
    evidence: Optional[Evidence]
    points: list[TeachPoint] = Field(min_length=1, max_length=5)

    @model_validator(mode="after")
    def _params(self):
        for p in self.points:
            if p.visual_params is None:
                continue
            if self.style == "summary" or self.visual is None or self.visual.kind == "image":
                raise ValueError("visual_params only for standard cards with builtin/scene visuals")
            if self.visual.kind == "builtin":
                merged = dict(self.visual.params or {})
                merged.update(p.visual_params)
                check_builtin_params(self.visual.key, merged)
        return self


class BPredict(M):
    block_id: str
    type: Literal["predict"]
    prompt: Spans
    options: list[Opt] = Field(min_length=2, max_length=4)
    reveal: Spans
    visual: Optional[Visual]


class BExercise(M):
    block_id: str
    type: Literal["exercise"]
    exercise: Exercise


Block = Annotated[Union[BParagraph, BEvidence, BVisual, BCallout, BHook, BStory, BTeach, BPredict, BExercise], Field(discriminator="type")]


# ---------------------------------------------------------------- lessons/sessions
class ReviewTopic(M):
    topic_id: str
    title: str
    concept_ids: list[str]


class Completion(M):
    challenge: Optional[Spans]
    review_topics: list[ReviewTopic]
    check_in: Optional[Spans]


class Counts(M):
    interactions: int
    exercises: int
    scored: int


class AnswerRecord(M):
    exercise_id: str
    is_retry: bool
    result: Literal["correct", "incorrect", "neutral", "hidden"]
    recorded_at: str
    evaluation: Optional["AnswerEvaluation"]


class Session(M):
    session_id: str
    kind: Literal["lesson", "review", "pretest", "unit_test"]
    mode: Optional[Literal["cards", "quick"]]
    status: Literal["active", "finished", "abandoned"]
    feedback_mode: Literal["immediate", "none", "end"]
    unit_id: Optional[str]
    lesson_id: Optional[str]
    lesson_version: Optional[int]
    title: str
    subtitle: Optional[str]
    lesson_type: Optional[Literal["concept", "story", "practice"]]
    reviewed_by: Optional[str]
    objectives: list[Spans]
    counts: Counts
    source_count: int
    total_exercises: int
    answered_exercises: int
    started_at: str
    items: list[Block]
    completion: Optional[Completion]
    sources: list[Source]
    terms: dict[str, TermCard]
    answers: list[AnswerRecord]

    @model_validator(mode="after")
    def _counts(self):
        ex = [b for b in self.items if b.type == "exercise"]
        pr = [b for b in self.items if b.type == "predict"]
        if self.counts.exercises != len(ex) or self.total_exercises != len(ex):
            raise ValueError("counts.exercises/total_exercises must equal exercise blocks")
        if self.counts.interactions != len(ex) + len(pr):
            raise ValueError("counts.interactions = exercise blocks + predict blocks")
        if self.counts.scored != sum(1 for b in ex if b.exercise.scoring.accuracy):
            raise ValueError("counts.scored = exercises with scoring.accuracy")
        if self.source_count != sum(1 for s in self.sources if s.displayed):
            raise ValueError("source_count = displayed sources")
        if sum(1 for s in self.sources if s.display_role == "content") > 3:
            raise ValueError("at most 3 content-displayed sources")
        types = {b.exercise.exercise_id: b.exercise.type for b in self.items if b.type == "exercise"}
        if len(types) != len(ex):
            raise ValueError("served exercise IDs must be unique")
        firsts, retries = {}, set()
        for a in self.answers:
            if a.exercise_id not in types:
                raise ValueError("answer for an exercise not served in this session")
            if not a.is_retry:
                if a.exercise_id in firsts:
                    raise ValueError("at most one first attempt per exercise")
                firsts[a.exercise_id] = a
            else:
                if self.kind != "lesson":
                    raise ValueError("retries exist only in lesson sessions")
                if a.exercise_id in retries:
                    raise ValueError("at most one retry per exercise (once-each rule)")
                f = firsts.get(a.exercise_id)
                if f is None or types[a.exercise_id] in ("recite_verse", "flashcard") or f.result not in ("incorrect", "hidden"):
                    raise ValueError("a retry needs an earlier incorrect first attempt of a retryable type")
                retries.add(a.exercise_id)
        order = [e for e in types]
        answered = list(firsts)
        if answered != order[:len(answered)]:
            raise ValueError("first attempts must follow authored order (no gaps)")
        if self.answered_exercises != len(firsts):
            raise ValueError("answered_exercises must count distinct original attempts")
        if "true_false" in types.values():
            raise ValueError("true_false is challenge-only")
        visible = self.feedback_mode == "immediate" or (self.feedback_mode == "end" and self.status == "finished")
        for a in self.answers:
            if visible and a.result == "hidden":
                raise ValueError("answer outcomes are visible in this mode/state")
            if not visible and (a.result != "hidden" or a.evaluation is not None):
                raise ValueError("answer outcomes must be hidden (result=hidden, evaluation=null) in this mode/state")
            if self.feedback_mode == "immediate" and a.evaluation is None:
                raise ValueError("immediate sessions return the stored evaluation snapshot")
            if a.evaluation:
                if a.evaluation.exercise_id != a.exercise_id:
                    raise ValueError("evaluation must belong to its recorded exercise")
                expected = {True: "correct", False: "incorrect", None: "neutral"}[a.evaluation.correct]
                if a.result != expected:
                    raise ValueError("history result must agree with the stored evaluation")
        return self


class LessonRead(M):
    lesson_id: str
    unit_id: str
    title: str
    subtitle: Optional[str]
    lesson_type: Literal["concept", "story", "practice"]
    reviewed_by: str
    version: int
    objectives: list[Spans]
    source_count: int
    blocks: list[Block]
    completion: Optional[Completion]
    sources: list[Source]
    terms: dict[str, TermCard]

    @model_validator(mode="after")
    def _no_ex(self):
        if any(b.type == "exercise" for b in self.blocks):
            raise ValueError("lesson reader projection has no exercise blocks")
        return self


class Misconception(M):
    misconception_id: str
    title: str
    card: Spans
    source_ids: list[str]


class MasteryChange(M):
    concept_id: str
    title: str
    before: float
    after: float


class TermChange(M):
    term_id: str
    state: Literal["new", "learning", "mastered"]


# The request's exercise_id supplies the discriminator. These shapes reject
# unknown fields; served-context validation selects the exact shape and IDs.
class AOption(M):
    option_id: str

class AValue(M):
    value: StrictBool

class AReason(M):
    value: StrictBool
    reason_option_id: str

class PairAnswer(M):
    left_id: str
    right_id: str

class APairs(M):
    pairs: list[PairAnswer]

class FillAnswer(M):
    blank_id: str
    word_id: str

class AFills(M):
    fills: list[FillAnswer]

class Assignment(M):
    item_id: str
    category_id: str

class AAssignments(M):
    assignments: list[Assignment]

class ASegment(M):
    segment_id: str

class AOrder(M):
    order: list[str]

class APin(M):
    pin_id: str

class ARating(M):
    rating: Literal["again", "hard", "good", "easy"]

class ACheck(M):
    check_id: str

class ASkipped(M):
    skipped: Literal[True]

class AUnavailable(M):
    unavailable: Literal[True]

CorrectAnswer = Union[AOption, AValue, AReason, APairs, AFills, AAssignments, ASegment, AOrder, APin]
SubmittedAnswer = Union[CorrectAnswer, ARating, ACheck, ASkipped, AUnavailable]

class DReason(M):
    value_correct: bool
    reason_correct: bool

class PairResult(M):
    left_id: str
    correct: bool

class DPairs(M):
    pair_results: list[PairResult]

class BlankResult(M):
    blank_id: str
    correct: bool

class DFills(M):
    blank_results: list[BlankResult]

class ItemResult(M):
    item_id: str
    correct: bool

class DAssignments(M):
    item_results: list[ItemResult]

class DOrder(M):
    first_wrong_index: Optional[int] = Field(ge=0)

class OptionFeedback(M):
    option_id: str
    spans: Spans

class DScenario(M):
    option_feedback: list[OptionFeedback]

class EventDate(M):
    event_id: str
    label: str

class DTimeline(M):
    event_dates: list[EventDate]

class PinLabel(M):
    pin_id: str
    label: str

class DPins(M):
    pin_labels: list[PinLabel]

EvaluationDetails = Union[DReason, DPairs, DFills, DAssignments, DOrder, DScenario, DTimeline, DPins]


class AnswerEvaluation(M):
    exercise_id: str
    recorded: Literal[True]
    correct: Optional[bool]
    correct_answer: Optional[CorrectAnswer]
    details: Optional[EvaluationDetails]
    explanation: Spans
    source_ids: list[str]
    misconception: Optional[Misconception]
    mastery_changes: list[MasteryChange]
    term_changes: list[TermChange]
    xp_awarded: int


class AnswerRecorded(M):
    exercise_id: str
    recorded: Literal[True]


AnswerRecord.model_rebuild()
Session.model_rebuild()


# ---------------------------------------------------------------- raqeeb
class UnderstoodImage(M):
    attachment_id: str
    extracted_text: str
    description: str


class UnderstoodDoc(M):
    attachment_id: str
    filename: str
    pages_processed: int
    truncated: bool
    summary: str


class UnderstoodInput(M):
    transcript: Optional[str]
    images: list[UnderstoodImage]
    document: Optional[UnderstoodDoc]


QuestionClass = Literal["general_knowledge", "text_explanation", "verification", "differing_opinions",
                        "personal_fatwa", "doubt_or_deep_creed", "sensitive_human", "out_of_scope"]


class Classification(M):
    question_class: QuestionClass
    label: str


class HadithGrade(M):
    grade_label: str
    grade_category: Literal["authentic", "acceptable", "weak", "fabricated", "other"]
    grader: str
    source_book: str
    reference: Optional[str]


class VerificationItem(M):
    item_id: str
    quote_text: str
    detected_kind: Literal["quran", "hadith", "claim"]
    status: Literal["quran_exact", "quran_inexact", "hadith_graded", "not_found", "needs_specialist"]
    hadith_grade: Optional[HadithGrade]
    correct_text: Optional[Evidence]
    alternative: Optional[Evidence]
    note: Spans
    source_ids: list[str]


class ReferralTarget(M):
    name: str
    description: str
    url: Optional[str]
    contact: Optional[str]


class Referral(M):
    referral_type: Literal["fatwa_authority", "specialist", "human_support"]
    reason: Spans
    targets: list[ReferralTarget]


class View(M):
    holder: str
    spans: Spans
    source_ids: list[str]


class ABParagraph(M):
    type: Literal["paragraph"]
    spans: Spans


class ABEvidence(M):
    type: Literal["evidence"]
    evidence: Evidence


class ABVerification(M):
    type: Literal["verification"]
    items: list[VerificationItem]


class ABViews(M):
    type: Literal["differing_views"]
    intro: Spans
    views: list[View]


class ABReferral(M):
    type: Literal["referral"]
    referral: Referral


AnswerBlock = Annotated[Union[ABParagraph, ABEvidence, ABVerification, ABViews, ABReferral], Field(discriminator="type")]


class Citation(M):
    ref: int
    source: Source


class LessonLink(M):
    lesson_id: str
    title: str


class RaqeebCompleted(M):
    message_id: str
    role: Literal["assistant"]
    status: Literal["completed"]
    stage: Literal["done"]
    created_at: str
    completed_at: str
    understood_input: UnderstoodInput
    classification: Classification
    abstained: bool
    blocks: list[AnswerBlock]
    citations: list[Citation]
    terms: dict[str, TermCard]
    suggested_lessons: list[LessonLink]
    feedback: Optional[Literal["up", "down"]]

    @model_validator(mode="after")
    def _rules(self):
        refs = {c.ref for c in self.citations}
        for b in self.blocks:
            spans = b.spans if b.type == "paragraph" else []
            for sp in spans:
                if sp.type == "citation" and sp.ref not in refs:
                    raise ValueError(f"citation ref {sp.ref} missing")
        if self.classification.question_class in ("personal_fatwa", "sensitive_human", "out_of_scope") and not self.abstained:
            raise ValueError("this class always abstains")
        if self.classification.question_class == "differing_opinions":
            if not any(b.type == "differing_views" for b in self.blocks) or self.blocks[-1].type != "referral":
                raise ValueError("differing_opinions: views block and final specialist referral")
        return self


# ---------------------------------------------------------------- challenges
class DuelPlayer(M):
    user_id: str
    display_name: str
    avatar_key: str
    is_me: bool
    is_bot: bool
    status: Literal["invited", "joined", "declined"]


class DuelScoring(M):
    base: int
    speed_bonus: int
    rounding: Literal["half_up", "floor"]


class DuelConfig(M):
    question_count: int
    time_limit_ms: int
    scoring: DuelScoring
    reveal_ms: int


class Score(M):
    user_id: str
    rank: int
    points: int
    correct: int


def challenge_points(correct: bool, remaining_ms: int, cfg: "DuelConfig") -> int:
    """Shared scoring: half_up = floor(x + 0.5) (Dart .round() for positive values), floor = floor(x)."""
    import math
    if not correct:
        return 0
    x = cfg.scoring.speed_bonus * max(0, remaining_ms) / cfg.time_limit_ms
    bonus = math.floor(x + 0.5) if cfg.scoring.rounding == "half_up" else math.floor(x)
    return cfg.scoring.base + bonus


class DuelResult(M):
    winner_user_ids: list[str]
    is_draw: bool
    scores: list[Score]
    xp_awarded: int


class Duel(M):
    duel_id: str
    status: Literal["pending", "ready", "in_progress", "finished", "expired", "declined"]
    mode: Literal["live", "async"]
    preset: Literal["duel", "group"]
    opponent_type: Literal["bot", "friend", "friends"]
    players: list[DuelPlayer] = Field(min_length=2, max_length=4)
    config: DuelConfig
    ws_url: str
    created_at: str
    expires_at: str
    result: Optional[DuelResult]

    @model_validator(mode="after")
    def _preset(self):
        exp = {"duel": (7, 15000, 100, 100, "floor", 3000), "group": (3, 10000, 100, 50, "half_up", 2200)}[self.preset]
        c = self.config
        if (c.question_count, c.time_limit_ms, c.scoring.base, c.scoring.speed_bonus, c.scoring.rounding, c.reveal_ms) != exp:
            raise ValueError(f"config does not match preset {self.preset}")
        if self.preset == "duel" and len(self.players) != 2:
            raise ValueError("duel has 2 players")
        return self


class WsEvent(M):
    type: Literal["state", "player_status", "player_ready", "player_left", "countdown", "question", "answer_received",
                  "opponent_answered", "question_result", "finished", "opponent_disconnected",
                  "opponent_reconnected", "error", "pong"]
    data: dict[str, Any]

    @model_validator(mode="after")
    def _typed_data(self):
        # Defined at module end so nested challenge models can be resolved.
        WS_DATA[self.type].model_validate(self.data)
        return self


EXPORTED = {
    "Session": Session, "LessonRead": LessonRead, "AnswerEvaluation": AnswerEvaluation, "AnswerRecorded": AnswerRecorded,
    "Visual": Visual, "Evidence": Evidence, "Source": Source, "TermCard": TermCard, "Exercise": Exercise,
    "RaqeebCompleted": RaqeebCompleted, "Duel": Duel, "WsEvent": WsEvent, "Image": Image, "Overlay": Overlay,
    "SceneRef": SceneRef,
}


# ---------------------------------------------------------------- journey (for the test curriculum)
class LessonRef(M):  # rev 10 curriculum amendment: a lesson named by a Soft Lock
    lesson_id: str
    unit_id: str
    title: str


class SoftLock(M):
    """Why a lesson cannot be opened yet and where to go first (rev 10 curriculum amendment).
    `prerequisites`: lessons introducing the lesson's unmet prerequisite concepts, in curriculum order.
    `start_with`: the earliest lesson on that dependency path the learner can open now."""
    prerequisites: list[LessonRef] = Field(min_length=1)
    start_with: LessonRef


class JLesson(M):
    lesson_id: str
    index: int  # curriculum position inside the unit; never an unlock dependency
    title: str
    lesson_type: Literal["concept", "story", "practice"]
    state: Literal["locked", "available", "in_progress", "completed"]
    estimated_minutes: int
    xp: int
    standalone_eligible: bool  # rev 10 curriculum amendment: listed in Discover
    soft_lock: Optional[SoftLock]  # rev 10 curriculum amendment: non-null exactly when state = locked

    @model_validator(mode="after")
    def _lock(self):
        if (self.state == "locked") != (self.soft_lock is not None):
            raise ValueError("soft_lock is present exactly when the lesson is locked")
        if self.standalone_eligible and self.state == "locked":
            raise ValueError("a standalone-eligible lesson has no mandatory prerequisites and is never locked")
        return self


class JUnitTest(M):
    state: Literal["not_passed", "passed"]
    best_percent: Optional[int]
    pass_percent: int
    can_skip: bool


class JPretest(M):  # rev 10: typed (was a generic object)
    state: Literal["taken", "not_taken"]


class JUnit(M):
    unit_id: str
    index: int
    title: str
    subtitle: str
    art_key: Optional[str]
    has_guide: bool
    state: Literal["locked", "available", "in_progress", "completed", "skipped"]
    coming_soon: bool
    pretest: JPretest
    unit_test: JUnitTest
    lessons: list[JLesson]


class JourneyCurrent(M):  # rev 10: typed (was a generic object)
    unit_id: Optional[str]
    lesson_id: Optional[str]


class Journey(M):
    track: Literal["explorer", "new_muslim"]
    current: JourneyCurrent
    units: list[JUnit]

    @model_validator(mode="after")
    def _soft_locks(self):
        # rev 10 curriculum amendment: a Soft Lock always points at real lessons of this journey,
        # and its start_with lesson can be opened now.
        lessons = {l.lesson_id: (u.unit_id, l) for u in self.units for l in u.lessons}
        for unit in self.units:
            for lesson in unit.lessons:
                if lesson.soft_lock is None:
                    continue
                for ref in lesson.soft_lock.prerequisites + [lesson.soft_lock.start_with]:
                    if ref.lesson_id not in lessons or lessons[ref.lesson_id][0] != ref.unit_id:
                        raise ValueError(f"soft_lock of {lesson.lesson_id} names a lesson outside this journey: {ref.lesson_id}")
                if lessons[lesson.soft_lock.start_with.lesson_id][1].state == "locked":
                    raise ValueError(f"soft_lock.start_with of {lesson.lesson_id} must be a lesson the learner can open")
        return self


class ErrorBody(M):
    code: str
    message: str
    details: dict[str, Any]


class ErrorEnvelope(M):
    error: ErrorBody


EXPORTED.update({"Journey": Journey, "ErrorEnvelope": ErrorEnvelope})


# ---------------------------------------------------------------- remaining API shapes (rev 4: every example has a model)
Lang = Literal["ar", "en"]


class User(M):
    user_id: str
    display_name: str
    role: Literal["learner", "reviewer"]
    language: Lang
    track: Literal["explorer", "new_muslim"]
    daily_goal_minutes: Literal[5, 10, 15, 20]
    timezone: str
    onboarding_completed: bool
    avatar_key: str
    familiarity: Optional[Literal["none", "some", "good"]]
    private_profile: bool
    created_at: str
    # rev 10 curriculum amendment: the onboarding curiosity choice (a key of registries.json
    # `goal_anchors`). It selects the onboarding bridge only; it never changes curriculum order,
    # recommendations or adaptation, and it is not a religious-identity field.
    goal_anchor: Optional[str]


class NextStep(M):
    type: Literal["pretest", "lesson", "review", "unit_test", "journey_complete"]
    reason: Literal["new_unit_pretest", "due_reviews", "next_lesson", "unit_ready_for_test", "all_done"]
    unit_id: Optional[str]
    lesson_id: Optional[str]
    title: Optional[str]
    due_reviews_count: int


class GuestReq(M):
    timezone: str


class ReviewerReq(M):
    email: str
    password: str


class AuthResp(M):
    access_token: str
    user: User


class MePatch(M):
    """PATCH /me partial update (rev 10: previously prose only). Send only the fields that change;
    none of them accepts null. Local-only preferences (sound, haptics, reduced motion, reminders) never appear."""
    display_name: Optional[str] = Field(default=None, min_length=2, max_length=24)
    language: Optional[Lang] = None
    track: Optional[Literal["explorer", "new_muslim"]] = None
    daily_goal_minutes: Optional[Literal[5, 10, 15, 20]] = None
    timezone: Optional[str] = None
    avatar_key: Optional[str] = None
    private_profile: Optional[bool] = None
    goal_anchor: Optional[str] = None  # rev 10 curriculum amendment

    @model_validator(mode="after")
    def _partial(self):
        if not self.model_fields_set:
            raise ValueError("PATCH /me needs at least one field")
        nulls = sorted(k for k in self.model_fields_set if getattr(self, k) is None)
        if nulls:
            raise ValueError(f"fields cannot be null: {nulls}")
        return self


class OnboardingReq(M):
    track_choice: Literal["explorer", "new_muslim", "undisclosed"]
    language: Lang
    familiarity: Optional[Literal["none", "some", "good"]]
    daily_goal_minutes: Literal[5, 10, 15, 20]
    private_profile: bool
    goal_anchor: Optional[str]  # rev 10 curriculum amendment: curiosity choice; null = skipped


class OnboardingResp(M):
    user: User
    start_unit_id: str
    next_step: NextStep


class Streak(M):
    current: int
    longest: int
    today_completed: bool


class DailyGoal(M):
    minutes: int
    minutes_today: int
    met: bool


class StatsLeague(M):  # rev 10: typed (was a generic object)
    league_id: str
    rank: int = Field(ge=1)
    size: int = Field(ge=1)


class ConceptCounts(M):
    mastered: int = Field(ge=0)
    learning: int = Field(ge=0)


class TermCounts(M):
    mastered: int = Field(ge=0)
    seen: int = Field(ge=0)


class MisconceptionCounts(M):
    resolved: int = Field(ge=0)
    active: int = Field(ge=0)


class Stats(M):
    xp_total: int
    xp_this_week: int
    streak: Streak
    daily_goal: DailyGoal
    league: Optional[StatsLeague]  # rev 10: null until the learner's first XP of the week assigns a league
    concepts: ConceptCounts
    terms: TermCounts
    misconceptions: MisconceptionCounts
    lessons_completed: int
    units_completed: int


class Day(M):
    date: str
    qualifying: bool
    minutes: int
    xp: int


class Activity(M):
    timezone: str
    from_: str = Field(alias="from")
    to: str
    streak: Streak
    days: list[Day]


class Quest(M):
    quest_id: str
    kind: Literal["earn_xp", "complete_lessons", "perfect_lesson", "complete_review", "win_challenge", "recite_verse"]
    title: str
    progress: int
    goal: int
    reward_xp: int
    completed: bool


class Quests(M):
    date: str
    resets_in_seconds: int
    items: list[Quest] = Field(min_length=3, max_length=3)


class AchievementProgress(M):  # rev 10: typed (was a generic object)
    current: int = Field(ge=0)
    target: int = Field(ge=1)


class Achievement(M):
    achievement_key: str
    title: str
    description: str
    unlocked: bool
    unlocked_at: Optional[str]
    progress: AchievementProgress


class Achievements(M):
    items: list[Achievement]


class ConceptRow(M):
    concept_id: str
    title: str
    unit_id: str
    mastery: float
    next_review_at: Optional[str]


def Page(model):
    class _P(M):
        items: list[model]  # type: ignore[valid-type]
        next_cursor: Optional[str]
    _P.__name__ = f"Page[{model.__name__}]"
    return _P


class GuideSection(M):
    title: str
    sentences: list[Sentence]


class Guide(M):
    unit_id: str
    title: str
    sections: list[GuideSection]
    sources: list[Source]
    terms: dict[str, TermCard]


class SessionCreate(M):
    kind: Literal["lesson", "review", "pretest", "unit_test"]
    lesson_id: Optional[str] = None
    unit_id: Optional[str] = None
    mode: Optional[Literal["cards", "quick"]] = None

    @model_validator(mode="after")
    def _shape(self):
        need = {"lesson": "lesson_id", "pretest": "unit_id", "unit_test": "unit_id"}.get(self.kind)
        if need and getattr(self, need) is None:
            raise ValueError(f"{self.kind} requires {need}")
        if (self.kind == "review") != (self.mode is not None):
            raise ValueError("mode is required for review and only for review")
        return self


class AnswerSubmit(M):
    exercise_id: str
    answer: Optional[SubmittedAnswer]
    elapsed_ms: int
    is_retry: bool


class FinishReq(M):
    duration_ms: int


class LayerResult(M):
    correct: int
    total: int
    percent: int


class Layers(M):
    understanding: Optional[LayerResult]
    applying: Optional[LayerResult]
    remembering: None


XpReason = Literal["lesson_complete", "lesson_perfect", "recitation_passed", "review_complete", "pretest_complete",
                   "unit_test_passed", "duel_win", "duel_draw", "duel_loss", "group_rank_1", "group_rank_2",
                   "group_rank_other", "daily_goal_met", "quest_complete"]


class XpGrant(M):  # rev 10: typed; reasons are the backend §10.1 table
    reason: XpReason
    xp: int = Field(ge=0)


class XpSummary(M):
    total: int = Field(ge=0)
    breakdown: list[XpGrant]

    @model_validator(mode="after")
    def _sum(self):
        if self.total != sum(g.xp for g in self.breakdown):
            raise ValueError("xp.total must equal the sum of xp.breakdown")
        return self


class StreakUpdate(M):
    current: int = Field(ge=0)
    extended_today: bool


class TermRef(M):
    term_id: str
    text: str


class MisconceptionRef(M):
    misconception_id: str
    title: str


class MisconceptionChanges(M):
    activated: list[MisconceptionRef]
    resolved: list[MisconceptionRef]


class Unlock(M):
    type: Literal["lesson", "unit"]
    id: str
    title: str


class ReviewItem(M):  # unit_test answer review (feedback mode `end`, after finish)
    exercise_id: str
    correct: Optional[bool]
    correct_answer: Optional[CorrectAnswer]
    explanation: Spans
    source_ids: list[str]


class SessionResult(M):
    session_id: str
    kind: Literal["lesson", "review", "pretest", "unit_test"]
    score: LayerResult  # same {correct, total, percent} shape
    passed: Optional[bool]
    xp: XpSummary
    duration_ms: int
    layers: Layers
    streak: StreakUpdate
    daily_goal: DailyGoal
    mastery_summary: list[MasteryChange]
    terms_mastered: list[TermRef]
    misconceptions: MisconceptionChanges
    unlocked: list[Unlock]
    review_items: Optional[list[ReviewItem]]
    next_step: NextStep

    @model_validator(mode="after")
    def _kind_rules(self):
        if (self.kind == "unit_test") != (self.passed is not None):
            raise ValueError("passed is set for unit_test and only for unit_test")
        if (self.kind == "unit_test") != (self.review_items is not None):
            raise ValueError("review_items is a list for unit_test and null otherwise")
        return self


class AudioSeg(M):
    url: str
    start_ms: int
    end_ms: int


class RecWord(M):
    index: int
    expected: Optional[str]
    result: Literal["correct", "missing", "substituted", "extra"]
    heard: Optional[str]
    audio_segment: Optional[AudioSeg]


class RecSummary(M):  # rev 10: typed (was a generic object)
    correct: int = Field(ge=0)
    missing: int = Field(ge=0)
    substituted: int = Field(ge=0)
    extra: int = Field(ge=0)


class RecitationCheck(M):
    check_id: str
    status: Literal["evaluated", "unclear"]
    passed: bool
    words: list[RecWord]
    summary: RecSummary
    message: Spans

    @model_validator(mode="after")
    def _consistent(self):
        counts = {k: sum(1 for w in self.words if w.result == k) for k in ("correct", "missing", "substituted", "extra")}
        if counts != self.summary.model_dump():
            raise ValueError("summary must count the words by result")
        if self.status == "unclear" and (self.passed or self.words):
            raise ValueError("unclear checks have passed=false and no words")
        if self.passed != (self.status == "evaluated" and counts["missing"] == 0 and counts["substituted"] == 0):
            raise ValueError("passed = evaluated with no missing or substituted words")
        return self


class ConvCreate(M):
    context: Optional[dict[str, Optional[str]]]


class Conversation(M):
    conversation_id: str
    title: Optional[str]
    context: Optional[dict[str, Optional[str]]]
    created_at: str
    updated_at: str


class ConvRow(M):
    conversation_id: str
    title: Optional[str]
    last_message_preview: str
    updated_at: str


class Attachment(M):
    attachment_id: str
    kind: Literal["audio", "image", "document"]
    filename: str
    mime: str
    size_bytes: int
    url: Optional[str]
    duration_ms: Optional[int]
    pages: Optional[int]


class UserMessage(M):
    message_id: str
    role: Literal["user"]
    status: Literal["received"]
    text: Optional[str]
    attachments: list[Attachment]
    created_at: str


Stage = Literal["received", "reading_inputs", "classifying", "retrieving", "verifying", "writing", "adapting", "done"]


class AssistantProcessing(M):
    message_id: str
    role: Literal["assistant"]
    status: Literal["processing"]
    stage: Stage
    created_at: str


class MessageError(M):  # rev 10: typed (was a generic object)
    code: Literal["upstream_unavailable", "internal_error", "input_unreadable"]
    message: str


class AssistantFailed(M):
    message_id: str
    role: Literal["assistant"]
    status: Literal["failed"]
    stage: Stage
    created_at: str
    error: MessageError


class PostMessageResp(M):
    user_message: UserMessage
    assistant_message: AssistantProcessing


# rev 10: GET /raqeeb/messages/{id} and conversation history are typed unions discriminated by `status`
# (user messages are `received`; assistant messages are `processing`, `failed` or `completed`).
AssistantState = Annotated[Union[AssistantProcessing, AssistantFailed, RaqeebCompleted], Field(discriminator="status")]
ConversationMessage = Annotated[Union[UserMessage, AssistantProcessing, AssistantFailed, RaqeebCompleted],
                                Field(discriminator="status")]


class AssistantMessage(RootModel[AssistantState]):
    pass


class ConvDetail(M):
    conversation: Conversation
    messages: list[ConversationMessage]


class FeedbackReq(M):
    rating: Literal["up", "down"]
    reason: Optional[Literal["inaccurate", "unclear", "not_helpful", "other"]]
    comment: Optional[str]


class Tier(M):
    tier_key: str
    index: int
    name: str
    is_top_tier: bool


class LeagueMember(M):
    rank: int
    user_id: str
    display_name: str
    xp_week: int
    is_me: bool
    avatar_key: str
    in_promotion_zone: bool


class League(M):
    league_id: str
    week_start: str
    week_end: str
    ends_in_seconds: int
    my_rank: int
    tier: Tier
    promotion_zone_size: int
    demotion: Literal[False]
    members: list[LeagueMember]


class Friend(M):
    user_id: str
    display_name: str
    xp_week: Optional[int]
    streak_current: Optional[int]
    online: bool
    avatar_key: str


class Invite(M):
    invite_id: str
    code: str
    share_text: str
    expires_at: str


class InviteAccept(M):
    code: str


class DuelCreate(M):
    preset: Literal["duel", "group"]
    opponent_type: Literal["bot", "friend", "friends"]
    friend_user_ids: list[str]
    bot_fill: bool

    @model_validator(mode="after")
    def _shape(self):
        n = len(self.friend_user_ids)
        ok = {("duel", "bot"): n == 0, ("duel", "friend"): n == 1, ("group", "friends"): 1 <= n <= 3}.get((self.preset, self.opponent_type), False)
        if not ok:
            raise ValueError("invalid preset/opponent_type/friend_user_ids combination")
        return self


class InvitationFrom(M):  # rev 10: typed (was a generic object)
    user_id: str
    display_name: str


class Invitation(M):
    duel_id: str
    from_: InvitationFrom = Field(alias="from")
    created_at: str
    expires_at: str


class AsyncNext(M):
    question_index: int
    total: int
    exercise: Exercise
    issued_at: str
    deadline_at: str


class AsyncAnswer(M):
    question_index: int = Field(ge=0)
    answer: Optional[Union[AOption, AValue]]  # rev 10: typed; null = no answer before the deadline (scores 0)


class AsyncAnswerResp(M):
    question_index: int = Field(ge=0)
    correct: bool
    correct_answer: Union[AOption, AValue]
    points: int
    explanation: Spans
    total_points: int
    finished: bool


class RunCreate(M):
    unit_id: str
    lesson_type: Literal["concept", "story", "practice"]
    brief: str
    position_index: int


RunStatus = Literal["running", "awaiting_gate1", "awaiting_gate2", "published", "rejected", "failed"]
RunStage = Literal["plan", "decompose", "retrieve", "verify_evidence", "write", "exercises", "glossary", "localize",
                   "visuals", "scene_author", "scene_render", "narration", "qa"]  # `localize`: rev 10 curriculum amendment
Digest = Annotated[str, Field(pattern=r"^[0-9a-f]{64}$")]


class RunRow(M):
    run_id: str
    unit_id: str
    lesson_type: Literal["concept", "story", "practice"]
    title: Optional[str]
    status: RunStatus
    stage: RunStage
    updated_at: str


# rev 10: the reviewer/factory surface below was exported as generic objects in revision 9.
class StageStatus(M):
    stage: RunStage
    status: Literal["pending", "running", "done", "failed", "skipped"]
    started_at: Optional[str]
    finished_at: Optional[str]


class TargetMisconception(M):
    misconception_id: Optional[str]  # null = new misconception proposed by the plan
    title: LocalizedText
    description: LocalizedText


# rev 10 curriculum amendment: pedagogical planning fields decided by the Curriculum Architect
# and approved at Gate 1 (factory §13.1). Product targets (minutes, terms, exercise ranges per
# lesson type) are QA warnings; only the bounds below are structural.
ReasoningTool = Literal["observation", "inference", "testimony", "historical_evidence", "causal_reasoning", "comparison"]
SentenceRole = Literal["claim", "framing", "hypothetical", "instruction", "question"]


def _filled(text) -> bool:
    return bool(text.ar.strip()) and bool(text.en.strip())


ArcTechnique = Literal["scenario", "prediction", "example", "story", "demonstration", "explanation", "evidence",
                       "comparison", "practice", "reflection", "takeaway"]  # lesson-composition refinement


class ArcStep(M):
    step_id: str
    technique: ArcTechnique  # the pedagogical technique this step uses; the set of techniques = the lesson's modes
    experience: LocalizedText  # what the learner should experience or do at this step
    interactive: bool  # the learner acts here (prediction, poll or exercise)

    @model_validator(mode="after")
    def _text(self):
        if not _filled(self.experience):
            raise ValueError("an arc step describes the learner's experience in both languages")
        return self


class LessonArc(M):
    """Lesson-specific pedagogical journey (not a fixed template) and the composition plan of the ONE
    lesson. `pattern` is a short label such as discovery, misconception, story, practice or comparison,
    or any name the architect constructs. Steps name only the techniques this lesson needs."""
    pattern: str = Field(min_length=1)
    rationale: LocalizedText
    steps: list[ArcStep] = Field(min_length=2)

    @model_validator(mode="after")
    def _steps(self):
        ids = [step.step_id for step in self.steps]
        if len(ids) != len(set(ids)):
            raise ValueError("arc step ids must be unique")
        if not any(step.interactive for step in self.steps):
            raise ValueError("a lesson arc needs at least one interactive step")
        if sum(step.technique == "takeaway" for step in self.steps) > 1:
            raise ValueError("a lesson has at most one takeaway step")
        return self


class ReasoningToolUse(M):
    tool: ReasoningTool
    justification: LocalizedText  # why this lesson actually needs the tool

    @model_validator(mode="after")
    def _why(self):
        if not _filled(self.justification):
            raise ValueError("every reasoning tool needs a justification in both languages")
        return self


DepthProfile = Literal["foundational", "standard", "focused"]  # lesson-depth refinement; not difficulty


class LessonPlan(M):
    title: LocalizedText
    central_question: LocalizedText  # lesson-depth refinement: the learner question this lesson answers completely
    primary_learning_outcome: LocalizedText  # rev 10 curriculum amendment: one coherent outcome (not one fact)
    supporting_understandings: list[LocalizedText]  # lesson-depth refinement: ideas needed to complete the outcome; never separate lessons
    depth_profile: DepthProfile  # lesson-depth refinement: foundational / standard / focused
    objectives: list[LocalizedText] = Field(min_length=1, max_length=3)  # learner-facing intro wording of that outcome
    prerequisite_concept_ids: list[str]  # mandatory prerequisites (the unlock input); curriculum position never is
    introduced_concept_ids: list[str]  # rev 10 curriculum amendment
    new_terms: list[LocalizedText]
    target_misconceptions: list[TargetMisconception]
    lesson_type: Literal["concept", "story", "practice"]
    estimated_minutes: int = Field(ge=1)  # the whole composed lesson; guidance, not a cap (curriculum: completeness and depth)
    lesson_arc: LessonArc  # rev 10 curriculum amendment
    reasoning_tools: list[ReasoningToolUse]  # rev 10 curriculum amendment; empty = none needed
    standalone_eligible: bool  # rev 10 curriculum amendment: may appear in Discover
    content_budget: int = Field(ge=1)  # planned non-interactive learner-experience blocks the depth needs (sized to depth, not minimised)
    exercise_budget: int = Field(ge=2, le=6)  # planned graded lesson exercises (interactions such as predictions and polls are separate)

    @model_validator(mode="after")
    def _plan(self):
        if not _filled(self.primary_learning_outcome):
            raise ValueError("the primary learning outcome is required in both languages")
        if not _filled(self.central_question):
            raise ValueError("the central learner question is required in both languages")
        if not all(_filled(u) for u in self.supporting_understandings):
            raise ValueError("every supporting understanding is written in both languages")
        if self.standalone_eligible and self.prerequisite_concept_ids:
            raise ValueError("a standalone-eligible lesson cannot have mandatory prerequisites")
        if set(self.prerequisite_concept_ids) & set(self.introduced_concept_ids):
            raise ValueError("a concept cannot be both a prerequisite and introduced by the same lesson")
        tools = [use.tool for use in self.reasoning_tools]
        if len(tools) != len(set(tools)):
            raise ValueError("each reasoning tool is listed once")
        # lesson_type is the primary mode; the arc must actually use it (other techniques are optional tools).
        techniques = {step.technique for step in self.lesson_arc.steps}
        primary = {"story": {"story"}, "practice": {"practice"}}.get(self.lesson_type)
        if primary and not techniques & primary:
            raise ValueError(f"a {self.lesson_type} lesson's arc needs a {self.lesson_type} step")
        return self


SemanticFit = Literal["exact", "partial", "stretched", "unrelated"]  # pre-generation audit: semantic scholarly review
SemanticConcern = Literal["needs_tafsir", "context_dependent", "addressee_specific", "generalised_from_specific",
                          "beyond_source", "scholarly_disagreement", "single_opinion_as_consensus", "oversimplified",
                          "translation_sensitive"]


class SemanticReview(M):
    """Pre-generation audit: the Evidence Verifier's semantic reading of one evidence item against the exact claim
    wording. It flags; the specialist decides at Gate 2. `exact`: the source states the claim as worded. `partial`:
    it supports the claim with a named concern. `stretched`: the claim says more than, or other than, the source.
    `unrelated`: the source does not address the claim."""
    fit: SemanticFit
    concerns: list[SemanticConcern]
    note: str = Field(min_length=1)

    @model_validator(mode="after")
    def _fit(self):
        if len(set(self.concerns)) != len(self.concerns):
            raise ValueError("each semantic concern is listed once")
        if self.fit == "partial" and not self.concerns:
            raise ValueError("a partial fit names its concern")
        return self


class ClaimEvidence(M):
    source: Source
    supports: bool
    verifier_note: str
    semantic_review: Optional[SemanticReview]  # pre-generation audit: required on supporting Quran, hadith and tafsir evidence

    @model_validator(mode="after")
    def _semantic(self):
        review = self.semantic_review
        if self.supports and self.source.kind in SCRIPTURE_KINDS and review is None:
            raise ValueError("supporting scripture or tafsir evidence needs a semantic review")
        if self.supports and review is not None and review.fit in ("stretched", "unrelated"):
            raise ValueError("stretched or unrelated evidence cannot support a claim")
        return self


class ReasoningSupport(M):
    """rev 10 curriculum amendment: reasoning a learner can evaluate without first accepting the
    authority of scripture. Human-reviewed like source evidence."""
    tool: ReasoningTool  # must be one of the approved plan's reasoning tools
    premises: list[str] = Field(min_length=1)
    inference: str = Field(min_length=1)


SCRIPTURE_KINDS = ("quran", "hadith", "tafsir")


class Claim(M):
    claim_id: str
    text: str
    status: Literal["supported", "dropped"]
    basis: Literal["source", "reasoning"]  # rev 10 curriculum amendment: scriptural/source support vs reasoning support
    evidence: list[ClaimEvidence]
    reasoning: Optional[ReasoningSupport]  # rev 10 curriculum amendment: only for basis = reasoning

    @model_validator(mode="after")
    def _support(self):
        if self.basis == "source":
            if self.reasoning is not None:
                raise ValueError("a source-based claim carries no reasoning support")
            if self.status == "supported" and not any(e.supports for e in self.evidence):
                raise ValueError("a supported claim needs at least one supporting evidence item")
        else:
            if self.status == "supported" and self.reasoning is None:
                raise ValueError("a supported reasoning claim needs its reasoning support")
            if any(e.supports and e.source.kind in SCRIPTURE_KINDS for e in self.evidence):
                raise ValueError("scripture never establishes a reasoning claim (no circular support)")
        return self


class SentenceClaims(M):
    sentence_id: str
    role: SentenceRole  # rev 10 curriculum amendment
    claim_ids: list[str]

    @model_validator(mode="after")
    def _role(self):
        # Only assertions need evidence; framing, hypotheticals, instructions and questions assert nothing.
        if (self.role == "claim") != bool(self.claim_ids):
            raise ValueError("a claim sentence links at least one claim; other roles link none")
        return self


ANSWER_KEY_MODEL = {
    "multiple_choice": AOption, "which_evidence": AOption, "scenario": AOption, "verse_meaning": AOption,
    "true_false": AValue, "true_false_reason": AReason, "match_pairs": APairs, "fill_blank": AFills,
    "categorize": AAssignments, "spot_error": ASegment, "order_steps": AOrder, "timeline_order": AOrder,
    "map_place": APin, "flashcard": None, "recite_verse": None,
}


class ReviewerExercise(Exercise):
    """Reviewer/storage projection of an exercise. Never served to learners (private key)."""
    answer_key: Optional[CorrectAnswer]  # null only for flashcard (self-rated) and recite_verse (bound check)
    option_misconceptions: dict[str, str]  # option_id -> misconception_id
    duel_eligible: bool

    @model_validator(mode="after")
    def _key(self):
        expected = ANSWER_KEY_MODEL[self.type]
        if expected is None:
            if self.answer_key is not None:
                raise ValueError(f"{self.type} has no stored answer key")
        elif not isinstance(self.answer_key, expected):
            raise ValueError(f"{self.type} needs a {expected.__name__} answer key")
        if self.duel_eligible and self.type not in ("multiple_choice", "true_false", "verse_meaning"):
            raise ValueError("only closed challenge types can be duel eligible")
        return self


class VisualAudit(M):
    passed: bool
    issues: list[str]


class QALocation(M):
    sentence_id: Optional[str]
    exercise_id: Optional[str]
    scene_id: Optional[str]


QAKind = Literal["unsupported_sentence", "fatwa_like", "reading_level", "consistency", "sensitive", "image_policy",
                 "validation",  # rev 10: deterministic code-validator finding (factory §13.5)
                 "pedagogy", "belief_grading", "circular_reasoning", "localization",  # rev 10 curriculum amendment
                 "scholarly_review"]  # pre-generation audit: semantic flags on scriptural support for the specialist


class QAIssue(M):
    severity: Literal["blocker", "warning", "info"]
    kind: QAKind
    location: QALocation
    message: str


class QAReport(M):
    issues: list[QAIssue]


class Preview(M):
    language: Lang
    variant: Literal["explorer", "new_muslim"]
    objectives: list[Spans]
    items: list[Block]
    completion: Optional[Completion]


class PreviewFrame(M):
    state: dict[str, Any]
    time_ms: int
    reduced_motion: bool
    image: Image


class AnimationPreview(M):
    url: str
    mime_type: Literal["video/webm"]
    width: int
    height: int
    duration_ms: int


class PreviewTiming(M):
    build_raster_p95_ms: float
    first_frame_ms: float
    device: str


class ScenePreview(M):
    frames: list[PreviewFrame] = Field(min_length=1)
    animation: AnimationPreview
    reduced_motion_still: Image
    fallbacks: list[PreviewFrame]
    timing: PreviewTiming
    renderer_version: str


class DraftVisual(M):
    scene_id: str
    origin: Literal["builtin", "generated", "generated_scene"]
    visual: Visual
    audit: Optional[VisualAudit]
    attempts: int
    previews: Optional[ScenePreview]

    @model_validator(mode="after")
    def _origin(self):
        exp = {"builtin": "builtin", "generated": "image", "generated_scene": "scene"}[self.origin]
        if self.visual.kind != exp:
            raise ValueError(f"origin {self.origin} requires visual.kind {exp}")
        if (self.origin == "generated_scene") != (self.previews is not None):
            raise ValueError("previews are required for generated_scene and only for it")
        if self.origin == "builtin" and (self.audit is not None or self.attempts != 0):
            raise ValueError("builtin visuals have no audit or attempts")
        return self


class ArcStepBlocks(M):  # rev 10 curriculum amendment: which blocks realise an approved arc step
    step_id: str
    block_ids: list[str] = Field(min_length=1)


class Draft(M):
    languages: list[Lang]
    variants: list[Literal["explorer", "new_muslim"]]
    previews: list[Preview]
    claims: list[Claim]
    sentence_map: list[SentenceClaims]
    arc_map: list[ArcStepBlocks]  # rev 10 curriculum amendment; the same block ids in every preview
    exercises: list[ReviewerExercise]
    glossary: list[StoredGlossaryTerm]
    misconceptions: list[Misconception]
    visuals: list[DraftVisual]

    @model_validator(mode="after")
    def _arc(self):
        steps = [row.step_id for row in self.arc_map]
        if len(steps) != len(set(steps)):
            raise ValueError("each arc step appears once in arc_map")
        return self


class DraftFragment(M):
    draft: Draft
    qa_report: QAReport


class RunError(M):
    code: str
    message: str


class PublishedRef(M):
    lesson_id: str
    version: int = Field(ge=1)


class FactoryRun(M):
    run_id: str
    unit_id: str
    lesson_type: Literal["concept", "story", "practice"]
    brief: str
    status: RunStatus
    stage: RunStage
    stages: list[StageStatus]
    plan: Optional[LessonPlan]
    draft: Optional[Draft]
    qa_report: Optional[QAReport]
    error: Optional[RunError]
    review_digest: Optional[Digest]  # rev 10: digest of the artifact awaiting a gate; echoed by Gate1/Gate2
    published: Optional[PublishedRef]  # rev 10: set exactly when status = published

    @model_validator(mode="after")
    def _status(self):
        at_gate = self.status in ("awaiting_gate1", "awaiting_gate2")
        if at_gate != (self.review_digest is not None):
            raise ValueError("review_digest is present exactly while the run awaits a gate")
        if self.status == "awaiting_gate1" and self.plan is None:
            raise ValueError("awaiting_gate1 needs the plan")
        if self.status == "awaiting_gate2" and (self.draft is None or self.qa_report is None):
            raise ValueError("awaiting_gate2 needs draft and qa_report")
        if (self.status == "published") != (self.published is not None):
            raise ValueError("published is set exactly when status = published")
        if (self.status == "failed") != (self.error is not None):
            raise ValueError("error is set exactly when status = failed")
        return self


class Gate1(M):
    decision: Literal["approve", "reject"]
    plan: Optional[LessonPlan]  # full edited plan, only with approve; null = approve as shown
    reason: Optional[str]
    review_digest: Digest  # rev 10: FactoryRun.review_digest the reviewer saw

    @model_validator(mode="after")
    def _shape(self):
        if self.decision == "reject" and self.plan is not None:
            raise ValueError("an edited plan is sent only with approve")
        return self


class SentenceEdit(M):
    sentence_id: str
    language: Lang
    variant: Literal["explorer", "new_muslim"]
    new_text: str = Field(min_length=1)


class Gate2(M):
    decision: Literal["approve", "request_changes", "reject"]
    sentence_edits: list[SentenceEdit]
    exercise_removals: list[str]
    reason: Optional[str]
    review_digest: Digest  # rev 10: FactoryRun.review_digest the reviewer saw

    @model_validator(mode="after")
    def _shape(self):
        if self.decision != "approve" and (self.sentence_edits or self.exercise_removals):
            raise ValueError("edits and removals are sent only with approve")
        if self.decision == "request_changes" and not (self.reason or "").strip():
            raise ValueError("request_changes needs a reason")
        # rev 10 curriculum amendment: Arabic is the semantic source, so an Arabic edit carries the
        # matching English localization of the same sentence and variant in the same decision.
        english = {(e.sentence_id, e.variant) for e in self.sentence_edits if e.language == "en"}
        unpaired = [e.sentence_id for e in self.sentence_edits if e.language == "ar" and (e.sentence_id, e.variant) not in english]
        if unpaired:
            raise ValueError(f"Arabic sentence edits need the matching English edit: {unpaired}")
        return self


class BlindLesson(M):
    title: str
    objectives: list[Spans]
    items: list[Block]
    completion: Optional[Completion]


class BlindPair(M):
    pair_id: str
    lesson_a: BlindLesson
    lesson_b: BlindLesson


class BlindAnswer(M):
    clearer: Literal["a", "b", "same"]
    more_accurate: Literal["a", "b", "same"]
    guessed_handwritten: Literal["a", "b", "unsure"]


class PrePost(M):
    unit_id: str
    unit_title: str
    participants: int = Field(ge=1)
    pre_avg_percent: int
    post_avg_percent: int
    delta: int


class MisconceptionMetrics(M):
    activated: int
    resolved: int
    resolution_rate_percent: Optional[int]  # null when nothing was activated


class CompletionMetrics(M):
    units_started: int
    units_completed: int


class LearningMetrics(M):
    pre_post: list[PrePost]
    misconceptions: MisconceptionMetrics
    completion: CompletionMetrics


class BenchmarkSystem(M):
    name: Literal["raqeeb", "baseline_llm"]
    accuracy_percent: int
    unsupported_claim_rate_percent: int
    correct_abstention_percent: int
    correct_referral_percent: int


class BenchmarkClass(M):
    question_class: Literal["general_knowledge", "text_explanation", "verification", "differing_opinions",
                            "personal_fatwa", "doubt_or_deep_creed", "sensitive_human", "out_of_scope"]
    raqeeb_accuracy_percent: int
    baseline_accuracy_percent: int


class BenchmarkMetrics(M):
    run_at: str
    question_count: int
    systems: list[BenchmarkSystem]
    by_class: list[BenchmarkClass]


class BlindMetrics(M):
    responses: int
    handwritten_identified_percent: Optional[int]  # null when there are no responses
    generated_preferred_or_same_percent: Optional[int]


class FactoryMetrics(M):
    lessons_published: int
    avg_generation_minutes: Optional[int]  # null before the first measured run
    avg_review_minutes: Optional[int]
    blind_test: BlindMetrics


class Metrics(M):
    learning: LearningMetrics
    raqeeb_benchmark: Optional[BenchmarkMetrics]  # null before the first stored benchmark run
    factory: FactoryMetrics


EXPORTED.update({n: globals()[n] for n in [
    "User", "NextStep", "AuthResp", "OnboardingReq", "OnboardingResp", "Stats", "Activity", "Quests", "Achievements",
    "Guide", "SessionCreate", "AnswerSubmit", "SessionResult", "RecitationCheck", "Conversation", "PostMessageResp",
    "AssistantProcessing", "AssistantFailed", "League", "Friend", "Invite", "DuelCreate", "DuelResult", "AsyncNext",
    "AsyncAnswerResp", "FactoryRun", "Draft", "Gate1", "Gate2", "BlindPair", "BlindAnswer", "Metrics"]})
# rev 10: every request/response body used by an endpoint is an exported root (see ../CHANGES.md).
EXPORTED.update({n: globals()[n] for n in [
    "GuestReq", "ReviewerReq", "MePatch", "FinishReq", "ConvCreate", "ConvDetail", "AssistantMessage", "FeedbackReq",
    "InviteAccept", "AsyncAnswer", "RunCreate", "DraftFragment", "LessonPlan", "ReviewerExercise"]})
EXPORTED.update({
    "ConceptPage": Page(ConceptRow), "ConversationPage": Page(ConvRow), "FriendPage": Page(Friend),
    "InvitationPage": Page(Invitation), "DuelPage": Page(Duel), "RunPage": Page(RunRow),
})

# Server event shapes, including reconnect snapshots and nested questions.
class WPlayer(M):
    user_id: str

class WPlayerStatus(WPlayer):
    status: Literal["invited", "joined", "declined"]

class WDisconnected(WPlayer):
    grace_ms: int = Field(ge=0)

class WIndex(M):
    question_index: int = Field(ge=0)

class WOpponentAnswered(WIndex):
    user_id: str

class WCountdown(M):
    starts_at: str
    seconds: int = Field(ge=0)

class WQuestion(WIndex):
    total: int = Field(gt=0)
    exercise: Exercise
    issued_at: str
    deadline_at: str

    @model_validator(mode="after")
    def _question(self):
        if self.question_index >= self.total:
            raise ValueError("question_index must be smaller than total")
        if self.exercise.type not in ("multiple_choice", "true_false", "verse_meaning"):
            raise ValueError("unsupported challenge question type")
        return self

class WPoints(M):
    user_id: str
    points: int = Field(ge=0)

class WPlayerResult(WPoints):
    correct: bool
    elapsed_ms: int = Field(ge=0)

class WQuestionResult(WIndex):
    correct_answer: Union[AOption, AValue]
    explanation: Spans
    players: list[WPlayerResult] = Field(min_length=2, max_length=4)
    totals: list[WPoints] = Field(min_length=2, max_length=4)

class WLocked(M):
    answer: Optional[Union[AOption, AValue]]
    locked: Literal[True]

class WLive(M):
    phase: Literal["countdown", "question", "result", "finished"]
    question_index: int = Field(ge=0)
    question: Optional[WQuestion]
    deadline_at: Optional[str]
    answered_user_ids: list[str]
    my_answer: Optional[WLocked]
    totals: list[WPoints]
    results_so_far: list[WQuestionResult]

class WState(M):
    duel: Duel
    server_ts: str
    live: Optional[WLive]

class WSummary(WIndex):
    prompt: Spans
    correct_answer: Union[AOption, AValue]
    explanation: Spans

class WFinished(M):
    result: DuelResult
    summary: list[WSummary]

class WError(M):
    code: str
    message: str

class WEmpty(M):
    pass

WS_DATA = {
    "state": WState, "player_status": WPlayerStatus, "player_ready": WPlayer,
    "player_left": WPlayer, "countdown": WCountdown, "question": WQuestion,
    "answer_received": WIndex, "opponent_answered": WOpponentAnswered,
    "question_result": WQuestionResult, "finished": WFinished,
    "opponent_disconnected": WDisconnected, "opponent_reconnected": WPlayer,
    "error": WError, "pong": WEmpty,
}


# rev 10: client -> server challenge socket messages (contract §8.1), previously prose only.
class WClientAnswer(WIndex):
    answer: Union[AOption, AValue]  # closed challenge types only; no message is sent when the timer expires


WS_CLIENT_DATA = {"ready": WEmpty, "answer": WClientAnswer, "ping": WEmpty}


class WsClientMessage(M):
    type: Literal["ready", "answer", "ping"]
    data: dict[str, Any]

    @model_validator(mode="after")
    def _typed_data(self):
        WS_CLIENT_DATA[self.type].model_validate(self.data)
        return self


EXPORTED.update({'Journey': Journey, 'ErrorEnvelope': ErrorEnvelope, 'DuelConfig': DuelConfig})
EXPORTED['WsClientMessage'] = WsClientMessage
EXPORTED.update({m.__name__: m for m in [AOption, AValue, AReason, APairs, AFills,
    AAssignments, ASegment, AOrder, APin, ARating, ACheck, ASkipped, AUnavailable,
    DReason, DPairs, DFills, DAssignments, DOrder, DScenario, DTimeline, DPins]})
EXPORTED.update({m.__name__: m for m in [Category, CatItem, Step, POrderSteps,
    PCategorize, StoredGlossaryTerm]})
EXPORTED['GlossaryPage'] = Page(TermCard)
EXPORTED['Draft'] = Draft
