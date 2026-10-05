"""Prompt registry and output schemas (agent catalog §17; system architecture ``llm/``).

A prompt is ``app/llm/prompts/<id>.md``: YAML front matter (``id``, ``version``, ``tier``, ``effort``, ``thinking``,
``max_tokens``, ``output_schema``, optional ``contract_model``) and the system text. ``LOCK.json`` pins each prompt's
version and the SHA-256 of its file; a prompt whose file changed without a recorded version bump is refused, so
every recorded call names exactly the text it used (``scripts/lock_prompts.py`` refreshes the lock and refuses a
changed file whose version was not raised).

Output schemas are ``app/llm/json_schemas/<name>.json``, written in the strict subset structured outputs accept:
every object closes ``additionalProperties`` and requires all its properties.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any, Literal

import yaml
from jsonschema import Draft202012Validator
from pydantic import BaseModel, ConfigDict, Field

from app.llm.errors import LLMNotConfigured

LLM_DIR = Path(__file__).resolve().parent
PROMPTS = LLM_DIR / "prompts"
PARTIALS = PROMPTS / "partials"
SCHEMAS = LLM_DIR / "json_schemas"
LOCK = PROMPTS / "LOCK.json"

Tier = Literal["strong", "fast"]
Effort = Literal["low", "medium", "high", "xhigh", "max"]


class PromptMeta(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    id: str = Field(pattern=r"^[a-z][a-z0-9_]{1,60}$")
    version: int = Field(ge=1)
    tier: Tier
    effort: Effort                          # always explicit: Opus 5.5 would otherwise default to medium
    thinking: Literal["disabled", "adaptive"] = "disabled"
    max_tokens: int = Field(ge=16, le=64_000)
    output_schema: str
    contract_model: str | None = None       # a revision 10 contract model the output must also satisfy
    includes: list[str] = Field(default_factory=list)   # shared rule texts from prompts/partials/<name>.md
    purpose: str


@dataclass(frozen=True)
class Prompt:
    meta: PromptMeta
    system: str
    schema: dict[str, Any]
    sha256: str                             # of the prompt file (the recorded prompt identity)
    schema_sha256: str

    @property
    def id(self) -> str:
        return self.meta.id

    @property
    def version(self) -> int:
        return self.meta.version

    def identity(self) -> dict[str, Any]:
        return {"prompt_id": self.id, "prompt_version": self.version, "prompt_sha256": self.sha256,
                "schema": self.meta.output_schema, "schema_sha256": self.schema_sha256}


def strict_schema_problems(schema: Any, path: str = "$") -> list[str]:
    """Structured-output compatibility: closed objects that require every property, no external references."""
    problems: list[str] = []
    if isinstance(schema, dict):
        if "$ref" in schema and not str(schema["$ref"]).startswith("#/"):
            problems.append(f"{path}: only local $ref is allowed")
        if schema.get("type") == "object":
            if schema.get("additionalProperties") is not False:
                problems.append(f"{path}: objects must set additionalProperties: false")
            properties = schema.get("properties", {})
            if set(schema.get("required", [])) != set(properties):
                problems.append(f"{path}: every property must be required (use a nullable type instead)")
        for key, value in schema.items():
            problems.extend(strict_schema_problems(value, f"{path}.{key}"))
    elif isinstance(schema, list):
        for index, item in enumerate(schema):
            problems.extend(strict_schema_problems(item, f"{path}[{index}]"))
    return problems


def load_schema(name: str) -> dict[str, Any]:
    path = SCHEMAS / name
    if not path.is_file():
        raise LLMNotConfigured(f"output schema {name} does not exist")
    schema: dict[str, Any] = json.loads(path.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    problems = strict_schema_problems(schema)
    if problems:
        raise LLMNotConfigured(f"{name}: " + "; ".join(problems))
    return schema


def normalized(path: Path) -> bytes:
    """File bytes with LF line endings, so digests do not depend on the checkout's newline conversion."""
    return path.read_bytes().replace(b"\r\n", b"\n")


def parse_prompt(path: Path) -> Prompt:
    raw = normalized(path)
    text = raw.decode("utf-8")
    if not text.startswith("---\n"):
        raise LLMNotConfigured(f"{path.name}: missing front matter")
    header, _, body = text[4:].partition("\n---\n")
    meta = PromptMeta.model_validate(yaml.safe_load(header))
    if meta.id != path.stem:
        raise LLMNotConfigured(f"{path.name}: front matter id {meta.id!r} differs from the file name")
    if not body.strip():
        raise LLMNotConfigured(f"{path.name}: empty system text")
    schema = load_schema(meta.output_schema)
    schema_bytes = normalized(SCHEMAS / meta.output_schema)
    # Shared rules come first (the agent catalog puts the fixed rules at the top); the identity covers them.
    parts, identity = [], hashlib.sha256(raw)
    for name in meta.includes:
        partial = PARTIALS / f"{name}.md"
        if not partial.is_file():
            raise LLMNotConfigured(f"{path.name}: included partial {name!r} does not exist")
        content = normalized(partial)
        identity.update(b"\0" + name.encode() + b"\0" + content)
        parts.append(content.decode("utf-8").strip())
    system = "\n\n".join([*parts, body.strip()])
    return Prompt(meta, system, schema, identity.hexdigest(), hashlib.sha256(schema_bytes).hexdigest())


def read_lock() -> dict[str, dict[str, Any]]:
    return dict(json.loads(LOCK.read_text(encoding="utf-8"))) if LOCK.is_file() else {}


@lru_cache
def get_prompt(prompt_id: str) -> Prompt:
    """A registered prompt; its file must match the lock (version and digest)."""
    path = PROMPTS / f"{prompt_id}.md"
    if not path.is_file():
        raise LLMNotConfigured(f"unknown prompt {prompt_id!r}")
    prompt = parse_prompt(path)
    locked = read_lock().get(prompt_id)
    if locked is None or locked["version"] != prompt.version or locked["sha256"] != prompt.sha256:
        raise LLMNotConfigured(f"prompt {prompt_id!r} differs from LOCK.json (bump its version and re-lock)")
    return prompt


def all_prompts() -> list[Prompt]:
    return [parse_prompt(path) for path in sorted(PROMPTS.glob("*.md"))]
