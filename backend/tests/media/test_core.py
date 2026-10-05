from __future__ import annotations

import io
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

import av
import pytest
from PIL import Image

from app.config import Settings
from app.llm.vision import VisionImage
from app.media import objects, scenes
from app.media.audio import mp3_duration, reference_clip
from app.media.codecs import raster, webp
from app.media.errors import MediaInvalid, MediaNotConfigured
from app.media.policy import provider_policy, style_inputs
from app.services.platform.storage import Bucket, ImmutableObjectError, LocalStorage, sha256_hex


def picture(width: int = 1600, height: int = 1000) -> bytes:
    output = io.BytesIO()
    Image.new("RGB", (width, height), "#0B5A52").save(output, "WEBP", lossless=True)
    return output.getvalue()


def audio() -> bytes:
    output = io.BytesIO()
    with av.open(output, "w", format="mp3") as container:
        stream = container.add_stream("libmp3lame", rate=24000)
        stream.layout = "mono"
        for index in range(20):
            frame = av.AudioFrame(format="fltp", layout="mono", samples=2400)
            frame.sample_rate = 24000
            frame.pts = index * 2400
            frame.planes[0].update(bytes(frame.planes[0].buffer_size))
            for packet in stream.encode(frame):
                container.mux(packet)
        for packet in stream.encode(None):
            container.mux(packet)
    return output.getvalue()


@pytest.fixture
def storage(tmp_path: Path) -> LocalStorage:
    return LocalStorage(
        tmp_path,
        public_base_url="https://cdn.example.test",
        private_base_url="https://private.example.test",
        signing_key=b"test-key",
    )


@pytest.mark.parametrize("bucket", list(Bucket))
def test_concurrent_create_only_writers(storage: LocalStorage, bucket: Bucket) -> None:
    def write(data: bytes) -> bool:
        try:
            storage.put_immutable(bucket, "same.webp", data, "image/webp")
            return True
        except ImmutableObjectError:
            return False

    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(write, [b"a", b"b"] * 8))
    winner = storage.get(bucket, "same.webp")
    assert sum(results) == 8
    assert winner in {b"a", b"b"}
    storage.put_immutable(bucket, "same.webp", winner, "image/webp")
    with pytest.raises(ImmutableObjectError):
        storage.put_immutable(bucket, "same.webp", winner, "image/png")


@pytest.mark.parametrize(
    "mime,width,height", [("image/png", 1600, 1000), ("image/webp", 1000, 1600), ("image/webp", 1601, 1000)]
)
def test_actual_image_format_and_dimensions(mime: str, width: int, height: int) -> None:
    with pytest.raises(MediaInvalid):
        raster(picture(), mime, width, height)


def test_audit_vision_requires_real_pixels() -> None:
    frame = VisionImage(picture(), "image/webp")
    assert frame.block()["source"]["type"] == "base64"
    assert frame.sha256 == sha256_hex(picture())
    with pytest.raises(Exception, match=r"vision|image"):
        VisionImage(b"not an image", "image/webp").block()


def test_explicit_webp_transformation() -> None:
    data = webp(picture(1536, 1024), "image/webp", 1600, 1000, native=(1536, 1024))
    raster(data, "image/webp", 1600, 1000)
    assert len(data) < 1_000_000


async def test_private_receipt_and_transport_projection(storage: LocalStorage) -> None:
    record = await objects.stage(
        storage,
        run_id="run_test",
        prefix="images",
        data=picture(),
        mime_type="image/webp",
        kind="illustration",
        provenance={"audit": {"passed": True}},
        licence={},
        binding={},
        width=1600,
        height=1000,
    )
    assert await objects.verify(storage, record) == picture()
    assert not storage.exists(Bucket.content, record.content_key)
    original = {"url": record.public_url(storage), "hash": record.sha256}
    projected = objects.sign_projection(original, [record.model_dump()], storage, 2000)
    assert original["url"] == record.public_url(storage)
    parsed = urlsplit(projected["url"])
    assert parsed.hostname == "private.example.test"
    assert "signature" in parse_qs(parsed.query)
    storage.put(Bucket.private, record.private_key, b"tampered", "image/webp")
    with pytest.raises(MediaInvalid, match="bytes"):
        await objects.verify(storage, record)


