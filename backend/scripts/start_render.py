"""Run the API and reply queue on a single Render web-service instance.

For a small deployment without a separate worker service. All children inherit the
same database, Redis and provider settings. Exit if any required child exits so
Render can restart the entire service instead of leaving replies unprocessed.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys
import time
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
STOP_TIMEOUT = 15


def commands(port: str) -> list[list[str]]:
    return [
        [sys.executable, "-m", "celery", "-A", "app.workers.celery_app", "worker",
         "--pool=solo", "--concurrency=1", "-Q", "maintenance,raqeeb,embeddings", "--loglevel=INFO"],
        [sys.executable, "-m", "celery", "-A", "app.workers.celery_app", "beat",
         "--schedule=/tmp/qabas-celerybeat", "--loglevel=INFO"],
        # Render's proxy requires the API to bind to all interfaces.
        [sys.executable, "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", port],  # noqa: S104
    ]


def stop(children: list[subprocess.Popen[bytes]]) -> None:
    for child in children:
        if child.poll() is None:
            child.terminate()
    deadline = time.monotonic() + STOP_TIMEOUT
    for child in children:
        try:
            child.wait(timeout=max(0, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()


def main() -> int:
    children: list[subprocess.Popen[bytes]] = []
    stopping = False

    def request_stop(_signum: int, _frame: object) -> None:
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)
    try:
        migration = subprocess.Popen([sys.executable, "-m", "alembic", "upgrade", "head"], cwd=BACKEND)
        children.append(migration)
        while migration.poll() is None and not stopping:
            time.sleep(0.25)
        if stopping:
            return 0
        if migration.returncode != 0:
            return 1
        children.clear()
        for command in commands(os.environ.get("PORT", "10000")):
            if stopping:
                return 0
            children.append(subprocess.Popen(command, cwd=BACKEND))
        while not stopping:
            for child in children:
                if child.poll() is not None:
                    print("A required service exited; stopping the instance.", file=sys.stderr, flush=True)
                    return 1
            time.sleep(0.5)
        return 0
    finally:
        stop(children)


if __name__ == "__main__":
    raise SystemExit(main())
