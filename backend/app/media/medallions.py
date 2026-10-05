"""Consume approved human-authored calligraphic SVGs. Never generate or substitute sacred-figure artwork."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from app.config import BACKEND_DIR
from app.media import objects, scenes
from app.media.errors import MediaInvalid, MediaNotConfigured
from app.media.policy import approved, read_yaml
from app.services.platform.storage import ObjectStorage, sha256_hex

REGISTRY = BACKEND_DIR / "content/medallions/registry.yaml"


def verified_item(figure: str, path: Path) -> tuple[dict[str, Any], bytes]:
    if not path.is_file():
        raise MediaNotConfigured("approved medallion registry/artwork is missing (D-37/O-13)")
    registry = read_yaml(path)
    if not isinstance(registry, dict) or registry.get("schema") != "qabas.medallions/1" or not registry.get("figures"):
        raise MediaNotConfigured("medallion registry must contain real approved artwork")
    item = registry["figures"].get(figure)
    if not isinstance(item, dict):
        raise MediaNotConfigured(f"approved medallion asset is missing for {figure}")
    approved(item, "human medallion artwork audit")
    approved(item["licence"], "medallion distribution licence")
    file = (path.parent / item["file"]).resolve()
    if not file.is_relative_to(BACKEND_DIR.resolve()) or not file.is_file():
        raise MediaNotConfigured("approved medallion file is missing or outside the content workspace")
    raw = file.read_bytes()
    if len(raw) > 1_000_000 or sha256_hex(raw) != item["sha256"]:
        raise MediaInvalid("medallion differs from its approved bytes")
    descriptor = {
        "asset_id": figure,
        "url": "https://medallion.example.test/verified.svg",
        "mime_type": "image/svg+xml",
        "width": item["width"],
        "height": item["height"],
        "bytes": len(raw),
        "sha256": item["sha256"],
    }
    found = scenes.checker().asset_errors({"assets": [descriptor]}, {descriptor["url"]: file})
    if found:
        raise MediaInvalid("medallion SVG failed its bounded SVG validation")
    return item, raw


def verify_receipt(record: objects.MediaObject, raw: bytes, path: Path = REGISTRY) -> None:
    item, approved_bytes = verified_item(record.binding["figure"], path)
    provenance = record.provenance
    if (
        not provenance.get("human_authored")
        or sha256_hex(path.read_bytes()) != provenance.get("registry_sha256")
        or raw != approved_bytes
        or record.licence != item["licence"]
        or provenance.get("approved_by") != item["approved_by"]
        or provenance.get("approved_on") != str(item["approved_on"])
        or provenance.get("artwork_sha256") != item["sha256"]
        or (record.width, record.height) != (item["width"], item["height"])
    ):
        raise MediaInvalid("medallion receipt differs from the current approved human artwork")


async def resolve(
    figures: list[str], storage: ObjectStorage, run_id: str, path: Path = REGISTRY
) -> tuple[dict[str, list[dict[str, Any]]], list[dict[str, Any]]]:
    overlays: dict[str, list[dict[str, Any]]] = {"ar": [], "en": []}
    if not figures:
        return overlays, []
    receipts = []
    for figure in figures:
        item, raw = verified_item(figure, path)
        record = await objects.stage(
            storage,
            run_id=run_id,
            prefix="medallions",
            data=raw,
            mime_type="image/svg+xml",
            kind="medallion",
            width=item["width"],
            height=item["height"],
            licence=item["licence"],
            binding={"figure": figure},
            provenance={
                "human_authored": True,
                "registry_sha256": sha256_hex(path.read_bytes()),
                "approved_by": item["approved_by"],
                "approved_on": str(item["approved_on"]),
                "artwork_sha256": item["sha256"],
            },
        )
        receipts.append(record.model_dump(mode="json"))
        for language in ("ar", "en"):
            label = item["labels"].get(language)
            if not isinstance(label, str) or not label.strip():
                raise MediaInvalid("approved medallion needs bilingual accessibility labels")
            overlays[language].append(
                {
                    "type": "medallion",
                    "asset_url": record.public_url(storage),
                    "label": label,
                    "anchor": item["anchor"],
                    "size_pct": item["size_pct"],
                }
            )
    return overlays, receipts
