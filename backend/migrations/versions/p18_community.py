"""Leagues, friends and achievements (Phase 18; data model ``leagues`` ... ``friend_invites``).

``league_tiers`` and ``achievements`` are seeded configuration. This revision inserts the frozen registry
snapshot (``content/registries.json`` at this revision; ``scripts/seed.py`` keeps them in sync afterwards), so a
fresh schema is usable before any seed runs. Weekly XP is not stored: standings are derived from ``xp_events``.

Revision ID: p18_community (provisional; renumbered after the Phase 16/17 migrations are integrated)
Revises: 0009
"""
from __future__ import annotations

import json
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "p18_community"
down_revision: str | None = "0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

TIERS = [
    ("tier_lantern", 0, {"en": "Lantern League", "ar": "دوري القنديل"}, 5, False),
    ("tier_beacon", 1, {"en": "Beacon League", "ar": "دوري المنارة"}, 5, False),
    ("tier_star", 2, {"en": "Star League", "ar": "دوري النجمة"}, 5, False),
    ("tier_dawn", 3, {"en": "Dawn League", "ar": "دوري الفجر"}, 5, True),
]
ACHIEVEMENTS = [
    ("firstStep", {"en": "First step", "ar": "الخطوة الأولى"},
     {"en": "Complete your first lesson", "ar": "أكمل درسك الأول"}, "lessons_completed", 1),
    ("kindled", {"en": "Kindled", "ar": "أول شعلة"},
     {"en": "Learn 3 days in a row", "ar": "تعلّم ٣ أيام متتالية"}, "longest_streak", 3),
    ("steadyFlame", {"en": "Steady flame", "ar": "شعلة ثابتة"},
     {"en": "Learn 7 days in a row", "ar": "تعلّم ٧ أيام متتالية"}, "longest_streak", 7),  # noqa: RUF001
    ("wordKeeper", {"en": "Word keeper", "ar": "حافظ الكلمات"},
     {"en": "Master 10 words", "ar": "أتقن ١٠ كلمات"}, "terms_mastered", 10),  # noqa: RUF001
    ("clearSight", {"en": "Clear sight", "ar": "رؤية واضحة"},
     {"en": "Correct 5 misconceptions", "ar": "صحّح ٥ مفاهيم خاطئة"}, "misconceptions_resolved", 5),  # noqa: RUF001
    ("unitComplete", {"en": "Unit complete", "ar": "أتممت وحدة"},
     {"en": "Finish every step of a unit", "ar": "أكمل كل خطوات وحدة"}, "units_completed", 1),
    ("seeker", {"en": "Seeker", "ar": "الباحث"},
     {"en": "Ask Raqeeb 5 questions", "ar": "اسأل رقيب ٥ أسئلة"}, "raqeeb_questions", 5),  # noqa: RUF001
    ("quickLight", {"en": "Quick light", "ar": "الأسرع"},
     {"en": "Win a live challenge with friends", "ar": "فُز في تحدٍّ مباشر مع أصدقائك"}, "challenges_won", 1),
]
COUNTERS = ("raqeeb_questions", "lessons_completed", "units_completed", "longest_streak", "terms_mastered",
            "misconceptions_resolved", "challenges_won", "recitations_passed", "reviews_completed",
            "perfect_lessons")


def _sql(value: object) -> str:
    """A constant as an SQL literal (renders in offline ``--sql`` mode, unlike typed bulk inserts)."""
    text = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False, sort_keys=True)
    return "'" + text.replace("'", "''") + "'"


def _user_fk(table: str, column: str, ondelete: str = "CASCADE") -> sa.ForeignKey:
    return sa.ForeignKey("users.id", ondelete=ondelete, name=op.f(f"fk_{table}_{column}_users"))


