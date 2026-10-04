"""The canonical mushaf, held in memory (SOURCE_ADAPTERS §12, §12.1; D-88).

Qur'an text is never typed, generated or taken from a provider response: it comes from one digest-pinned
dataset named in ``content/sources/mushaf.yaml`` (the King Fahd Complex's Hafs data, the organizers' approved
edition). The loader refuses a file whose SHA-256 differs from the manifest.

* :meth:`Mushaf.get` resolves a reference (surah, ayah range, optional word segment) to the canonical text.
* :meth:`Mushaf.find_exact` locates a quotation whose normalized words equal canonical words (``quran_exact``).
* :meth:`Mushaf.find_fuzzy` proposes the closest passage for a misquotation (``quran_inexact`` + correct text).
  It only *locates*; nothing is ever corrected or inserted from a fuzzy match (insertion goes through ``get``).

Words are the whitespace-separated tokens of the Uthmani text that keep a letter after normalization, so
waqf marks stay attached to their word and standalone marks are not words; the ayah-end glyph and number are
not part of the text.
"""

from __future__ import annotations

import hashlib
import json
import re
import unicodedata
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field
from functools import cached_property
from pathlib import Path
from typing import Any, Literal

import yaml
from pydantic import BaseModel, ConfigDict
from rapidfuzz import fuzz, process

from app.config import BACKEND_DIR, Settings
from app.sources.normalize import normalize_ar

MANIFEST = BACKEND_DIR / "content" / "sources" / "mushaf.yaml"
SURAHS = 114
FUZZY_THRESHOLD = 85            # §12.1: rapidfuzz partial_ratio on normalized text
FUZZY_MIN_CHARS = 12            # shorter quotations cannot be located reliably
FUZZY_WINDOW = 5                # consecutive ayahs considered together for multi-ayah quotations
FUZZY_MIN_COVER = 0.9           # a candidate window is at least this fraction of the quotation's length
_AYAH_END = re.compile("\\s*\u06dd[\u0660-\u0669\u06f0-\u06f90-9]*\\s*$")


class MushafError(RuntimeError):
    """The mushaf dataset is missing, altered or malformed."""


class ReferenceNotFound(LookupError):
    """The reference does not exist in the canonical mushaf (or its name contradicts its number)."""


