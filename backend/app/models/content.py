"""Curriculum and versioned content (data model §4.2).

Published rows of ``lesson_versions``, ``exercise_versions``, ``scene_versions`` (and their child
claims, sentences and scene assets) are immutable; triggers in the migration enforce it for every
database role (AD-07). ``lessons.current_version`` / ``exercises.current_version`` may only point
at a published version.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    PrimaryKeyConstraint,
    SmallInteger,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy import (
    text as sql_text,
)
from sqlalchemy.dialects.postgresql import ARRAY, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import enums
from app.db.base import SHA256_HEX, Base, Timestamps, enum_check, id_check, sql_list

TextArray = ARRAY(Text)
EMPTY_ARRAY = sql_text("'{}'::text[]")


class Unit(Timestamps, Base):
    __tablename__ = "units"
    __table_args__ = (
        id_check("id", "unit"),
        CheckConstraint("index >= 0", name="index_non_negative"),
        CheckConstraint(f"cardinality(tracks) >= 1 AND tracks <@ ARRAY[{sql_list(enums.TRACK)}]::text[]",
                        name="tracks_valid"),
        CheckConstraint("pass_percent BETWEEN 1 AND 100", name="pass_percent_range"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    index: Mapped[int] = mapped_column(Integer, unique=True)  # curriculum position; never gates access
    title: Mapped[dict[str, Any]]      # {lang: {track: text}}; Explorer-only units have only `explorer`
    subtitle: Mapped[dict[str, Any]]
    art_key: Mapped[str | None] = mapped_column(Text)
    guide: Mapped[dict[str, Any] | None]
    tracks: Mapped[list[str]] = mapped_column(TextArray)
    coming_soon: Mapped[bool] = mapped_column(Boolean, server_default="true")
    pass_percent: Mapped[int] = mapped_column(SmallInteger, server_default="80")


class Concept(Timestamps, Base):
    __tablename__ = "concepts"
    __table_args__ = (id_check("id", "con"), Index("ix_concepts_unit_id", "unit_id"))

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    unit_id: Mapped[str] = mapped_column(ForeignKey("units.id"))
    title: Mapped[dict[str, Any]]
    # Curriculum concept graph for the Curriculum Architect; never read for access (AD-29).
    prerequisite_ids: Mapped[list[str]] = mapped_column(TextArray, server_default=EMPTY_ARRAY)
    # Set once, at publication of the single lesson that introduces the concept (trigger-enforced).
    introduced_by_lesson_id: Mapped[str | None] = mapped_column(
        ForeignKey("lessons.id", use_alter=True, name="fk_concepts_introduced_by_lesson_id_lessons"))


class Source(Timestamps, Base):
    __tablename__ = "sources"
    __table_args__ = (
        id_check("id", "src"),
        enum_check("kind", enums.SOURCE_KIND),
        enum_check("provider", enums.SOURCE_PROVIDER),
        CheckConstraint(f"text_sha256 IS NULL OR text_sha256 ~ '{SHA256_HEX}'", name="text_sha256_format"),
        Index("uq_sources_provider_record", "provider", "provider_record_id", unique=True,
              postgresql_where=sql_text("provider_record_id IS NOT NULL")),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    kind: Mapped[str] = mapped_column(Text)
    provider: Mapped[str] = mapped_column(Text)
    provider_record_id: Mapped[str | None] = mapped_column(Text)
    title: Mapped[str] = mapped_column(Text)
    reference: Mapped[str] = mapped_column(Text)
    excerpt: Mapped[str] = mapped_column(Text)
    url: Mapped[str | None] = mapped_column(Text)
    raw: Mapped[dict[str, Any]] = mapped_column(server_default=sql_text("'{}'::jsonb"))
    text_sha256: Mapped[str | None] = mapped_column(Text)  # digest of the exact cited text (sources §12)
    retrieved_at: Mapped[datetime | None]
    adapter_version: Mapped[str | None] = mapped_column(Text)


class CurriculumSlot(Timestamps, Base):
    """A curriculum position (unit, 0-based index) and the canonical lesson ID that fills it (curriculum
    document; ``content/curriculum.yaml``). Authoring metadata only: nothing here is learner-facing until a
    lesson version for the slot is published. A lesson can exist only in a declared slot (composite FK)."""

    __tablename__ = "curriculum_slots"
    __table_args__ = (
        id_check("lesson_id", "les"),
        CheckConstraint("index >= 0", name="index_non_negative"),
        UniqueConstraint("unit_id", "index", name="uq_curriculum_slots_unit_id_index"),
        UniqueConstraint("lesson_id", "unit_id", "index", name="uq_curriculum_slots_position"),
    )

    lesson_id: Mapped[str] = mapped_column(Text, primary_key=True)
    unit_id: Mapped[str] = mapped_column(ForeignKey("units.id"))
    index: Mapped[int] = mapped_column(Integer)          # 0-based position in the unit (wire JLesson.index)
    working_title: Mapped[dict[str, Any]]                # {en, ar?}: curriculum working title, not learner copy
    focus: Mapped[dict[str, Any] | None]                 # curriculum focus note for the Curriculum Architect


class Lesson(Timestamps, Base):
    """One canonical lesson per curriculum slot, shared by both tracks (AD-28, AD-34)."""

    __tablename__ = "lessons"
    __table_args__ = (
        id_check("id", "les"),
        UniqueConstraint("unit_id", "index", name="uq_lessons_unit_id_index"),
        CheckConstraint("index >= 0", name="index_non_negative"),
        ForeignKeyConstraint(["id", "unit_id", "index"],
                             ["curriculum_slots.lesson_id", "curriculum_slots.unit_id", "curriculum_slots.index"],
                             name="fk_lessons_curriculum_slot"),
        enum_check("lesson_type", enums.LESSON_TYPE),
        CheckConstraint("estimated_minutes > 0", name="estimated_minutes_positive"),
        CheckConstraint("xp >= 0", name="xp_non_negative"),
        # Standalone (Discover) lessons have no prerequisites (backend §6.1).
        CheckConstraint("NOT standalone_eligible OR cardinality(prerequisite_concept_ids) = 0",
                        name="standalone_without_prerequisites"),
        CheckConstraint(f"variants <@ ARRAY[{sql_list(enums.VARIANT)}]::text[]", name="variants_valid"),
        ForeignKeyConstraint(["id", "current_version"], ["lesson_versions.lesson_id", "lesson_versions.version"],
                             name="fk_lessons_current_version_lesson_versions", use_alter=True),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    unit_id: Mapped[str] = mapped_column(ForeignKey("units.id"))
    index: Mapped[int] = mapped_column(Integer)  # 0-based curriculum position within the unit; never a prerequisite
    lesson_type: Mapped[str] = mapped_column(Text)
    estimated_minutes: Mapped[int] = mapped_column(SmallInteger)
    xp: Mapped[int] = mapped_column(SmallInteger, server_default="10")
    current_version: Mapped[int | None] = mapped_column(Integer)
    is_gold: Mapped[bool] = mapped_column(Boolean, server_default="false")
    # Denormalized from the current published version (curr).
    prerequisite_concept_ids: Mapped[list[str]] = mapped_column(TextArray, server_default=EMPTY_ARRAY)
    introduced_concept_ids: Mapped[list[str]] = mapped_column(TextArray, server_default=EMPTY_ARRAY)
    standalone_eligible: Mapped[bool] = mapped_column(Boolean, server_default="false")
    variants: Mapped[list[str]] = mapped_column(TextArray, server_default=EMPTY_ARRAY)


class LessonVersion(Base):
    __tablename__ = "lesson_versions"
    __table_args__ = (
        UniqueConstraint("lesson_id", "version", name="uq_lesson_versions_lesson_id_version"),
        CheckConstraint("version >= 1", name="version_positive"),
        CheckConstraint(f"content_sha256 ~ '{SHA256_HEX}'", name="content_sha256_format"),
        CheckConstraint("contract_revision >= 10", name="contract_revision_supported"),
        enum_check("origin", enums.CONTENT_ORIGIN),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, server_default=func.gen_random_uuid())
    lesson_id: Mapped[str] = mapped_column(ForeignKey("lessons.id"))
    version: Mapped[int] = mapped_column(Integer)
    reviewed_by: Mapped[str | None] = mapped_column(Text)  # reviewer display name shown to learners
    published_at: Mapped[datetime | None]
    run_id: Mapped[str | None] = mapped_column(ForeignKey("factory_runs.id"))
    # factory | gold_import | test_fixture. Test-fixture content is publishable only outside staging and
    # production (app-enforced, D-29) and exists to exercise the real pipeline in automated tests.
    origin: Mapped[str] = mapped_column(Text)
    plan: Mapped[dict[str, Any]]          # approved LessonPlan
    arc_map: Mapped[dict[str, Any] | None]
    content: Mapped[dict[str, Any]]       # {lang: {variant: {title, subtitle, objectives, blocks, completion, ...}}}
    content_sha256: Mapped[str] = mapped_column(Text)
    contract_revision: Mapped[int] = mapped_column(SmallInteger)
    scene_schema: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class Claim(Base):
    __tablename__ = "claims"
    __table_args__ = (
        PrimaryKeyConstraint("lesson_version_id", "id", name="pk_claims"),
        # Claim and sentence ids are authored per lesson version; the contract fixtures use ids such as
        # "s1"/"c1", so no prefix is enforced here (decision D-33).
        enum_check("status", enums.CLAIM_STATUS),
        enum_check("basis", enums.CLAIM_BASIS),
        CheckConstraint("basis = 'reasoning' OR reasoning IS NULL", name="reasoning_only_for_reasoning_basis"),
    )

    lesson_version_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("lesson_versions.id", ondelete="CASCADE"))
    id: Mapped[str] = mapped_column(Text)
    text: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text)
    basis: Mapped[str] = mapped_column(Text)
    evidence: Mapped[list[Any]] = mapped_column(server_default=sql_text("'[]'::jsonb"))
    reasoning: Mapped[dict[str, Any] | None]


class SentenceRecord(Base):
    """Sentence roles and claim links; IDs are shared by the Arabic and English variants (AD-31, AD-32)."""

    __tablename__ = "sentences"
    __table_args__ = (
        PrimaryKeyConstraint("lesson_version_id", "lang", "variant", "id", name="pk_sentences"),
        enum_check("lang", enums.LANGUAGE),
        enum_check("variant", enums.VARIANT),
        enum_check("role", enums.SENTENCE_ROLE),
        CheckConstraint("(role = 'claim') = (cardinality(claim_ids) > 0)", name="claim_links_match_role"),
    )

    lesson_version_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("lesson_versions.id", ondelete="CASCADE"))
    lang: Mapped[str] = mapped_column(Text)
    variant: Mapped[str] = mapped_column(Text)
    id: Mapped[str] = mapped_column(Text)
    role: Mapped[str] = mapped_column(Text)
    claim_ids: Mapped[list[str]] = mapped_column(TextArray, server_default=EMPTY_ARRAY)
    edited_by_reviewer: Mapped[bool] = mapped_column(Boolean, server_default="false")


class Term(Timestamps, Base):
    __tablename__ = "terms"
    __table_args__ = (id_check("id", "term"), Index("ix_terms_concept_id", "concept_id"))

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    text: Mapped[dict[str, Any]]                    # {ar, en} localized headings
    arabic: Mapped[str | None] = mapped_column(Text)  # canonical Arabic display, independent of the heading
    transliteration: Mapped[str | None] = mapped_column(Text)
    concept_id: Mapped[str | None] = mapped_column(ForeignKey("concepts.id"))
    lesson_id: Mapped[str | None] = mapped_column(ForeignKey("lessons.id"))
    source_id: Mapped[str | None] = mapped_column(ForeignKey("sources.id"))
    pronunciation_audio_url: Mapped[str | None] = mapped_column(Text)
    definition: Mapped[dict[str, Any]]              # {basic: {ar, en}, intermediate: {ar, en} | null}
    example: Mapped[dict[str, Any]]


class Misconception(Timestamps, Base):
    __tablename__ = "misconceptions"
    __table_args__ = (id_check("id", "mis"),)

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    unit_id: Mapped[str] = mapped_column(ForeignKey("units.id"))
    concept_id: Mapped[str | None] = mapped_column(ForeignKey("concepts.id"))
    title: Mapped[dict[str, Any]]
    card: Mapped[dict[str, Any]]
    source_ids: Mapped[list[str]] = mapped_column(TextArray, server_default=EMPTY_ARRAY)


class Exercise(Timestamps, Base):
    __tablename__ = "exercises"
    __table_args__ = (
        id_check("id", "ex"),
        enum_check("purpose", enums.EXERCISE_PURPOSE),
        enum_check("type", enums.EXERCISE_TYPE),
        CheckConstraint("purpose <> 'lesson' OR lesson_id IS NOT NULL", name="lesson_exercise_has_lesson"),
        CheckConstraint(f"purpose = 'lesson' OR type NOT IN ({sql_list(enums.ASSESSMENT_EXCLUDED_TYPES)})",
                        name="assessment_type_allowed"),
        CheckConstraint(f"purpose <> 'duel' OR type IN ({sql_list(enums.DUEL_TYPES)})", name="duel_type_allowed"),
        CheckConstraint(f"type NOT IN ({sql_list(enums.DUEL_ONLY_TYPES)}) OR purpose = 'duel'",
                        name="duel_only_type"),
        Index("ix_exercises_unit_id_purpose", "unit_id", "purpose"),
        Index("ix_exercises_lesson_id", "lesson_id"),
        ForeignKeyConstraint(["id", "current_version"], ["exercise_versions.exercise_id", "exercise_versions.version"],
                             name="fk_exercises_current_version_exercise_versions", use_alter=True),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    lesson_id: Mapped[str | None] = mapped_column(ForeignKey("lessons.id"))
    unit_id: Mapped[str] = mapped_column(ForeignKey("units.id"))
    purpose: Mapped[str] = mapped_column(Text)
    type: Mapped[str] = mapped_column(Text)  # identity: translations keep the same id and type
    concept_ids: Mapped[list[str]] = mapped_column(TextArray, server_default=EMPTY_ARRAY)
    current_version: Mapped[int | None] = mapped_column(Integer)


class ExerciseVersion(Base):
    """Immutable once published; grading reads only from the served version (AD-07)."""

    __tablename__ = "exercise_versions"
    __table_args__ = (
        PrimaryKeyConstraint("exercise_id", "version", name="pk_exercise_versions"),
        CheckConstraint("version >= 1", name="version_positive"),
        CheckConstraint(f"content_sha256 ~ '{SHA256_HEX}'", name="content_sha256_format"),
    )

    exercise_id: Mapped[str] = mapped_column(ForeignKey("exercises.id"))
    version: Mapped[int] = mapped_column(Integer)
    content: Mapped[dict[str, Any]]                   # {ar, en}: prompt, payload, explanation, feedback, labels
    scoring: Mapped[dict[str, Any]]                   # {accuracy, combo, layer}
    framing: Mapped[dict[str, Any] | None]
    answer_key: Mapped[dict[str, Any]]                # server-side only; never in a learner payload
    option_misconceptions: Mapped[dict[str, Any]] = mapped_column(server_default=sql_text("'{}'::jsonb"))
    targets_misconception_id: Mapped[str | None] = mapped_column(ForeignKey("misconceptions.id"))
    source_ids: Mapped[list[str]] = mapped_column(TextArray, server_default=EMPTY_ARRAY)
    duel_eligible: Mapped[bool] = mapped_column(Boolean, server_default="false")
    lesson_version_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("lesson_versions.id"))
    content_sha256: Mapped[str] = mapped_column(Text)
    published_at: Mapped[datetime | None]
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class SceneVersion(Base):
    __tablename__ = "scene_versions"
    __table_args__ = (
        PrimaryKeyConstraint("scene_id", "version", name="pk_scene_versions"),
        id_check("scene_id", "scn"),
        CheckConstraint("version >= 1", name="version_positive"),
        enum_check("status", enums.SCENE_STATUS),
        CheckConstraint("(status = 'published') = (published_at IS NOT NULL)", name="published_status"),
        CheckConstraint(f"sha256 ~ '{SHA256_HEX}'", name="sha256_format"),
        CheckConstraint("bytes > 0", name="bytes_positive"),
    )

    scene_id: Mapped[str] = mapped_column(Text)
    version: Mapped[int] = mapped_column(Integer)
    manifest_url: Mapped[str] = mapped_column(Text)
    sha256: Mapped[str] = mapped_column(Text)
    bytes: Mapped[int] = mapped_column(Integer)
    view_box: Mapped[dict[str, Any]]
    states: Mapped[dict[str, Any]]
    required_capabilities: Mapped[list[str]] = mapped_column(TextArray, server_default=EMPTY_ARRAY)
    anchors: Mapped[list[Any]] = mapped_column(server_default=sql_text("'[]'::jsonb"))
    fallback_image: Mapped[dict[str, Any]]
    preview: Mapped[dict[str, Any] | None]
    audit: Mapped[dict[str, Any] | None]
    status: Mapped[str] = mapped_column(Text, server_default="draft")
    published_at: Mapped[datetime | None]
    created_by_run_id: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class SceneAsset(Base):
    __tablename__ = "scene_assets"
    __table_args__ = (
        PrimaryKeyConstraint("scene_id", "version", "asset_id", name="pk_scene_assets"),
        ForeignKeyConstraint(["scene_id", "version"], ["scene_versions.scene_id", "scene_versions.version"],
                             name="fk_scene_assets_scene_versions", ondelete="CASCADE"),
        enum_check("mime_type", enums.SCENE_ASSET_MIME),
        CheckConstraint("width > 0 AND height > 0 AND bytes > 0", name="dimensions_positive"),
        CheckConstraint(f"sha256 ~ '{SHA256_HEX}'", name="sha256_format"),
    )

    scene_id: Mapped[str] = mapped_column(Text)
    version: Mapped[int] = mapped_column(Integer)
    asset_id: Mapped[str] = mapped_column(Text)
    url: Mapped[str] = mapped_column(Text)
    mime_type: Mapped[str] = mapped_column(Text)
    width: Mapped[int] = mapped_column(Integer)
    height: Mapped[int] = mapped_column(Integer)
    bytes: Mapped[int] = mapped_column(Integer)
    sha256: Mapped[str] = mapped_column(Text)
