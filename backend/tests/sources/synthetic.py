"""A synthetic mushaf for tests: neutral Arabic sentences in the KFGQPC record format, deliberately NOT scripture.

CI has no copy of the canonical dataset (its redistribution terms are pending, D-88), and engineers never type
scripture, so every mushaf behaviour is exercised on this stand-in. ``synthetic=True`` marks the spec; nothing in
the application can load it (``get_mushaf`` reads only the manifest's datasets).
"""

from __future__ import annotations

import hashlib
import json

from app.sources.mushaf import DatasetSpec, Mushaf

# (surah name ar, surah name en, [ayah texts with harakat/annotation marks]).
SURAHS = [
    ("الدَّرسِ", "Ad-Dars", [
        "ذَهَبَ ٱلطَّالِبُ إِلَى ٱلۡمَدۡرَسَةِ صَبَاحࣰا",
        "وَقَرَأَ ٱلۡكِتَابَ مَعَ أَصۡدِقَائِهِ ۚ ثُمَّ رَجَعَ",
        "۞ وَكَتَبَ ٱلدَّرۡسَ فِي دَفۡتَرِهِ ٱلۡجَدِيدِ",
    ]),
    ("الحَدِيقَةِ", "Al-Hadiqah", [
        "فِي ٱلۡحَدِيقَةِ شَجَرَةٌ كَبِيرَةٌ",
        "يَجۡلِسُ تَحۡتَهَا ٱلۡأَطۡفَالُ لِلرَّاحَةِ",
        "وَيَلۡعَبُونَ بِٱلۡكُرَةِ حَتَّىٰ ٱلۡمَسَاءِ",
        "ثُمَّ يَعُودُونَ إِلَى بُيُوتِهِمۡ مَسۡرُورِينَ بِٱلۡحَيَوٰةِ",
    ]),
]

IMLAEI = {
    (1, 1): "ذهب الطالب إلى المدرسة صباحا",
    (1, 2): "وقرأ الكتاب مع أصدقائه ثم رجع",
    (1, 3): "وكتب الدرس في دفتره الجديد",
    (2, 1): "في الحديقة شجرة كبيرة",
    (2, 2): "يجلس تحتها الأطفال للراحة",
    (2, 3): "ويلعبون بالكرة حتى المساء",
    (2, 4): "ثم يعودون إلى بيوتهم مسرورين بالحياة",
}


def records() -> list[dict[str, object]]:
    out: list[dict[str, object]] = []
    for s, (name_ar, name_en, ayahs) in enumerate(SURAHS, start=1):
        for a, text in enumerate(ayahs, start=1):
            number = "".join("٠١٢٣٤٥٦٧٨٩"[int(d)] for d in str(a))
            out.append({"id": len(out) + 1, "sura_no": s, "sura_name_ar": name_ar, "sura_name_en": name_en,
                        "aya_no": a, "aya_text_unicode": f"{text} ۝{number}", "aya_text_emlaey": IMLAEI[(s, a)]})
    return out


def payload() -> bytes:
    return json.dumps(records(), ensure_ascii=False).encode("utf-8")


def spec(data: bytes | None = None) -> DatasetSpec:
    data = payload() if data is None else data
    return DatasetSpec(id="synthetic_test", title="Synthetic test text (not scripture)", publisher="tests",
                       riwaya="none", version="0", member="synthetic.json",
                       member_sha256=hashlib.sha256(data).hexdigest(), ayah_count=len(records()),
                       authority="tests only", citation="نص تجريبي", redistribution="permitted",
                       synthetic=True)


def mushaf() -> Mushaf:
    return Mushaf.from_records(records(), spec())