def upgrade() -> None:
    op.create_table(
        "league_tiers",
        sa.Column("tier_key", sa.Text(), nullable=False),
        sa.Column("index", sa.SmallInteger(), nullable=False),
        sa.Column("name", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("promotion_zone_size", sa.SmallInteger(), nullable=False),
        sa.Column("is_top_tier", sa.Boolean(), nullable=False),
        sa.CheckConstraint("index >= 0", name=op.f("ck_league_tiers_index_non_negative")),
        sa.CheckConstraint("promotion_zone_size >= 1", name=op.f("ck_league_tiers_zone_positive")),
        sa.PrimaryKeyConstraint("tier_key", name=op.f("pk_league_tiers")),
        sa.UniqueConstraint("index", name="uq_league_tiers_index"),
    )
    op.create_table(
        "leagues",
        sa.Column("id", sa.Text(), nullable=False),
        sa.Column("week_key", sa.Text(), nullable=False),
        sa.Column("tier_key", sa.Text(), sa.ForeignKey("league_tiers.tier_key",
                  name=op.f("fk_leagues_tier_key_league_tiers")), nullable=False),
        sa.Column("seq", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("id ~ '^lg_[0-9]{4}w[0-9]{2}_[0-9]+_[0-9]+$'", name=op.f("ck_leagues_id_format")),
        sa.CheckConstraint("week_key ~ '^[0-9]{4}-W[0-9]{2}$'", name=op.f("ck_leagues_week_key_format")),
        sa.CheckConstraint("seq >= 1", name=op.f("ck_leagues_seq_positive")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_leagues")),
        sa.UniqueConstraint("week_key", "tier_key", "seq", name="uq_leagues_week_key_tier_key_seq"),
        sa.UniqueConstraint("id", "week_key", name="uq_leagues_id_week_key"),
    )
    op.create_table(
        "league_members",
        sa.Column("league_id", sa.Text(), nullable=False),
        sa.Column("user_id", sa.Text(), _user_fk("league_members", "user_id"), nullable=False),
        sa.Column("week_key", sa.Text(), nullable=False),
        sa.Column("joined_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["league_id", "week_key"], ["leagues.id", "leagues.week_key"], ondelete="CASCADE",
                                name="fk_league_members_league_id_week_key_leagues"),
        sa.PrimaryKeyConstraint("league_id", "user_id", name="pk_league_members"),
        sa.UniqueConstraint("user_id", "week_key", name="uq_league_members_user_id_week_key"),
    )
    op.create_table(
        "learner_tiers",
        sa.Column("user_id", sa.Text(), _user_fk("learner_tiers", "user_id"), nullable=False),
        sa.Column("tier_key", sa.Text(), sa.ForeignKey("league_tiers.tier_key",
                  name=op.f("fk_learner_tiers_tier_key_league_tiers")), nullable=False),
        sa.Column("promoted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("promoted_week_key", sa.Text(), nullable=True),
        sa.PrimaryKeyConstraint("user_id", name=op.f("pk_learner_tiers")),
    )
    op.create_table(
        "league_promotions",
        sa.Column("week_key", sa.Text(), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("promoted", sa.Integer(), nullable=False),
        sa.CheckConstraint("promoted >= 0", name=op.f("ck_league_promotions_promoted_non_negative")),
        sa.PrimaryKeyConstraint("week_key", name=op.f("pk_league_promotions")),
    )
    op.create_table(
        "achievements",
        sa.Column("achievement_key", sa.Text(), nullable=False),
        sa.Column("position", sa.SmallInteger(), nullable=False),
        sa.Column("title", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("description", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("counter", sa.Text(), nullable=False),
        sa.Column("target", sa.Integer(), nullable=False),
        sa.CheckConstraint("counter IN (" + ", ".join(f"'{c}'" for c in COUNTERS) + ")",
                           name=op.f("ck_achievements_counter_valid")),
        sa.CheckConstraint("target >= 1", name=op.f("ck_achievements_target_positive")),
        sa.PrimaryKeyConstraint("achievement_key", name=op.f("pk_achievements")),
        sa.UniqueConstraint("position", name="uq_achievements_position"),
    )
    op.create_table(
        "learner_achievements",
        sa.Column("user_id", sa.Text(), _user_fk("learner_achievements", "user_id"), nullable=False),
        sa.Column("achievement_key", sa.Text(), sa.ForeignKey("achievements.achievement_key",
                  name=op.f("fk_learner_achievements_achievement_key_achievements")), nullable=False),
        sa.Column("progress", sa.Integer(), nullable=False),
        sa.Column("unlocked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("progress >= 0", name=op.f("ck_learner_achievements_progress_non_negative")),
        sa.PrimaryKeyConstraint("user_id", "achievement_key", name="pk_learner_achievements"),
    )
    op.create_table(
        "friendships",
        sa.Column("user_a", sa.Text(), _user_fk("friendships", "user_a"), nullable=False),
        sa.Column("user_b", sa.Text(), _user_fk("friendships", "user_b"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("user_a < user_b", name=op.f("ck_friendships_ordered_pair")),
        sa.PrimaryKeyConstraint("user_a", "user_b", name="pk_friendships"),
    )
    op.create_index("ix_friendships_user_b", "friendships", ["user_b"])
    op.create_table(
        "friend_invites",
        sa.Column("id", sa.Text(), nullable=False),
        sa.Column("code", sa.Text(), nullable=False),
        sa.Column("inviter_id", sa.Text(), _user_fk("friend_invites", "inviter_id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_by", sa.Text(), _user_fk("friend_invites", "used_by", "SET NULL"), nullable=True),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("id ~ '^inv_[0-9A-Za-z_]+$'", name=op.f("ck_friend_invites_id_format")),
        sa.CheckConstraint("code ~ '^QBS-[0-9A-HJKMNP-TV-Z]{4}$'", name=op.f("ck_friend_invites_code_format")),
        sa.CheckConstraint("expires_at > created_at", name=op.f("ck_friend_invites_expires_after_created")),
        sa.CheckConstraint("used_by IS NULL OR used_at IS NOT NULL", name=op.f("ck_friend_invites_used_by_has_time")),
        sa.CheckConstraint("used_by IS NULL OR used_by <> inviter_id", name=op.f("ck_friend_invites_not_self")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_friend_invites")),
    )
    op.create_index("ix_friend_invites_code_expires_at", "friend_invites", ["code", "expires_at"])
    op.create_index("ix_friend_invites_inviter_id", "friend_invites", ["inviter_id"])
    op.create_index("ix_friend_invites_used_by", "friend_invites", ["used_by"])

    # Constant registry snapshot rendered as literals (offline --sql mode), not user input.
    op.execute("INSERT INTO league_tiers (tier_key, index, name, promotion_zone_size, is_top_tier) VALUES "  # noqa: S608
               + ", ".join(f"({_sql(k)}, {i}, {_sql(n)}::jsonb, {z}, {str(top).lower()})" for k, i, n, z, top in TIERS))
    op.execute("INSERT INTO achievements (achievement_key, position, title, description, counter, target) VALUES "  # noqa: S608
               + ", ".join(f"({_sql(k)}, {p}, {_sql(t)}::jsonb, {_sql(d)}::jsonb, {_sql(c)}, {n})"
                           for p, (k, t, d, c, n) in enumerate(ACHIEVEMENTS)))
    op.execute("SELECT qabas_apply_grants()")


def downgrade() -> None:
    for index, table in (("ix_friend_invites_used_by", "friend_invites"),
                         ("ix_friend_invites_inviter_id", "friend_invites"),
                         ("ix_friend_invites_code_expires_at", "friend_invites"),
                         ("ix_friendships_user_b", "friendships")):
        op.drop_index(index, table_name=table)
    for table in ("friend_invites", "friendships", "learner_achievements", "achievements", "league_promotions",
                  "learner_tiers", "league_members", "leagues", "league_tiers"):
        op.drop_table(table)
