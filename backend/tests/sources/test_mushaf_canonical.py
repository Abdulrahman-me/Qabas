"""The canonical KFGQPC dataset itself - only where it has been installed (scripts/fetch_mushaf.py).

CI does not download it (no live calls; redistribution pending, D-88), so these skip there. Locally they prove the
pinned file loads, has the published structure, agrees word-for-word with the recorded Quran.com capability data
for 4:103, and resolves every Qur'an reference the Unit 0 drafts ask code to insert.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.config import Settings
from app.sources.mushaf import Mushaf, get_mushaf, load_manifest
from app.sources.normalize import normalize_ar

RECORDINGS = Path(__file__).parent / "recordings"
_canonical, _specs = load_manifest()
_PATH = Settings().mushaf_dir / f"{_canonical}.json"

pytestmark = pytest.mark.skipif(not _PATH.is_file(), reason="canonical mushaf not installed (fetch_mushaf.py)")


@pytest.fixture(scope="module")
def mushaf() -> Mushaf:
    return get_mushaf(Settings())


def test_structure(mushaf: Mushaf) -> None:
    assert len(mushaf.surahs) == 114 and sum(len(s.ayahs) for s in mushaf.surahs) == 6236
    assert len(mushaf.surah(2).ayahs) == 286 and len(mushaf.surah(108).ayahs) == 3


def test_agrees_with_the_recorded_capability_text(mushaf: Mushaf) -> None:
    recorded = json.loads((RECORDINGS / "quran_com" / "verse_4_103.json").read_text("utf-8"))["response"]["body"]["verse"]
    words = [w["text_qpc_hafs"] for w in recorded["words"] if w["char_type_name"] == "word"]
    canonical = mushaf.get(4, 103).words
    assert [normalize_ar(w) for w in words] == [normalize_ar(w.text) for w in canonical]
    assert len(recorded["audio"]["segments"]) == len(canonical) == 20


@pytest.mark.parametrize(("reference", "key", "words"), [
    ("Ash-Shura 42:51", "42:51", 22), ("An-Nahl 16:36", "16:36", 28), ("As-Sajdah 32:2–3", "32:2-3", 26),
    ("Al-Baqarah 2:23", "2:23", 20), ("An-Nisa 4:82", "4:82", 13), ("Sad 38:86", "38:86", 10),
    ("Al-Anam 6:162–163", "6:162-163", 17), ("Ali Imran 3:19", "3:19", 26),
])
def test_unit0_references_resolve(mushaf: Mushaf, reference: str, key: str, words: int) -> None:
    passage = mushaf.resolve(reference)
    assert passage.key == key and len(passage.words) == words


def test_matching_on_real_text(mushaf: Mushaf) -> None:
    keys = {m.passage.key for m in mushaf.find_exact("فأقيموا الصلاة")}
    assert "4:103#w12-13" in keys
    assert [m.passage.key for m in mushaf.find_exact("كتابا موقوتا")] == ["4:103#w19-20"]
    fuzzy = mushaf.find_fuzzy("إن الصلاة كانت على المؤمنين كتابا مفروضا")
    assert fuzzy is not None and fuzzy.passage.key == "4:103"
