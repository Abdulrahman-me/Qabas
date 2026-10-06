"""The practice bot ("المدرّب" / "Coach", backend §11.3).

Per question the bot is correct with probability 0.7 and answers after a log-normal time with median 6 s, clamped
to [1.5 s, 14 s]. Both are drawn from a PRNG seeded by (duel, question, bot), so a coordinator takeover or a replay
reproduces exactly the same behaviour (§11.2). A wrong answer is a deterministic wrong choice among the served
options; the bot never answers faster or better because it sees the key.

Bots are users with ``is_bot`` (never synthetic, never in leagues, friends or metrics); several exist so that
``bot_fill`` can seat up to three in one group challenge.
"""

from __future__ import annotations

import hashlib
import math
import random
from dataclasses import dataclass
from typing import Any

from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User

ACCURACY = 0.7
MEDIAN_MS = 6000
SIGMA = 0.5             # spread of the log-normal response time (not specified; recorded decision)
MIN_MS, MAX_MS = 1500, 14000
BOT_IDS = ("usr_bot_coach_1", "usr_bot_coach_2", "usr_bot_coach_3")
NAME = {"ar": "المدرّب", "en": "Coach"}
AVATAR = "traveler_bot"


@dataclass(frozen=True)
class BotAnswer:
    answer: dict[str, Any]
    correct: bool
    elapsed_ms: int


def _rng(duel_id: str, question_index: int, bot_id: str) -> random.Random:
    seed = hashlib.sha256(f"qabas-bot:{duel_id}:{question_index}:{bot_id}".encode()).digest()
    return random.Random(int.from_bytes(seed[:16], "big"))  # noqa: S311 (reproducible simulation, not secrecy)


def answer(duel_id: str, question_index: int, bot_id: str, exercise: dict[str, Any],
           key: dict[str, Any]) -> BotAnswer:
    """The bot's answer to a closed question (multiple choice, verse meaning or true/false)."""
    rng = _rng(duel_id, question_index, bot_id)
    correct = rng.random() < ACCURACY
    elapsed = int(min(MAX_MS, max(MIN_MS, math.exp(math.log(MEDIAN_MS) + SIGMA * rng.gauss(0.0, 1.0)))))
    if correct:
        return BotAnswer(dict(key), True, elapsed)
    if "value" in key:
        return BotAnswer({"value": not key["value"]}, False, elapsed)
    wrong = sorted(o["option_id"] for o in exercise["payload"]["options"] if o["option_id"] != key["option_id"])
    return BotAnswer({"option_id": rng.choice(wrong)}, False, elapsed)


async def ensure_bots(db: AsyncSession) -> None:
    """Create the bot users if missing (seed and first use; idempotent)."""
    for bot_id in BOT_IDS:
        await db.execute(insert(User).values(
            id=bot_id, display_name=NAME["en"], avatar_key=AVATAR, role="learner", language="en", track="explorer",
            daily_goal_minutes=10, timezone="UTC", onboarding_completed=True, private_profile=True, is_bot=True,
        ).on_conflict_do_nothing(index_elements=[User.id]))
