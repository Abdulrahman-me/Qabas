"""normalize_ar (§12.1) and the mushaf loader/lookup/matching, on the synthetic stand-in text (never scripture)."""

from __future__ import annotations

from pathlib import Path

import pytest

from app.sources.mushaf import Mushaf, MushafError, ReferenceNotFound, load_manifest
from app.sources.normalize import normalize_ar, tokens
from tests.sources import synthetic


# ---------------------------------------------------------------- normalize_ar
@pytest.mark.parametrize(("raw", "expected"), [
    ("ٱلۡكِتَٰبُ", "الكتب"),                              # harakat, small marks, dagger alef, wasla
    ("أَإِآٱ", "\u0627" * 4),                              # alef variants
    ("مُوسَىٰ", "موسي"), ("صَلَاةٌ", "صلاه"),              # alef maqsura, ta marbuta
    ("مُؤۡمِن", "مومن"), ("قَائِم", "قايم"),               # hamza carriers
    ("قِيَٰمࣰا", "قيما"),                                   # KFGQPC open tanween U+08F0 (F-66)
    ("كـــتاب", "كتاب"),                                   # tatweel
    ("قال: «نعم»، ثم ذهب.", "قال نعم ثم ذهب"),            # punctuation separates words
    ("الكتاب ۝١٢", "الكتاب"), ("\ufd3f" + "الكتاب" + "\ufd3e", "الكتاب"),  # ayah-end, number, brackets
    ("  كلمة‌  أخرى\n", "كلمه اخري"),                 # zero-width, whitespace
    ("ﻻ", "لا"),                                            # presentation forms (NFKC)
])
def test_normalize_ar(raw: str, expected: str) -> None:
    assert normalize_ar(raw) == expected


def test_tokens_drop_standalone_marks() -> None:
    assert tokens("۞ وَكَتَبَ ۚ ٱلدَّرۡسَ") == ["وكتب", "الدرس"]


# ---------------------------------------------------------------- loading
def test_load_verifies_the_pinned_digest(tmp_path: Path) -> None:
    data = synthetic.payload()
    path = tmp_path / "m.json"
    path.write_bytes(data)
    assert len(Mushaf.load(path, synthetic.spec(data)).surahs) == 2
    path.write_bytes(data.replace("صَبَاحࣰا".encode(), "مَسَاءࣰ".encode()))
    assert path.read_bytes() != data
    with pytest.raises(MushafError, match="does not match the pinned"):
        Mushaf.load(path, synthetic.spec(data))
    with pytest.raises(MushafError, match="not installed"):
        Mushaf.load(tmp_path / "missing.json", synthetic.spec(data))


def test_load_rejects_structural_damage() -> None:
    records = synthetic.records()
    with pytest.raises(MushafError, match="manifest says"):
        Mushaf.from_records(records[:-1], synthetic.spec())
    broken = [dict(r) for r in records]
    broken[1]["aya_no"] = 5
    with pytest.raises(MushafError, match="not contiguous"):
        Mushaf.from_records(broken, synthetic.spec())


def test_the_manifest_pins_the_canonical_dataset() -> None:
    canonical, specs = load_manifest()
    spec = specs[canonical]
    assert canonical == "kfgqpc_hafs_v30" and spec.ayah_count == 6236 and not spec.synthetic
    assert len(spec.member_sha256) == 64 and len(spec.archive_sha256 or "") == 64
    assert spec.redistribution == "pending"   # O-03: fetched by digest, never committed


# ---------------------------------------------------------------- get / resolve
def test_get_whole_ayahs_and_segments() -> None:
    m = synthetic.mushaf()
    p = m.get(1, 2)
    assert p.text_uthmani == "وَقَرَأَ ٱلۡكِتَابَ مَعَ أَصۡدِقَائِهِ ۚ ثُمَّ رَجَعَ"   # ayah-end glyph removed
    assert [w.text for w in p.words][-2:] == ["ثُمَّ", "رَجَعَ"] and len(p.words) == 6   # «ۚ» is not a word
    p = m.get(1, 3)
    assert p.words[0].text == "وَكَتَبَ" and len(p.words) == 5                          # «۞» is not a word
    seg = m.get(2, 2, word_start=2, word_end=3)
    assert seg.text_uthmani == "تَحۡتَهَا ٱلۡأَطۡفَالُ" and seg.key == "2:2#w2-3"
    assert [(w.ayah, w.position) for w in seg.words] == [(2, 2), (2, 3)]
    multi = m.get(2, 1, 2)
    assert multi.key == "2:1-2" and multi.text_uthmani.count(" ") == len(multi.words) - 1
    assert len(seg.text_sha256) == 64


