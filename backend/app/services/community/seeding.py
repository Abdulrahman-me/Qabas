"""Seeded community configuration: league tiers and achievement definitions from ``content/registries.json``.

The migration inserts the registry snapshot of its revision; ``scripts/seed.py`` keeps the tables equal to the
manifest afterwards (names, zone sizes, titles, targets). Keys are contract identities: a key that disappeared
from the manifest is refused rather than deleted (learner rows reference it), and adding or removing one is a
contract update (API §6.2 ``GET /me/achievements``).
"""

from __future__ import annotations

from typing import Any

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import AchievementDefinition, LeagueTier
from app.registries import registries


class RegistryDrift(Exception):
    pass


def tier_rows() -> list[dict[str, Any]]:
    return [{"tier_key": t["tier_key"], "index": t["index"], "name": t["name"],
             "promotion_zone_size": t["promotion_zone_size"], "is_top_tier": t["is_top_tier"]}
            for t in registries()["league_tiers"]["tiers"]]


def achievement_rows() -> list[dict[str, Any]]:
    return [{"achievement_key": a["achievement_key"], "position": i, "title": a["title"],
             "description": a["description"], "counter": a["counter"], "target": a["target"]}
            for i, a in enumerate(registries()["achievements"]["items"])]


async def sync_registries(db: AsyncSession) -> dict[str, int]:
    """Upsert both tables from the manifest; returns the number of rows changed."""
    changed = {}
    for model, key, rows in ((LeagueTier, "tier_key", tier_rows()), (AchievementDefinition, "achievement_key",
                                                                      achievement_rows())):
        stored = {getattr(r, key): r for r in (await db.execute(select(model))).scalars()}
        missing = set(stored) - {row[key] for row in rows}
        if missing:
            raise RegistryDrift(f"{model.__tablename__}: {sorted(missing)} are no longer in registries.json")
        count = 0
        for row in rows:
            current = stored.get(row[key])
            if current is not None and all(getattr(current, k) == v for k, v in row.items()):
                continue
            statement = insert(model).values(**row)
            await db.execute(statement.on_conflict_do_update(
                index_elements=[getattr(model, key)], set_={k: v for k, v in row.items() if k != key}))
            count += 1
        changed[model.__tablename__] = count
    await db.flush()
    return changed
