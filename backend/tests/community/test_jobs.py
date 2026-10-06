"""Community beat jobs: week-end promotion at Sunday 00:00 Asia/Riyadh plus hourly catch-up, the synthetic
member job and the challenge expiry/forfeit sweep, on the maintenance queue."""

from __future__ import annotations

from datetime import UTC, datetime

from app.services.community import leagues
from app.workers import tasks_community
from app.workers.celery_app import celery_app


def test_community_jobs_are_scheduled_on_the_maintenance_queue() -> None:
    schedule = celery_app.conf.beat_schedule
    week_end = schedule["league-promotion-week-end"]
    assert week_end["task"] == "community.promote_leagues"
    cron = week_end["schedule"]
    # Saturday 21:00 UTC is Sunday 00:00 Asia/Riyadh, the start of a league week.
    assert cron.hour == {21} and cron.minute == {0} and cron.day_of_week == {6}
    assert leagues.week_start(datetime(2026, 10, 10, 21, 0, tzinfo=UTC)) == datetime(2026, 10, 10, 21, 0, tzinfo=UTC)
    assert schedule["league-promotion-catch-up"]["schedule"] == 3600.0
    assert schedule["synthetic-league-members"]["task"] == "community.synthetic_leagues"
    router = celery_app.amqp.router
    assert schedule["challenge-expiry"]["task"] == "community.sweep_challenges"
    assert schedule["challenge-expiry"]["schedule"] <= 5                    # lobbies close at 60 s, duels at 2 min
    for name in ("community.promote_leagues", "community.synthetic_leagues", "community.sweep_challenges"):
        assert name in celery_app.tasks
        assert router.route({}, name)["queue"].name == "maintenance"
    assert tasks_community.CONSUMER_MODULES
