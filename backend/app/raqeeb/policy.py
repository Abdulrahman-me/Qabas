"""Reviewed code-owned routing, labels and referrals; model output cannot select targets."""

from __future__ import annotations

import re
from functools import cache
from pathlib import Path
from typing import Any

import yaml

from app.config import BACKEND_DIR
from app.contract import models as C
from app.sources.normalize import normalize_ar


def span(text: str) -> list[dict[str, Any]]:
    return [{"type": "text", "text": text}]


@cache
def load(directory: Path = BACKEND_DIR / "content") -> tuple[dict[str, Any], dict[str, Any]]:
    rules = yaml.safe_load((directory / "safety_rules.yaml").read_text(encoding="utf-8"))
    referrals = yaml.safe_load((directory / "referrals.yaml").read_text(encoding="utf-8"))
    if rules.get("schema") != "qabas.safety_rules/1" or referrals.get("schema") != "qabas.referrals/1":
        raise ValueError("unknown Raqeeb policy schema")
    for category in ("sensitive_human", "personal_fatwa"):
        for language in ("ar", "en"):
            if not rules["patterns"][category][language]:
                raise ValueError("empty safety policy")
            for expression in rules["patterns"][category][language]:
                re.compile(expression)
    for kind in ("fatwa_authority", "specialist", "human_support"):
        for language in ("ar", "en"):
            row = referrals["types"][kind][language]
            if not row["targets"] or not row["reason"]:
                raise ValueError("empty referral policy")
            C.Referral.model_validate({"referral_type": kind, "reason": span(row["reason"]),
                                       "targets": row["targets"]})
    return rules, referrals


def matches(text: str, category: str) -> bool:
    rules, _ = load()
    for language in ("ar", "en"):
        for expression in rules["patterns"][category][language]:
            if re.search(expression, text, re.IGNORECASE):
                return True
            # Arabic policy patterns are literal alternatives. Match normalized words too, without
            # normalizing regex syntax or rewriting the user's stored text.
            if language == "ar" and any(normalize_ar(word) in normalize_ar(text)
                    for word in expression.strip("()").split("|")):
                return True
    return False


def label(category: str, language: str) -> str:
    return str(load()[0]["labels"][category][language])


def template(name: str, language: str) -> dict[str, Any]:
    return {"type": "paragraph", "spans": span(load()[0]["templates"][name][language])}


def referral(kind: str, language: str) -> dict[str, Any]:
    row = load()[1]["types"][kind][language]
    return {"type": "referral", "referral": {"referral_type": kind, "reason": span(row["reason"]),
                                                "targets": row["targets"]}}


def abstention(category: str, language: str) -> list[dict[str, Any]]:
    if category == "personal_fatwa":
        return [referral("fatwa_authority", language)]
    if category == "sensitive_human":
        return [template(category, language), referral("human_support", language)]
    if category == "out_of_scope":
        return [template(category, language)]
    if category == "differing_opinions":
        return [{"type": "differing_views", "intro": template("unavailable", language)["spans"], "views": []},
                referral("specialist", language)]
    return [template("unavailable", language), referral("specialist", language)]