def test_pending_approvals_do_not_enable_providers(settings: Settings) -> None:
    with pytest.raises(MediaNotConfigured):
        provider_policy(settings, "image")
    with pytest.raises(MediaNotConfigured):
        style_inputs()


@pytest.mark.parametrize("raw", [b"", b"ID3fake", b"RIFFwrong", picture()])
def test_audio_header_is_not_audio_validation(raw: bytes) -> None:
    with pytest.raises(MediaInvalid):
        mp3_duration(raw)


def test_licensed_reference_cut_preserves_word_binding() -> None:
    data = audio()
    assert 1950 <= mp3_duration(data) <= 2050
    clipped, timings, provenance = reference_clip(
        data,
        expected_sha256=sha256_hex(data),
        start_ms=400,
        end_ms=1600,
        timings=[[1, 0, 300], [2, 500, 900], [3, 1000, 1500]],
        word_start=2,
        word_end=3,
        canonical_word_count=3,
    )
    assert 1150 <= mp3_duration(clipped) <= 1250
    assert timings == [[2, 100, 500], [3, 600, 1100]]
    assert provenance["original_sha256"] == sha256_hex(data)
    with pytest.raises(MediaInvalid, match="hash"):
        reference_clip(
            data,
            expected_sha256="0" * 64,
            start_ms=0,
            end_ms=1000,
            timings=[],
            word_start=1,
            word_end=1,
            canonical_word_count=1,
        )


def test_complete_scene_grammar_does_not_claim_capability_release() -> None:
    import json

    from app.contract import FIXTURES_DIR

    manifest = json.loads((FIXTURES_DIR / "scenes/scn_test_desert_well.v2.scene.json").read_text("utf-8"))
    assert scenes.validate(manifest, {}) == []
    assert any("capability" in error for error in scenes.validate(manifest, {}, publication=True))
    assert scenes.released() == []
    scenes.state(manifest, {"beat": 1, "focus": -1})
    with pytest.raises(MediaInvalid):
        scenes.state(manifest, {"beat": True})


async def test_private_scene_transport_signs_dependencies_without_changing_reviewed_objects(
    storage: LocalStorage,
) -> None:
    import json
    from urllib.parse import unquote
    asset = await objects.stage(storage, run_id="run_test", prefix="images", data=picture(), mime_type="image/webp",
        kind="illustration", provenance={}, licence={}, binding={}, width=1600, height=1000)
    original = {"scene_id": "scn_test", "version": 1, "assets": [{"url": asset.public_url(storage),
                "sha256": asset.sha256}]}
    manifest = await objects.stage(storage, run_id="run_test", prefix="scenes", data=objects.encode(original),
        mime_type="application/json", kind="scene_manifest", provenance={}, licence={}, binding={})
    scene_ref = {"scene_id": "scn_test", "version": 1, "schema_version": "qabas.scene/1",
                 "url": manifest.public_url(storage), "sha256": manifest.sha256}
    records = [r.model_dump(mode="json") for r in (asset, manifest)]
    result = await objects.review_projection(scene_ref, records, storage, 900, published=False)
    key = unquote(urlsplit(result["url"]).path.removeprefix("/"))
    raw = storage.get(Bucket.private, key)
    assert result["sha256"] == sha256_hex(raw) and result["sha256"] != manifest.sha256
    transport = json.loads(raw)
    assert transport["assets"][0]["sha256"] == asset.sha256
    assert "signature=" in transport["assets"][0]["url"]
    assert await objects.verify(storage, manifest) == objects.encode(original)
    assert await objects.review_projection(scene_ref, records, storage, 900, published=True) == scene_ref


@pytest.mark.parametrize("code,unavailable", [("NoSuchKey", False), ("503", True)])
async def test_storage_failure_is_classified_without_exposing_sdk_details(code: str, unavailable: bool) -> None:
    from botocore.exceptions import ClientError

    from app.media.errors import MediaUnavailable
    def broken() -> bytes:
        raise ClientError({"Error": {"Code": code, "Message": "synthetic sensitive provider detail"}}, "GetObject")
    with pytest.raises(MediaUnavailable if unavailable else MediaInvalid) as error:
        await objects.io(broken)
    assert "sensitive" not in str(error.value)
