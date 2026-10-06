"""Bounded ticket-safe API/WS launcher; reverse proxies must also omit WS URL query strings from logs."""

from __future__ import annotations

import argparse

import uvicorn

from app.config import get_settings
from app.logs import configure_logging


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--workers", type=int, default=1)
    args = parser.parse_args()
    settings = get_settings()
    configure_logging(settings.log_level)
    uvicorn.run("app.main:app", host=args.host, port=args.port, workers=args.workers, log_config=None,
                access_log=False, ws_max_size=settings.live_ws_max_frame_bytes, ws_max_queue=8,
                timeout_graceful_shutdown=10)


if __name__ == "__main__":
    main()
