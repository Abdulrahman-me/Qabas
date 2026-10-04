"""Bounded newline JSON-RPC stdio client. No shell, sampling, filesystem tools or ambient secrets."""

from __future__ import annotations

import asyncio
import json
import os
from collections.abc import Sequence
from typing import Any

from app.sources.errors import ProviderResponseInvalid, UpstreamUnavailable
from app.sources.providers.base import require
from app.sources.records import canonical_json

PROTOCOLS = {"2025-06-18", "2025-03-26", "2024-11-05"}


class StdioMcp:
    def __init__(self, provider: str, command: Sequence[str], *, connect_timeout: float = 5,
                 read_timeout: float = 15) -> None:
        if not command or not all(isinstance(item, str) and item for item in command):
            raise ValueError("MCP command must be a nonempty argv array")
        self.provider, self.command = provider, list(command)
        self.connect_timeout, self.read_timeout = connect_timeout, read_timeout
        self.process: asyncio.subprocess.Process | None = None
        self.tools: dict[str, dict[str, Any]] = {}
        self._next_id = 0
        self._lock = asyncio.Lock()

    async def aclose(self) -> None:
        process, self.process = self.process, None
        self.tools.clear()
        if process is None or process.returncode is not None:
            return
        if process.stdin:
            process.stdin.close()
        try:
            await asyncio.wait_for(process.wait(), 1)
        except TimeoutError:
            process.terminate()
            try:
                await asyncio.wait_for(process.wait(), 1)
            except TimeoutError:
                process.kill()
                await process.wait()

    async def _start(self) -> None:
        if self.process is not None and self.process.returncode is None:
            return
        env = {key: value for key, value in os.environ.items()
               if key.upper() in {"PATH", "SYSTEMROOT", "WINDIR", "TEMP", "TMP", "PATHEXT"}}
        env["PYTHONUTF8"] = "1"
        async with asyncio.timeout(self.connect_timeout):
            self.process = await asyncio.create_subprocess_exec(
                *self.command, env=env, stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL, limit=1_048_576)
            initialized = await self._rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                                         "clientInfo": {"name": "qabas", "version": "1"}})
            if initialized.get("protocolVersion") not in PROTOCOLS:
                raise ProviderResponseInvalid(self.provider, "unsupported MCP protocol")
            require(self.provider, initialized, "serverInfo", dict)
            require(self.provider, require(self.provider, initialized, "capabilities", dict), "tools", dict)
            await self._write({"jsonrpc": "2.0", "method": "notifications/initialized"})
            listing = await self._rpc("tools/list", {})
            if listing.get("nextCursor"):
                raise ProviderResponseInvalid(self.provider, "paginated tool catalogue needs reviewed mapping")
            self.tools = {require(self.provider, item, "name"): item
                          for item in require(self.provider, listing, "tools", list)}

    async def _write(self, message: dict[str, Any]) -> None:
        assert self.process and self.process.stdin
        self.process.stdin.write((canonical_json(message) + "\n").encode())
        await self.process.stdin.drain()

    async def _rpc(self, method: str, params: dict[str, Any]) -> dict[str, Any]:
        assert self.process and self.process.stdout
        self._next_id += 1
        request_id = self._next_id
        await self._write({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params})
        async with asyncio.timeout(self.read_timeout):
            for _ in range(100):
                line = await self.process.stdout.readline()
                if not line:
                    raise OSError("MCP process closed stdout")
                try:
                    message = json.loads(line)
                except (ValueError, UnicodeDecodeError) as exc:
                    raise ProviderResponseInvalid(self.provider, "MCP stdout is not JSON") from exc
                if not isinstance(message, dict) or message.get("jsonrpc") != "2.0":
                    raise ProviderResponseInvalid(self.provider, "invalid MCP envelope")
                if message.get("method"):
                    if "id" in message:
                        # We advertise no sampling, roots or elicitation capabilities.
                        await self._write({"jsonrpc": "2.0", "id": message["id"],
                                           "error": {"code": -32601, "message": "Unsupported client method"}})
                    continue
                if message.get("id") != request_id:
                    raise ProviderResponseInvalid(self.provider, "MCP response identity differs from request")
                if "error" in message:
                    raise ProviderResponseInvalid(self.provider, "MCP RPC returned an error")
                return dict(require(self.provider, message, "result", dict))
        raise ProviderResponseInvalid(self.provider, "excessive MCP notifications")

    async def call(self, tool: str, arguments: dict[str, Any]) -> dict[str, Any]:
        async with self._lock:
            try:
                await self._start()
                if tool not in self.tools:
                    raise ProviderResponseInvalid(self.provider, "configured tool is absent from MCP catalogue")
                schema = require(self.provider, self.tools[tool], "inputSchema", dict)
                from jsonschema import Draft202012Validator
                if list(Draft202012Validator(schema).iter_errors(arguments)):
                    raise ProviderResponseInvalid(self.provider, "arguments disagree with MCP tool schema")
                return await self._rpc("tools/call", {"name": tool, "arguments": arguments})
            except asyncio.CancelledError:
                await self.aclose()
                raise
            except (OSError, TimeoutError) as exc:
                await self.aclose()
                raise UpstreamUnavailable(self.provider, f"MCP transport failure ({type(exc).__name__})") from exc
            except (ValueError, ProviderResponseInvalid) as exc:
                await self.aclose()
                if isinstance(exc, ProviderResponseInvalid):
                    raise
                raise ProviderResponseInvalid(self.provider, "invalid MCP message or schema") from exc
