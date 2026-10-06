"""Programmatic scenes do not initialize a raster provider; output rights stay gated."""
from types import SimpleNamespace

import pytest
import yaml

from app.config import Environment
from app.media.errors import MediaNotConfigured
from app.media.service import MediaService


def test_code_scene_uses_its_own_approved_rights_without_image_key(settings, tmp_path):
    path = tmp_path / "media.yaml"
    path.write_text(yaml.safe_dump({"schema": "qabas.media_policy/1", "scene_outputs": {"licence": {
        "status": "approved", "approved_by": "synthetic-reviewer", "approved_on": "2026-10-06"}}}), encoding="utf-8")
    context = SimpleNamespace(settings=settings.model_copy(update={"app_env": Environment.staging,
        "media_policy_path": path, "image_provider": None, "image_api_key": None}))
    service = MediaService(None, style={"identity": "synthetic-style"})
    style, terms = service.scene_inputs(context)
    assert style["identity"] == "synthetic-style" and terms["licence"]["status"] == "approved"
    assert service.image_provider is None


def test_raster_approval_cannot_approve_code_scene_output(settings, tmp_path):
    path = tmp_path / "media.yaml"
    path.write_text(yaml.safe_dump({"schema": "qabas.media_policy/1"}), encoding="utf-8")
    context = SimpleNamespace(settings=settings.model_copy(update={"app_env": Environment.staging,
                                                                   "media_policy_path": path}))
    service = MediaService(None, style={}, image_terms={"licence": {"status": "approved"}})
    with pytest.raises(MediaNotConfigured, match="distribution approval"):
        service.scene_inputs(context)
