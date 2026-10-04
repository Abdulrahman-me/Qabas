"""Pinned native sidecar lifecycle and the actual NodeCache disable hook."""

import asyncio
import shutil
import socket
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest

from app.sources.sidecar import REVISION_FILE, DorarSidecar, SidecarError


def port() -> int:
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return int(listener.getsockname()[1])


def test_sidecar_checks_real_head_and_tracked_changes(tmp_path: Path, monkeypatch: Any) -> None:
    revision = "a" * 40
    (tmp_path / REVISION_FILE).write_text(revision)
    sidecar = DorarSidecar(tmp_path, f"http://127.0.0.1:{port()}", revision=revision)
    calls = []

    def run(args: list[str], **kwargs: Any) -> Any:
        calls.append(args)
        return subprocess.CompletedProcess(args, 0, stdout=revision if "rev-parse" in args else "", stderr="")
    monkeypatch.setattr(subprocess, "run", run)
    sidecar.check_revision()
    assert len(calls) == 2
    monkeypatch.setattr(subprocess, "run", lambda *a, **k: subprocess.CompletedProcess(a, 0, stdout="wrong"))
    with pytest.raises(SidecarError, match="HEAD"):
        sidecar.check_revision()
    (tmp_path / REVISION_FILE).write_text("b" * 40)
    with pytest.raises(SidecarError, match="pinned"):
        sidecar.check_revision()


async def test_sidecar_start_stop_and_no_ambient_secrets(tmp_path: Path, monkeypatch: Any) -> None:
    monkeypatch.setenv("QURAN_FOUNDATION_CLIENT_SECRET", "must-not-be-in-child")
    monkeypatch.setenv("DATABASE_URL", "must-not-be-in-child")
    command = [sys.executable, "-c", "import os,socket,time; "
               "s=socket.socket(); s.bind(('127.0.0.1',int(os.environ['PORT']))); s.listen(); time.sleep(30)"]
    sidecar = DorarSidecar(tmp_path, f"http://127.0.0.1:{port()}", command=command)
    monkeypatch.setattr(sidecar, "check_revision", lambda: None)
    assert "DATABASE_URL" not in sidecar.env and "QURAN_FOUNDATION_CLIENT_SECRET" not in sidecar.env
    assert "RATE_LIMIT_MAX" not in sidecar.env
    await sidecar.start(timeout=3)
    process = sidecar.process
    assert process is not None and process.returncode is None
    with pytest.raises(SidecarError, match="already"):
        await sidecar.start()
    await sidecar.stop()
    assert process.returncode is not None and sidecar.process is None
    await sidecar.stop()


async def test_sidecar_refuses_occupied_port(tmp_path: Path, monkeypatch: Any) -> None:
    server = await asyncio.start_server(lambda r, w: w.close(), "127.0.0.1", 0)
    assert server.sockets
    sidecar = DorarSidecar(tmp_path, f"http://127.0.0.1:{server.sockets[0].getsockname()[1]}")
    monkeypatch.setattr(sidecar, "check_revision", lambda: None)
    try:
        with pytest.raises(SidecarError, match="occupied"):
            await sidecar.start()
        assert sidecar.process is None
    finally:
        server.close()
        await server.wait_closed()


def test_node_cache_hook_never_stores_even_with_zero_ttl(tmp_path: Path) -> None:
    node = shutil.which("node")
    assert node, "Node is required for the pinned Dorar sidecar and its cache safety test"
    module = tmp_path / "node_modules" / "node-cache"
    module.mkdir(parents=True)
    (module / "index.js").write_text(
        "module.exports=class NodeCache { constructor(){this.data={};} "
        "set(k,v){this.data[k]=v;return true;} get(k){return this.data[k];} has(k){return k in this.data;} };",
        encoding="utf-8")
    from app.sources import sidecar
    hook = Path(sidecar.__file__).with_name("dorar_no_cache.cjs")
    result = subprocess.run([node, "--require", str(hook), "-e", "const C=require('node-cache');"
                             "const c=new C({stdTTL:0});c.set('x','private-provider-response');"
                             "if(c.has('x')||c.get('x')!==undefined||Object.keys(c.data).length)process.exit(1);"],
                            cwd=tmp_path, capture_output=True, check=False)
    assert result.returncode == 0
