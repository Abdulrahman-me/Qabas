"""Community beat jobs (Phases 18-19): league promotion, synthetic league members and challenge expiry.

* ``community.promote_leagues`` runs at Sunday 00:00 Asia/Riyadh (Saturday 21:00 UTC; Riyadh has no DST) and
  hourly as catch-up; promotion is idempotent per ``week_key`` (``league_promotions``), and learner assignment in
  a new week also applies a pending promotion first.
* ``community.synthetic_leagues`` seats synthetic members and grants their XP (one grant per member per 30-minute
  slot); a no-op unless ``SYNTHETIC_LEAGUE_MEMBERS=true`` (P-01).

* ``community.sweep_challenges`` (every 5 s): pending invitations and group lobbies, unstarted live challenges and
  the 24 h async close (forfeits), idempotent per duel.

Importing this module (Celery ``include``) also registers the achievements subscriber of ``session.finished`` and
the ``duel.finished`` consumer.
"""

from __future__ import annotations

from celery.schedules import crontab

from app.runtime import Resources
from app.services.challenges import duels, results
from app.services.community import achievements, leagues, synthetic
from app.services.platform.auth_sessions import utcnow
from app.workers.celery_app import celery_app
from app.workers.tasks_maintenance import run_with_resources

CONSUMER_MODULES = (achievements, results)


@celery_app.task(name="community.promote_leagues")
def promote_leagues() -> dict[str, int]:
    async def job(r: Resources) -> dict[str, int]:
        async with r.sessionmaker() as db, db.begin():
            return await leagues.promote_pending(db, utcnow())

    return run_with_resources(job)


@celery_app.task(name="community.synthetic_leagues")
def synthetic_leagues() -> dict[str, int]:
    async def job(r: Resources) -> dict[str, int]:
        if not r.settings.synthetic_league_members:
            return {}
        now = utcnow()
        async with r.sessionmaker() as db, db.begin():
            seated = await synthetic.fill(db, now)
        async with r.sessionmaker() as db, db.begin():
            granted = await synthetic.grant_xp(db, now)
        return {"seated": seated, "granted": granted}

    return run_with_resources(job)


@celery_app.task(name="community.sweep_challenges")
def sweep_challenges() -> int:
    return run_with_resources(lambda r: duels.sweep(r.sessionmaker, utcnow()))


SCHEDULE = {
    "challenge-expiry": {"task": "community.sweep_challenges", "schedule": 5.0},
    "league-promotion-week-end": {"task": "community.promote_leagues",
                                  "schedule": crontab(minute=0, hour=21, day_of_week="sat")},
    "league-promotion-catch-up": {"task": "community.promote_leagues", "schedule": 3600.0},
    "synthetic-league-members": {"task": "community.synthetic_leagues", "schedule": 60.0},
}
celery_app.conf.beat_schedule.update(SCHEDULE)
