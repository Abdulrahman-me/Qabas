"""The Dorar sidecar: the pinned Node service run natively as a local child process (handoff §12; no containers).

The sidecar directory must contain the exact pinned revision (``.qabas-revision`` written by
``scripts/dorar_sidecar.py install``); anything else is refused. ``start`` waits until the port accepts
connections (or the process dies); ``stop`` terminates it and kills it if it does not exit.
"""

from __future__ import annotations

import asyncio
import contextlib
import os
import shutil
import subprocess
from collections.abc import Sequence
from pathlib import Path
from types import TracebackType
from urllib.parse import urlsplit

from app.config import Settings, get_settings
from app.sources.policy import policy

REVISION_FILE = ".qabas-revision"


class SidecarError(RuntimeError):
    pass


def pinned_revision() -> str:
    sidecar = policy("dorar").option("sidecar") or {}
    revision = sidecar.get("revision")
    if not isinstance(revision, str) or len(revision) != 40:
        raise SidecarError("providers.yaml does not pin a Dorar sidecar revision")
    return revision


class DorarSidecar:
    def __init__(self, directory: Path, base_url: str, *, command: Sequence[str] | None = None,
                 revision: str | None = None, env: dict[str, str] | None = None,
                 settings: Settings | None = None) -> None:
        parts = urlsplit(base_url)
        if parts.hostname not in ("127.0.0.1", "localhost") or parts.port is None:
            raise SidecarError(f"the sidecar runs locally on an explicit port, not {base_url}")
        self.directory = directory
        self.settings = settings or get_settings()
        self.host, self.port = parts.hostname, parts.port
        self.command = list(command) if command is not None else [
            "node", "--require", str(Path(__file__).with_name("dorar_no_cache.cjs")), "server.js"]
        self.revision = revision or pinned_revision()
        # Keep the provider's access limit. A breaker is not an access-rate licence (O-03).
        self.env = {**{key: value for key, value in os.environ.items()
                      if key.upper() in {"PATH", "SYSTEMROOT", "WINDIR", "TEMP", "TMP", "PATHEXT"}},
                    "PORT": str(self.port), "CACHE_EACH": "5",
                    "FETCH_TIMEOUT": "15000", **(env or {})}
        self.process: asyncio.subprocess.Process | None = None

    def check_revision(self) -> None:
        marker = self.directory / REVISION_FILE
        found = marker.read_text(encoding="utf-8").strip() if marker.is_file() else None
        if found != self.revision:
            raise SidecarError(f"{self.directory} holds revision {found!r}, not the pinned {self.revision} "
                               "(run scripts/dorar_sidecar.py install)")
        try:
            git = shutil.which("git")
            if git is None:
                raise SidecarError("git is required to verify the sidecar")
            head = subprocess.run([git, "-C", str(self.directory), "rev-parse", "HEAD"],  # noqa: S603 - fixed git args
                                  check=True, capture_output=True, text=True).stdout.strip()
            changes = subprocess.run(  # noqa: S603 - fixed git args, no shell
                [git, "-C", str(self.directory), "status", "--porcelain", "--untracked-files=no"],
                check=True, capture_output=True, text=True).stdout.strip()
        except (OSError, subprocess.CalledProcessError) as exc:
            raise SidecarError("cannot verify the pinned sidecar checkout") from exc
        if head != self.revision or changes:
            raise SidecarError("sidecar HEAD or tracked files differ from the pinned revision")

    async def start(self, timeout: float = 15.0) -> None:
        policy("dorar").require_live(self.settings)
        if self.process is not None:
            raise SidecarError("sidecar is already started")
        self.check_revision()
        # Do not accidentally treat an unrelated process on this port as the pinned sidecar.
        try:
            _, existing = await asyncio.open_connection(self.host, self.port)
        except OSError:
            pass
        else:
            existing.close()
            await existing.wait_closed()
            raise SidecarError("sidecar port is already occupied")
        self.process = await asyncio.create_subprocess_exec(
            *self.command, cwd=self.directory, env=self.env,
            stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
        try:
            await self._wait_ready(timeout)
        except BaseException:
            await self.stop()
            raise

    async def _wait_ready(self, timeout: float) -> None:
        assert self.process is not None
        loop = asyncio.get_running_loop()
        deadline = loop.time() + timeout
        while loop.time() < deadline:
            if self.process.returncode is not None:
                raise SidecarError(f"sidecar exited with code {self.process.returncode} during startup")
            with contextlib.suppress(OSError):
                _, writer = await asyncio.open_connection(self.host, self.port)
                writer.close()
                await writer.wait_closed()
                return
            await asyncio.sleep(0.1)
        await self.stop()
        raise SidecarError(f"sidecar did not accept connections on port {self.port} within {timeout} s")

    async def stop(self, grace: float = 5.0) -> None:
        process, self.process = self.process, None
        if process is None or process.returncode is not None:
            return
        process.terminate()
        try:
            await asyncio.wait_for(process.wait(), grace)
        except TimeoutError:
            process.kill()
            await process.wait()

    async def __aenter__(self) -> DorarSidecar:
        await self.start()
        return self

    async def __aexit__(self, exc_type: type[BaseException] | None, exc: BaseException | None,
                        tb: TracebackType | None) -> None:
        await self.stop()
