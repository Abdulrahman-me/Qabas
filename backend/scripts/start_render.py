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
PREPARATION_TIMEOUT = 120


def commands(port: str) -> list[list[str]]:
    return [
        # Start the port-binding process before loading the queue worker.
        [sys.executable, "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", port],  # noqa: S104
        [sys.executable, "-m", "celery", "-A", "app.workers.celery_app", "worker",
         "--pool=solo", "--concurrency=1", "-B", "--schedule=/tmp/qabas-celerybeat",
         "-Q", "maintenance,raqeeb,embeddings", "--loglevel=INFO"],
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
    os.environ["PYTHONUNBUFFERED"] = "1"
    try:
        preparations = [[sys.executable, "-m", "alembic", "upgrade", "head"]]
        if os.environ.get("MUSHAF_ARCHIVE_URL"):
            preparations.append([sys.executable, "scripts/fetch_mushaf.py", "--if-missing"])
        else:
            print("Canonical dataset must be installed during build; "
                  "startup download disabled without MUSHAF_ARCHIVE_URL.", flush=True)
        for preparation in preparations:
            label = "migrations" if "alembic" in preparation else "canonical dataset"
            print(f"Starting {label} (timeout {PREPARATION_TIMEOUT}s)", flush=True)
            child = subprocess.Popen(preparation, cwd=BACKEND)
            children.append(child)
            preparation_deadline = time.monotonic() + PREPARATION_TIMEOUT
            while child.poll() is None and not stopping:
                if time.monotonic() >= preparation_deadline:
                    print(f"Startup blocked: {label} exceeded {PREPARATION_TIMEOUT}s; "
                          "stopping instead of waiting for Render's port timeout.", file=sys.stderr, flush=True)
                    return 1
                time.sleep(0.25)
            if stopping:
                return 0
            if child.returncode != 0:
                print(f"Startup failed: {label} exited with {child.returncode}", file=sys.stderr, flush=True)
                return 1
            print(f"Completed {label}", flush=True)
            children.clear()
        for command in commands(os.environ.get("PORT", "10000")):
            if stopping:
                return 0
            label = "API" if "uvicorn" in command else "reply worker with scheduler"
            print(f"Starting {label}", flush=True)
            child = subprocess.Popen(command, cwd=BACKEND)
            children.append(child)
            print(f"Started {label} pid={child.pid}", flush=True)
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
