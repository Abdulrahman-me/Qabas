"""Reviewed media inputs, never inferred approval from an available API key or a model's opinion."""

from __future__ import annotations

import hashlib
import json
from datetime import date
from pathlib import Path
from typing import Any

import yaml

from app.config import BACKEND_DIR, Settings
from app.media.errors import MediaNotConfigured

POLICY = BACKEND_DIR / "content" / "media" / "policy.yaml"


def read_yaml(path: Path) -> dict[str, Any]:
    def scalar(value: Any) -> str:
        if isinstance(value, date):
            return value.isoformat()
        raise MediaNotConfigured("media approval file contains unsupported YAML values")
    data = json.loads(json.dumps(yaml.safe_load(path.read_text("utf-8")), default=scalar))
    if not isinstance(data, dict):
        raise MediaNotConfigured("media approval file must be an object")
    return dict(data)


def approved(entry: dict[str, Any], label: str) -> None:
    if entry.get("status") != "approved" or not entry.get("approved_by") or not entry.get("approved_on"):
        raise MediaNotConfigured(f"{label} approval is pending")


def policy(path: Path = POLICY) -> dict[str, Any]:
    data = read_yaml(path)
    if data.get("schema") != "qabas.media_policy/1":
        raise MediaNotConfigured("unknown media policy")
    return data


def provider_policy(settings: Settings, kind: str, path: Path = POLICY) -> dict[str, Any]:
    name = getattr(settings, f"{kind}_provider")
    document = policy(path)
    if document.get("fixture_only") and not settings.is_dev_like:
        raise MediaNotConfigured("synthetic media policy cannot enable production or staging providers")
    entries = document["providers"].get(kind, {})
    if name not in entries:
        raise MediaNotConfigured(f"{kind} provider is unselected or unknown (O-03/O-13)")
    entry: dict[str, Any] = entries[name]
    # Paid media requires explicit terms/model approval in every environment; CI injects providers directly.
    approved(entry, f"{kind} provider/model/terms (O-03)")
    approved(entry["licence"], f"{kind} distribution licence")
    return entry


def style_inputs(path: Path = POLICY) -> dict[str, Any]:
    entry = policy(path)["style"]
    approved(entry, "style guide and character reference sheet (O-05/O-13)")
    out: dict[str, Any] = {"identity": {k: entry[k] for k in ("approved_by", "approved_on")}}
    for name in ("guide", "characters"):
        item = entry[name]
        file = (BACKEND_DIR / item["path"]).resolve()
        if not file.is_relative_to(BACKEND_DIR.resolve()) or not file.is_file():
            raise MediaNotConfigured(f"approved {name} file is missing")
        raw = file.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        if digest != item["sha256"]:
            raise MediaNotConfigured(f"approved {name} file changed")
        out[name] = raw.decode("utf-8")
        out["identity"][name] = digest
    references = []
    for item in entry["references"]:
        file = (BACKEND_DIR / item["path"]).resolve()
        if not file.is_relative_to(BACKEND_DIR.resolve()) or not file.is_file():
            raise MediaNotConfigured("approved character artwork is missing")
        raw = file.read_bytes()
        if hashlib.sha256(raw).hexdigest() != item["sha256"]:
            raise MediaNotConfigured("approved character artwork changed")
        references.append(raw)
    out["references"] = references
    out["identity"]["references"] = [hashlib.sha256(raw).hexdigest() for raw in references]
    return out


def scene_author_inputs(settings: Settings) -> dict[str, Any]:
    document = policy(settings.media_policy_path or POLICY)
    if document.get("fixture_only") and not settings.is_dev_like:
        raise MediaNotConfigured("synthetic scene authoring references cannot enable production")
    entry = document.get("scene_author", {})
    approved(entry, "scene design-token mapping and two reviewed example manifests (O-13)")
    if len(entry.get("examples", [])) != 2:
        raise MediaNotConfigured("scene authoring requires exactly two reviewed example manifests")
    def read(item: dict[str, Any]) -> str:
        file: Path = (BACKEND_DIR / item["path"]).resolve()
        if not file.is_relative_to(BACKEND_DIR.resolve()) or not file.is_file():
            raise MediaNotConfigured("approved scene authoring reference is missing")
        raw = file.read_bytes()
        if hashlib.sha256(raw).hexdigest() != item["sha256"]:
            raise MediaNotConfigured("approved scene authoring reference changed")
        return raw.decode("utf-8")
    return {"design_tokens": read(entry["design_tokens"]), "examples": [read(e) for e in entry["examples"]],
            "identity": {"approved_by": entry["approved_by"], "approved_on": entry["approved_on"],
                         "design_tokens": entry["design_tokens"]["sha256"],
                         "examples": [e["sha256"] for e in entry["examples"]]}}
