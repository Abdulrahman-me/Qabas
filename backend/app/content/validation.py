"""Deterministic content validators: the publication gate's code checks.

They apply identically to factory output, gold imports and fixtures (factory §13.3 "the same rules apply to
factory output and gold imports"; §13.5 ``validation`` rows; backend §6.5). Every problem is reported with
its location; nothing is repaired or guessed. Judgement checks (pedagogy, belief grading, circular reasoning,
localization meaning, scholarly fit) belong to model QA and reviewers (Phase 12), not to this module.

Database-dependent rules (prerequisites introduced by earlier published lessons in every track, concepts
introduced once, referenced scenes published) are checked by :mod:`app.content.store` at publication.
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass, field
from typing import Any

from app.content.package import LANGS, LessonPackage, VariantContent, sentences_of
from app.content.projection import display_roles, referenced_source_ids, resolve_items, term_ids
from app.contract import contextual

MAX_CONTENT_SOURCES = 3              # factory §13.2 evidence budget, per language x variant
GRADED_BOUNDS = (2, 6)               # structural bound for lesson exercises (AD-30, contextual.py)
PRETEST_PER_LESSON = 2               # factory §13.3
PRETEST_POOL_MIN = 6                 # backend §6.2: a pretest needs >= 6 unit pretest items
UNIT_TEST_POOL_MIN = 9               # backend §6.2: a unit test needs >= 9 unit-test items
UNIT_TEST_PER_LESSON = 3
DUEL_PER_LESSON = 3
NON_ASSESSMENT_TYPES = ("recite_verse", "flashcard")
DUEL_TYPES = ("multiple_choice", "true_false", "verse_meaning")

# Arc technique -> block types that may realise it (factory §13.5 lesson-composition validation).
STORY_TECHNIQUES = {"story", "scenario"}
PREDICT_TECHNIQUES = {"prediction", "reflection"}


@dataclass(frozen=True)
class Issue:
    code: str
    message: str
    location: str = ""

    def __str__(self) -> str:
        return f"[{self.code}] {self.location}: {self.message}" if self.location else f"[{self.code}] {self.message}"


class ContentValidationError(ValueError):
    def __init__(self, issues: list[Issue]) -> None:
        self.issues = issues
        super().__init__("content failed validation:\n" + "\n".join(f"  - {i}" for i in issues))


@dataclass
class Context:
    """What the package is validated against (its slot, its unit's tracks and what already exists)."""

    unit_tracks: list[str]
    known_terms: set[str] = field(default_factory=set)
    known_sources: set[str] = field(default_factory=set)
    known_misconceptions: set[str] = field(default_factory=set)
    known_concepts: set[str] = field(default_factory=set)
    allow_placeholder_media: bool = False  # only for test fixtures, never production (D-29, D-84)
    allow_timed_items: bool = False        # only for test fixtures: the contract specimens carry 20 s timers (D-61)


def validate_package(package: LessonPackage, ctx: Context) -> list[Issue]:
    issues: list[Issue] = []
    checks = (_variants, _skeleton, _localization_parity, _sentence_roles, _claims, _arc_map, _exercises,
              _assessment_items, _sources, _terms, _completion, _misconceptions, _media)
    for check in checks:
        issues.extend(check(package, ctx))
    return issues


def require_valid(package: LessonPackage, ctx: Context) -> None:
    issues = validate_package(package, ctx)
    if issues:
        raise ContentValidationError(issues)


# --------------------------------------------------------------------------------------- variants

def _variants(p: LessonPackage, ctx: Context) -> list[Issue]:
    issues = []
    if set(p.variants) != set(LANGS):
        return [Issue("variants", "a lesson is published in both Arabic and English", "variants")]
    sets = {lang: set(v) for lang, v in p.variants.items()}
    if sets["ar"] != sets["en"]:
        issues.append(Issue("variants", "every Arabic variant needs its English localization (and only those)"))
    allowed = set(ctx.unit_tracks)
    required = {"explorer"} if "explorer" in allowed else allowed
    if not sets["ar"] <= allowed:
        issues.append(Issue("variants", f"variants {sorted(sets['ar'] - allowed)} are not tracks of this unit"))
    if not required <= sets["ar"]:
        issues.append(Issue("variants", f"missing required variant(s) {sorted(required - sets['ar'])}; an "
                                        "Explorer is never served a New Muslim variant"))
    for lang, variant in p.variant_keys():
        if len(p.variants[lang][variant].objectives) != len(p.plan.objectives):
            issues.append(Issue("variants", "objectives must restate the plan's objectives", f"{lang}/{variant}"))
    return issues


def _skeleton(p: LessonPackage, ctx: Context) -> list[Issue]:
    keys = p.variant_keys()
    if not keys:
        return []
    reference_key = keys[0]
    reference = p.variants[reference_key[0]][reference_key[1]].skeleton()
    return [Issue("skeleton", "variants must share one block skeleton (ids, types, order, exercise blocks)",
                  f"{lang}/{variant}")
            for lang, variant in keys[1:] if p.variants[lang][variant].skeleton() != reference]


def _sentence_skeleton(content: VariantContent) -> list[tuple[str, list[str]]]:
    return [(b["block_id"], [s["sentence_id"] for s in sentences_of(b)]) for b in content.blocks]


def _localization_parity(p: LessonPackage, ctx: Context) -> list[Issue]:
    issues = []
    for variant in sorted(set(p.variants.get("ar", {})) & set(p.variants.get("en", {}))):
        ar, en = p.variants["ar"][variant], p.variants["en"][variant]
        if _sentence_skeleton(ar) != _sentence_skeleton(en):
            issues.append(Issue("localization", "the English localization keeps every sentence id in place",
                                f"en/{variant}"))
    return issues


# --------------------------------------------------------------------------------- sentences/claims

def _sentence_roles(p: LessonPackage, ctx: Context) -> list[Issue]:
    issues = []
    roles = {}
    for row in p.sentence_map:
        if row.sentence_id in roles:
            issues.append(Issue("sentence_roles", "sentence appears twice in the sentence map", row.sentence_id))
        roles[row.sentence_id] = row
    used: set[str] = set()
    for lang, variant in p.variant_keys():
        for block in p.variants[lang][variant].blocks:
            for sentence in sentences_of(block):
                used.add(sentence["sentence_id"])
    for sentence_id in sorted(used - roles.keys()):
        issues.append(Issue("sentence_roles", "every sentence needs a role (claim/framing/hypothetical/"
                                              "instruction/question)", sentence_id))
    for sentence_id in sorted(roles.keys() - used):
        issues.append(Issue("sentence_roles", "sentence map names a sentence that no variant contains", sentence_id))
    supported = {c.claim_id for c in p.claims if c.status == "supported"}
    for row in roles.values():
        for claim_id in row.claim_ids:
            if claim_id not in supported:
                issues.append(Issue("unsupported_sentence", f"links {claim_id}, which is not a supported claim",
                                    row.sentence_id))
    return issues


def _claims(p: LessonPackage, ctx: Context) -> list[Issue]:
    issues = []
    ids = Counter(c.claim_id for c in p.claims)
    issues += [Issue("claims", "duplicate claim id", cid) for cid, n in ids.items() if n > 1]
    tools = {use.tool for use in p.plan.reasoning_tools}
    for claim in p.claims:
        if claim.reasoning is not None and claim.reasoning.tool not in tools:
            issues.append(Issue("claims", f"reasoning tool {claim.reasoning.tool} is not in the approved plan",
                                claim.claim_id))
    return issues


# ------------------------------------------------------------------------------------------ arc map

def _arc_map(p: LessonPackage, ctx: Context) -> list[Issue]:
    issues = []
    steps = p.plan.lesson_arc.steps
    plan_ids = [s.step_id for s in steps]
    map_ids = [row.step_id for row in p.arc_map]
    if map_ids != plan_ids:
        missing = [s for s in plan_ids if s not in map_ids]
        unknown = [s for s in map_ids if s not in plan_ids]
        detail = f"missing {missing}" if missing else (f"unknown {unknown}" if unknown else "out of arc order")
        issues.append(Issue("arc_map", f"arc_map must list every approved arc step once, in order ({detail})"))
    keys = p.variant_keys()
    if not keys:
        return issues
    blocks = {b["block_id"]: (i, b) for i, b in enumerate(p.variants[keys[0][0]][keys[0][1]].blocks)}
    technique = {s.step_id: s.technique for s in steps}
    seen: set[str] = set()
    last_position = -1
    for row in p.arc_map:
        for block_id in row.block_ids:
            if block_id not in blocks:
                issues.append(Issue("arc_map", "names an unknown block", f"{row.step_id}/{block_id}"))
                continue
            if block_id in seen:
                issues.append(Issue("arc_map", "a block realises only one arc step", f"{row.step_id}/{block_id}"))
            seen.add(block_id)
            position, block = blocks[block_id]
            if position < last_position:
                issues.append(Issue("arc_map", "blocks must follow the arc order", f"{row.step_id}/{block_id}"))
            last_position = max(last_position, position)
            step_technique = technique.get(row.step_id)
            if step_technique is None:
                continue
            if block["type"] == "story" and step_technique not in STORY_TECHNIQUES:
                issues.append(Issue("composition", "a story block belongs to a story or scenario step", block_id))
            if block["type"] == "predict" and step_technique not in PREDICT_TECHNIQUES:
                issues.append(Issue("composition", "a predict block belongs to a prediction or reflection step",
                                    block_id))
            if block["type"] == "teach" and block.get("style") == "summary" and step_technique != "takeaway":
                issues.append(Issue("composition", "a summary card belongs to the takeaway step", block_id))
    summaries = [b for _, b in blocks.values() if b["type"] == "teach" and b.get("style") == "summary"]
    hooks = [b for _, b in blocks.values() if b["type"] == "hook"]
    if len(summaries) > 1:
        issues.append(Issue("composition", "a lesson has at most one summary card"))
    if len(hooks) > 1:
        issues.append(Issue("composition", "a lesson has one hook"))
    return issues


# ---------------------------------------------------------------------------------------- exercises

def _exercises(p: LessonPackage, ctx: Context) -> list[Issue]:
    issues = []
    ids = Counter(e.exercise_id for e in p.exercises)
    issues += [Issue("exercises", "duplicate exercise id", eid) for eid, n in ids.items() if n > 1]
    if not ctx.allow_timed_items:
        # API §5.7: lessons, tests and card reviews are untimed; timers belong to the serving mode (quick review
        # 20 s, challenges 15 s / 10 s), so stored lesson, pretest and unit-test items carry no time limit.
        issues += [Issue("exercises", "lesson, pretest and unit-test items are untimed (time_limit_ms null)",
                         e.exercise_id) for e in p.exercises
                   if e.purpose in ("lesson", "pretest", "unit_test") and e.exercise["ar"].time_limit_ms is not None]
    keys = p.variant_keys()
    placed = p.variants[keys[0][0]][keys[0][1]].exercise_ids() if keys else []
    for exercise_id in placed:
        record = p.exercise(exercise_id)
        if record is None:
            issues.append(Issue("exercises", "exercise block names an unknown exercise", exercise_id))
        elif record.purpose != "lesson":
            issues.append(Issue("exercises", "only lesson exercises are placed in the lesson", exercise_id))
    graded = sum(1 for eid in placed if (r := p.exercise(eid)) is not None and r.scored)
    low, high = GRADED_BOUNDS
    if not low <= graded <= high:
        issues.append(Issue("exercises", f"a lesson has {low}-{high} graded exercises (found {graded})"))
    introduced = set(p.plan.introduced_concept_ids)
    flashcard_concepts = {c for e in p.exercises if e.type == "flashcard" for c in e.concept_ids}
    for concept_id in sorted(introduced - flashcard_concepts):
        issues.append(Issue("exercises", "every concept the lesson teaches has at least one flashcard", concept_id))
    for record in p.exercises:
        issues += _exercise_record(record)
    return issues


def _exercise_record(record: Any) -> list[Issue]:
    issues = []
    eid, typ = record.exercise_id, record.type
    if record.purpose in ("pretest", "unit_test", "duel") and typ in NON_ASSESSMENT_TYPES:
        issues.append(Issue("exercises", f"{typ} is excluded from pretests, unit tests and duels", eid))
    if record.purpose == "duel" and typ not in DUEL_TYPES:
        issues.append(Issue("exercises", f"duel items are {', '.join(DUEL_TYPES)}", eid))
    if typ == "true_false" and record.purpose != "duel":
        issues.append(Issue("exercises", "true_false is challenge-only", eid))
    for lang in LANGS:
        exercise = record.exercise[lang]
        if exercise.answer_key is not None:
            try:
                contextual.validate_answer(exercise.model_dump(mode="json"),
                                           exercise.answer_key.model_dump(mode="json"), special=False)
            except ValueError as exc:
                issues.append(Issue("answer_key", f"key is not a complete answer for the served payload: {exc}",
                                    f"{eid}/{lang}"))
            else:
                issues += _answer_order(exercise, f"{eid}/{lang}")
        issues += _feedback(record, lang)
        if exercise.framing is not None and record.targets_misconception_id is None:
            issues.append(Issue("exercises", "a myth-framed item targets the misconception it corrects", eid))
    return issues


def _answer_order(exercise: Any, location: str) -> list[Issue]:
    """The public order of a bank must not spell out the private answer (decision D-42).

    Banks may be authored or captured (factory §13.3) and are served exactly as stored, so an order that equals
    the key would hand the learner the answer: steps/events in key order, a right column aligned with its left
    items, or a word bank that starts with the blanks' words in blank order. Single-item banks are exempt.
    """
    payload, key, typ = exercise.payload, exercise.answer_key.model_dump(mode="json"), exercise.type
    reveals = False
    if typ in ("order_steps", "timeline_order"):
        field, ident = ("steps", "step_id") if typ == "order_steps" else ("events", "event_id")
        served = [x[ident] for x in payload[field]]
        reveals = len(served) > 1 and served == key["order"]
    elif typ == "match_pairs":
        pairs = {p["left_id"]: p["right_id"] for p in key["pairs"]}
        aligned = [pairs[x["item_id"]] for x in payload["left"]]
        reveals = len(pairs) > 1 and aligned == [x["item_id"] for x in payload["right"]]
    elif typ == "fill_blank":
        blanks = [x["blank_id"] for x in payload["segments"] if x["type"] == "blank"]
        fills = {f["blank_id"]: f["word_id"] for f in key["fills"]}
        bank = [x["word_id"] for x in payload["word_bank"]]
        reveals = len(blanks) > 1 and bank[:len(blanks)] == [fills[b] for b in blanks]
    if reveals:
        return [Issue("exposure", f"the served {typ} order equals the answer key; author or capture a "
                                  "non-revealing order", location)]
    return []


def _feedback(record: Any, lang: str) -> list[Issue]:
    exercise, feedback = record.exercise[lang], record.feedback[lang]
    payload, eid = exercise.payload, record.exercise_id
    expected: dict[str, set[str]] = {
        "option_feedback": ({o["option_id"] for o in payload.get("options", [])}
                            if exercise.type == "scenario" else set()),
        "event_dates": ({e["event_id"] for e in payload.get("events", [])}
                        if exercise.type == "timeline_order" else set()),
        "pin_labels": {p["pin_id"] for p in payload.get("pins", [])} if exercise.type == "map_place" else set(),
    }
    id_field = {"option_feedback": "option_id", "event_dates": "event_id", "pin_labels": "pin_id"}
    issues = []
    for name, ids in expected.items():
        got = [getattr(row, id_field[name]) for row in getattr(feedback, name)]
        if sorted(got) != sorted(ids):
            issues.append(Issue("exercises", f"{name} must cover exactly the served ids", f"{eid}/{lang}"))
    return issues


def _assessment_items(p: LessonPackage, ctx: Context) -> list[Issue]:
    counts: Counter[str] = Counter(e.purpose for e in p.exercises)
    issues = []
    for purpose, expected in (("pretest", PRETEST_PER_LESSON), ("unit_test", UNIT_TEST_PER_LESSON),
                              ("duel", DUEL_PER_LESSON)):
        if counts.get(purpose, 0) != expected:
            issues.append(Issue("assessment", f"each lesson contributes {expected} {purpose} item(s) "
                                              f"(found {counts.get(purpose, 0)})"))
    return issues


# ----------------------------------------------------------------------------- sources, terms, media

def _sources(p: LessonPackage, ctx: Context) -> list[Issue]:
    issues = []
    available = {s.source_id for s in p.sources} | ctx.known_sources
    ids = Counter(s.source_id for s in p.sources)
    issues += [Issue("sources", "duplicate source id", sid) for sid, n in ids.items() if n > 1]
    referenced: set[str] = set(referenced_source_ids([v.model_dump(mode="json") for lv in p.variants.values()
                                                      for v in lv.values()]))
    for record in p.exercises:
        referenced |= set(record.source_ids) | set(referenced_source_ids(
            [e.model_dump(mode="json") for e in record.exercise.values()]))
    for claim in p.claims:
        referenced |= {e.source.source_id for e in claim.evidence}
    referenced |= {s for m in p.misconceptions for s in m.source_ids}
    referenced |= {t.source_id for t in p.glossary if t.source_id}
    for source_id in sorted(referenced - available):
        issues.append(Issue("sources", "references a source that is not in the package or the source registry",
                            source_id))
    for lang, variant in p.variant_keys():
        items = resolve_items(p, lang, variant) if not issues else []
        roles = display_roles(items)
        content = [s for s, role in roles.items() if role == "content"]
        if len(content) > MAX_CONTENT_SOURCES:
            issues.append(Issue("validation", f"at most {MAX_CONTENT_SOURCES} displayed content sources "
                                              f"(found {len(content)})", f"{lang}/{variant}"))
    return issues


def _terms(p: LessonPackage, ctx: Context) -> list[Issue]:
    issues = []
    glossary = Counter(t.term_id for t in p.glossary)
    issues += [Issue("terms", "duplicate glossary term", tid) for tid, n in glossary.items() if n > 1]
    available = set(glossary) | ctx.known_terms
    used = set(term_ids([v.model_dump(mode="json") for lv in p.variants.values() for v in lv.values()]))
    used |= set(term_ids([e.model_dump(mode="json") for r in p.exercises for e in r.exercise.values()]))
    issues += [Issue("terms", "term span names a term without a glossary record", tid)
               for tid in sorted(used - available)]
    for term in p.glossary:
        if term.lesson_id not in (None, p.lesson_id):
            issues.append(Issue("terms", "a new term is introduced by this lesson", term.term_id))
    return issues


def _completion(p: LessonPackage, ctx: Context) -> list[Issue]:
    concepts = set(p.plan.introduced_concept_ids) | set(p.plan.prerequisite_concept_ids) | ctx.known_concepts
    issues = []
    for lang, variant in p.variant_keys():
        completion = p.variants[lang][variant].completion
        for topic in completion.review_topics if completion else []:
            for concept_id in topic.concept_ids:
                if concept_id not in concepts:
                    issues.append(Issue("completion", "review topic names a concept this lesson neither teaches "
                                                      "nor requires", f"{lang}/{variant}/{topic.topic_id}"))
    return issues


def _misconceptions(p: LessonPackage, ctx: Context) -> list[Issue]:
    available = {m.misconception_id for m in p.misconceptions} | ctx.known_misconceptions
    issues = []
    for record in p.exercises:
        mapped = set(record.exercise["ar"].option_misconceptions.values())
        if record.targets_misconception_id:
            mapped.add(record.targets_misconception_id)
        issues += [Issue("misconceptions", "maps a misconception without a card", f"{record.exercise_id}/{m}")
                   for m in sorted(mapped - available)]
    return issues


def _media(p: LessonPackage, ctx: Context) -> list[Issue]:
    if ctx.allow_placeholder_media:
        return []
    errors = contextual.placeholder_media_errors(p.model_dump(mode="json"))
    return [Issue("validation", error) for error in errors]