class DatasetSpec(BaseModel):
    """One mushaf dataset as pinned in the manifest. ``synthetic`` datasets exist only inside tests."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    id: str
    title: str
    publisher: str
    riwaya: str
    version: str
    url: str | None = None
    archive_sha256: str | None = None
    member: str
    member_sha256: str
    ayah_count: int
    authority: str
    redistribution: Literal["pending", "permitted", "not_permitted"]
    synthetic: bool = False

    def provenance(self) -> dict[str, Any]:
        return {"dataset": self.id, "publisher": self.publisher, "riwaya": self.riwaya, "version": self.version,
                "sha256": self.member_sha256, "url": self.url}


def load_manifest(path: Path = MANIFEST) -> tuple[str, dict[str, DatasetSpec]]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if data.get("schema") != "qabas.mushaf_datasets/1":
        raise MushafError(f"{path}: unknown manifest schema")
    specs = {key: DatasetSpec(id=key, **value) for key, value in data["datasets"].items()}
    if data["canonical"] not in specs:
        raise MushafError(f"{path}: canonical dataset {data['canonical']!r} is not declared")
    return data["canonical"], specs


@dataclass(frozen=True)
class Ayah:
    surah: int
    number: int
    text: str                       # canonical Uthmani text without the ayah-end glyph
    imlaei: str                     # the dataset's own standard-orthography rendering (matching only)
    words: tuple[str, ...]          # Uthmani words (waqf marks attached)
    norm: tuple[str, ...]           # normalized words, aligned 1:1 with ``words``
    norm_imlaei: tuple[str, ...]


@dataclass(frozen=True)
class Surah:
    number: int
    name_ar: str
    name_en: str
    ayahs: tuple[Ayah, ...]


@dataclass(frozen=True)
class WordRef:
    ayah: int
    position: int                   # 1-based within its ayah
    text: str


@dataclass(frozen=True)
class Passage:
    """Canonical text for a reference. ``word_start``/``word_end`` are set for a segment of one ayah."""

    surah: int
    surah_name_ar: str
    surah_name_en: str
    ayah_start: int
    ayah_end: int
    word_start: int | None
    word_end: int | None
    text_uthmani: str
    words: tuple[WordRef, ...]
    dataset: DatasetSpec

    @property
    def key(self) -> str:
        span = f"{self.surah}:{self.ayah_start}" + (f"-{self.ayah_end}" if self.ayah_end != self.ayah_start else "")
        if self.word_start is not None:
            span += f"#w{self.word_start}-{self.word_end}"
        return span

    @property
    def text_sha256(self) -> str:
        return hashlib.sha256(self.text_uthmani.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class ExactMatch:
    passage: Passage
    form: Literal["uthmani", "imlaei"]   # which canonical rendering the quotation matched


@dataclass(frozen=True)
class FuzzyMatch:
    passage: Passage                      # the correct canonical text (``correct_text``)
    score: float


@dataclass(frozen=True)
class _Stream:
    """A surah's normalized words in one rendering, with each word's (ayah, 1-based position)."""

    text: str
    index: dict[int, int]                 # character offset in ``text`` -> word index
    owners: tuple[tuple[int, int], ...]


@dataclass
class Mushaf:
    dataset: DatasetSpec
    surahs: tuple[Surah, ...]
    _streams: dict[tuple[int, str], _Stream] = field(default_factory=dict, repr=False)

    # ---------------------------------------------------------------- loading
    @classmethod
    def load(cls, path: Path, spec: DatasetSpec) -> Mushaf:
        if not path.is_file():
            raise MushafError(f"mushaf dataset {spec.id} is not installed at {path} "
                              "(run scripts/fetch_mushaf.py)")
        raw = path.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        if digest != spec.member_sha256:
            raise MushafError(f"mushaf dataset {spec.id}: SHA-256 {digest} does not match the pinned "
                              f"{spec.member_sha256}; refusing to load altered scripture")
        return cls.from_records(json.loads(raw.decode("utf-8")), spec)

    @classmethod
    def from_records(cls, records: Sequence[dict[str, Any]], spec: DatasetSpec) -> Mushaf:
        """Build from KFGQPC-format records (``sura_no``, ``aya_no``, ``aya_text_unicode``, …)."""
        by_surah: dict[int, list[dict[str, Any]]] = {}
        for record in records:
            by_surah.setdefault(int(record["sura_no"]), []).append(record)
        if len(records) != spec.ayah_count:
            raise MushafError(f"{spec.id}: {len(records)} ayahs, manifest says {spec.ayah_count}")
        expected = range(1, SURAHS + 1) if not spec.synthetic else range(1, len(by_surah) + 1)
        if sorted(by_surah) != list(expected):
            raise MushafError(f"{spec.id}: surah numbering is not contiguous")
        surahs = []
        for number in expected:
            rows = sorted(by_surah[number], key=lambda r: int(r["aya_no"]))
            if [int(r["aya_no"]) for r in rows] != list(range(1, len(rows) + 1)):
                raise MushafError(f"{spec.id}: surah {number} ayah numbering is not contiguous")
            surahs.append(Surah(number, rows[0]["sura_name_ar"], rows[0]["sura_name_en"],
                                tuple(_ayah(number, r) for r in rows)))
        return cls(spec, tuple(surahs))

    # ---------------------------------------------------------------- lookup
    def surah(self, number: int) -> Surah:
        if not 1 <= number <= len(self.surahs):
            raise ReferenceNotFound(f"surah {number} does not exist")
        return self.surahs[number - 1]

    def get(self, surah: int, ayah_start: int, ayah_end: int | None = None, *,
            word_start: int | None = None, word_end: int | None = None) -> Passage:
        s = self.surah(surah)
        ayah_end = ayah_start if ayah_end is None else ayah_end
        if not 1 <= ayah_start <= ayah_end <= len(s.ayahs):
            raise ReferenceNotFound(f"{surah}:{ayah_start}-{ayah_end} is outside surah {surah} "
                                    f"({len(s.ayahs)} ayahs)")
        ayahs = s.ayahs[ayah_start - 1:ayah_end]
        if (word_start is None) != (word_end is None):
            raise ReferenceNotFound("a segment needs both word_start and word_end")
        if word_start is not None and word_end is not None:
            if ayah_start != ayah_end:
                raise ReferenceNotFound("a word segment lies within one ayah")
            count = len(ayahs[0].words)
            if not 1 <= word_start <= word_end <= count:
                raise ReferenceNotFound(f"words {word_start}-{word_end} are outside {surah}:{ayah_start} "
                                        f"({count} words)")
            words = tuple(WordRef(ayah_start, i, ayahs[0].words[i - 1]) for i in range(word_start, word_end + 1))
            text = " ".join(w.text for w in words)
        else:
            words = tuple(WordRef(a.number, i, w) for a in ayahs for i, w in enumerate(a.words, start=1))
            text = " ".join(a.text for a in ayahs)
        return Passage(surah, s.name_ar, s.name_en, ayah_start, ayah_end, word_start, word_end, text, words,
                       self.dataset)

    def resolve(self, reference: str) -> Passage:
        """``"Al-An'am 6:162-163"`` / ``"6:162"`` → the canonical passage. A surah name, when given, must agree
        with the number; a contradiction is an authoring error and is refused rather than guessed."""
        match = _REFERENCE.fullmatch(unicodedata.normalize("NFKC", reference).strip())
        if match is None:
            raise ReferenceNotFound(f"unreadable Qur'an reference {reference!r}")
        name, surah, start, end = match["name"], int(match["surah"]), int(match["start"]), match["end"]
        if name:
            expected = _latin_key(self.surah(surah).name_en)
            if fuzz.ratio(_latin_key(name), expected) < 80:
                raise ReferenceNotFound(f"{reference!r}: the name does not match surah {surah} "
                                        f"({self.surah(surah).name_en})")
        return self.get(surah, start, int(end) if end else None)

    # ---------------------------------------------------------------- matching
    def find_exact(self, text: str) -> list[ExactMatch]:
        """Every place whose consecutive normalized words equal the quotation's (Uthmani, then the dataset's
        standard-orthography rendering). Word positions are reported only where they are certain."""
        query = normalize_ar(text)
        if not query:
            return []
        found: list[ExactMatch] = []
        for form in ("uthmani", "imlaei"):
            for s in self.surahs:
                stream = self._stream(s.number, form)
                padded, offset = f" {stream.text} ", 0
                while (at := padded.find(f" {query} ", offset)) >= 0:
                    offset = at + 1
                    first = stream.index[at]
                    last = first + query.count(" ")
                    (a1, w1), (a2, w2) = stream.owners[first], stream.owners[last]
                    found.append(ExactMatch(self._span(s, a1, w1, a2, w2), form))
            if found:
                break
        return found

    def find_fuzzy(self, text: str, candidates: Iterable[tuple[int, int]] | None = None,
                   threshold: float = FUZZY_THRESHOLD) -> FuzzyMatch | None:
        """The closest canonical passage (``partial_ratio`` ≥ threshold on normalized text), or None.

        ``candidates`` are (surah, ayah) hints from ``quran.search``; without them the whole mushaf is scanned
        locally, so locating a misquotation never depends on a provider being up."""
        query = normalize_ar(text)
        if len(query) < FUZZY_MIN_CHARS:
            return None
        allowed = None if candidates is None else self._allowed(candidates)
        best: tuple[float, tuple[int, int, int]] | None = None
        # Smallest window first: a larger window only wins with a strictly better score, so the correct text
        # never carries neighbouring ayahs the quotation did not touch.
        # partial_ratio aligns the shorter string inside the longer one, so a window shorter than the quotation
        # (e.g. «الم») would score 100 against any quotation containing it: windows must be long enough.
        minimum = FUZZY_MIN_COVER * len(query)
        for size in range(1, FUZZY_WINDOW + 1):
            windows = [w for w in self._windows[size]
                       if len(w[1]) >= minimum and (allowed is None or not allowed.isdisjoint(w[2]))]
            if not windows:
                continue
            hit = process.extractOne(query, [w[1] for w in windows], scorer=fuzz.partial_ratio,
                                     score_cutoff=threshold)
            if hit is not None and (best is None or hit[1] > best[0]):
                best = (float(hit[1]), windows[hit[2]][0])
        if best is None:
            return None
        surah, start, end = self._trim(query, *best[1])
        return FuzzyMatch(self.get(surah, start, end), best[0])

    # ---------------------------------------------------------------- internals
    def _span(self, s: Surah, a1: int, w1: int, a2: int, w2: int) -> Passage:
        """Word position 0 means "somewhere in this ayah" (a rendering not aligned word-for-word)."""
        whole = w1 <= 1 and w2 in (0, len(s.ayahs[a2 - 1].norm))
        if a1 == a2 and w1 and w2 and not whole:
            return self.get(s.number, a1, word_start=w1, word_end=w2)
        return self.get(s.number, a1, a2)

    def _stream(self, surah: int, form: str) -> _Stream:
        key = (surah, form)
        if key not in self._streams:
            words: list[str] = []
            owners: list[tuple[int, int]] = []
            for a in self.surah(surah).ayahs:
                norm = a.norm if form == "uthmani" else a.norm_imlaei
                aligned = form == "uthmani" or len(a.norm_imlaei) == len(a.norm)
                for i, w in enumerate(norm, start=1):
                    words.append(w)
                    # Imla'i words that do not align 1:1 with the Uthmani words own the whole ayah.
                    owners.append((a.number, i if aligned else 0))
            index, offset = {}, 0
            for i, w in enumerate(words):
                index[offset] = i
                offset += len(w) + 1
            self._streams[key] = _Stream(" ".join(words), index, tuple(owners))
        return self._streams[key]

    def _trim(self, query: str, surah: int, start: int, end: int) -> tuple[int, int, int]:
        """Drop edge ayahs of a multi-ayah window that the aligned quotation covers less than half of."""
        if start == end:
            return surah, start, end
        ayahs = self.surah(surah).ayahs[start - 1:end]
        text = " ".join(" ".join(a.norm) for a in ayahs)
        alignment = fuzz.partial_ratio_alignment(query, text)
        if len(query) <= len(text):
            lo, hi = alignment.dest_start, alignment.dest_end
        else:
            lo, hi = alignment.src_start, alignment.src_end
        kept, offset = [], 0
        for a in ayahs:
            length = len(" ".join(a.norm))
            overlap = max(0, min(hi, offset + length) - max(lo, offset))
            if overlap * 2 >= length:
                kept.append(a.number)
            offset += length + 1
        return (surah, min(kept), max(kept)) if kept else (surah, start, end)

    @cached_property
    def _windows(self) -> dict[int, list[tuple[tuple[int, int, int], str, frozenset[tuple[int, int]]]]]:
        """Per window size: ((surah, first, last), normalized text, the (surah, ayah) pairs it covers)."""
        out: dict[int, list[tuple[tuple[int, int, int], str, frozenset[tuple[int, int]]]]] = {}
        for size in range(1, FUZZY_WINDOW + 1):
            out[size] = [((s.number, span[0].number, span[-1].number), " ".join(w for a in span for w in a.norm),
                          frozenset((s.number, a.number) for a in span))
                         for s in self.surahs for i in range(len(s.ayahs) - size + 1)
                         for span in (s.ayahs[i:i + size],)]
        return out

    def _allowed(self, candidates: Iterable[tuple[int, int]]) -> frozenset[tuple[int, int]]:
        return frozenset((int(s), int(a)) for s, a in candidates)


_REFERENCE = re.compile(r"(?:(?P<name>[^\d:]+?)\s+)?(?P<surah>\d{1,3})\s*:\s*(?P<start>\d{1,3})"
                        r"(?:\s*[-\u2010-\u2015]\s*(?P<end>\d{1,3}))?")


def _latin_key(name: str) -> str:
    decomposed = unicodedata.normalize("NFKD", name.casefold())
    return "".join(ch for ch in decomposed if "a" <= ch <= "z")


def _ayah(surah: int, record: dict[str, Any]) -> Ayah:
    text = _AYAH_END.sub("", record["aya_text_unicode"]).strip()
    words, norm = [], []
    for token in text.split():
        n = normalize_ar(token)
        if not n:
            continue  # a standalone mark (e.g. ۞) is not a word
        if " " in n:
            raise MushafError(f"{surah}:{record['aya_no']}: word {token!r} normalizes to several words")
        words.append(token)
        norm.append(n)
    if not words:
        raise MushafError(f"{surah}:{record['aya_no']}: no words")
    return Ayah(surah, int(record["aya_no"]), text, record.get("aya_text_emlaey", ""), tuple(words), tuple(norm),
                tuple(normalize_ar(record.get("aya_text_emlaey", "")).split()))


_LOADED: dict[tuple[Path, str], Mushaf] = {}


def get_mushaf(settings: Settings) -> Mushaf:
    """The canonical mushaf for this process, loaded once (§12: held in memory)."""
    canonical, specs = load_manifest()
    spec = specs[canonical]
    path = settings.mushaf_dir / f"{spec.id}.json"
    key = (path, spec.member_sha256)
    if key not in _LOADED:
        _LOADED[key] = Mushaf.load(path, spec)
    return _LOADED[key]