@pytest.mark.parametrize(("args", "kwargs"), [
    ((3, 1), {}), ((1, 0), {}), ((1, 4), {}), ((1, 2, 1), {}),
    ((2, 2), {"word_start": 3, "word_end": 2}), ((2, 2), {"word_start": 1, "word_end": 9}),
    ((2, 1, 2), {"word_start": 1, "word_end": 1}), ((2, 2), {"word_start": 1}),
])
def test_get_refuses_what_does_not_exist(args: tuple[int, ...], kwargs: dict[str, int]) -> None:
    with pytest.raises(ReferenceNotFound):
        synthetic.mushaf().get(*args, **kwargs)


def test_resolve_reference_checks_the_name_against_the_number() -> None:
    m = synthetic.mushaf()
    assert m.resolve("Al-Hadiqah 2:2\u20133").key == "2:2-3"
    assert m.resolve("2:4").key == "2:4"
    with pytest.raises(ReferenceNotFound, match="does not match"):
        m.resolve("Ad-Dars 2:1")
    with pytest.raises(ReferenceNotFound, match="unreadable"):
        m.resolve("Al-Hadiqah two")


# ---------------------------------------------------------------- find_exact
def test_find_exact_on_the_uthmani_text_reports_words() -> None:
    (match,) = synthetic.mushaf().find_exact("ٱلۡأَطۡفَالُ لِلرَّاحَةِ")
    assert match.form == "uthmani" and match.passage.key == "2:2#w3-4"


def test_find_exact_across_ayahs() -> None:
    (match,) = synthetic.mushaf().find_exact("حتى المساء ثم يعودون")
    assert match.passage.key == "2:3-4" and match.form == "uthmani"
    assert match.passage.text_uthmani.startswith("وَيَلۡعَبُونَ")   # correct text is the canonical rendering


def test_find_exact_on_the_dataset_standard_spelling() -> None:
    m = synthetic.mushaf()
    # «بالحياة» normalizes to «بالحياه»; the Uthmani «بِٱلۡحَيَوٰةِ» to «بالحيوه»: only the imla'i rendering matches.
    (match,) = m.find_exact("مسرورين بالحياة")
    assert match.form == "imlaei" and match.passage.key == "2:4#w5-6"
    (whole,) = m.find_exact("في الحديقة شجرة كبيرة")
    assert whole.passage.key == "2:1" and whole.passage.word_start is None


def test_find_exact_needs_whole_words_and_finds_every_occurrence() -> None:
    m = synthetic.mushaf()
    assert m.find_exact("الطال") == []                      # a word fragment is not an exact quotation
    assert {x.passage.surah for x in m.find_exact("ثم")} == {1, 2}
    assert m.find_exact("") == [] and m.find_exact("…") == []


# ---------------------------------------------------------------- find_fuzzy
def test_find_fuzzy_locates_a_misquotation_without_correcting_it() -> None:
    m = synthetic.mushaf()
    quote = "يجلس تحتها الأولاد للراحة"
    assert m.find_exact(quote) == []
    match = m.find_fuzzy(quote)
    assert match is not None and match.passage.key == "2:2" and 85 <= match.score < 100
    assert match.passage.text_uthmani == m.get(2, 2).text_uthmani   # the correct text comes from the mushaf


def test_find_fuzzy_returns_nothing_below_the_threshold_or_for_short_text() -> None:
    m = synthetic.mushaf()
    assert m.find_fuzzy("السيارة الحمراء تسير في الطريق السريع") is None
    assert m.find_fuzzy("الكرة") is None


def test_find_fuzzy_spans_ayahs_without_adding_untouched_neighbours() -> None:
    match = synthetic.mushaf().find_fuzzy("في الحديقه شجره كبيره يجلس تحتها الاطفال للراحه")
    assert match is not None and match.passage.key == "2:1-2"


def test_find_fuzzy_short_ayahs_do_not_swallow_longer_quotations() -> None:
    # A window much shorter than the quotation would otherwise score 100 (partial_ratio aligns the shorter one).
    match = synthetic.mushaf().find_fuzzy("ويلعبون بالكرة حتى المساء كل يوم بعد العصر مع الجيران")
    assert match is None or match.passage.key.startswith("2:3")


def test_find_fuzzy_candidates_restrict_the_search() -> None:
    m = synthetic.mushaf()
    quote = "يجلس تحتها الأولاد للراحة"
    assert m.find_fuzzy(quote, candidates=[(1, 1), (1, 2)]) is None
    match = m.find_fuzzy(quote, candidates=[(2, 2), (99, 1)])
    assert match is not None and match.passage.key == "2:2"
