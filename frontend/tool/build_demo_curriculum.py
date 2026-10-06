#!/usr/bin/env python3
"""Builds the mock demo curriculum and its journeys.

    python3 tool/build_demo_curriculum.py [--unit0-plans <UNIT_0_CONTENT/lessons>]

Writes:
  assets/mocks/demo_curriculum/curriculum.json   the mock backend's curriculum (units, lessons, prerequisites,
                                                  standalone flags, session file per variant)
  assets/mocks/demo_curriculum/journey_initial_{ar,en}_{explorer,new_muslim}.json
                                                  GET /journey for a fresh learner (validated against the contract)

`compute_journey()` is the reference algorithm the Dart mock journey handler ports: lesson access comes only
from prerequisites (Soft Lock), never from curriculum position (API §6.3, backend §6.1).

Sources: Unit 0 plans (prerequisite/introduced concept IDs) from the backend's UNIT_0_CONTENT authoring
packages; Unit 0 sessions from the frontend demo handoff (assets/mocks/unit0/); lesson 1.1 from TEST_LESSONS
(assets/mocks/test_lessons/); unit titles from docs/contract/01_PRODUCT/CURRICULUM_AND_LEARNING_DESIGN.md and
the API journey example. Where no Arabic title exists, the English working title is used (never invented).
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MOCKS = ROOT / "assets/mocks"
OUT = MOCKS / "demo_curriculum"
DEFAULT_PLANS = Path("/Users/aw/Documents/qpr/FINAL_ENGINEERING_HANDOFF 2/FINAL_ENGINEERING_HANDOFF/UNIT_0_CONTENT/lessons")

COMING_SOON = {"ar": "قريباً", "en": "Coming soon"}
# unit_id, index, tracks, title {ar,en}, subtitle {ar,en} (or per track), art_key
UNITS = [
    ("unit_0", 0, ["explorer"], {"ar": "ابدأ بسؤال", "en": "Start With a Question"},
     {"ar": "أسس قبل الأسئلة الكبرى", "en": "Foundations before the big questions"}, "unit_big_questions"),
    ("unit_1", 1, ["explorer", "new_muslim"], {"ar": "الخطوة الأولى", "en": "The First Step"},
     {"explorer": {"ar": "فهم الخطوة الأولى في الإسلام", "en": "Understanding the First Step into Islam"},
      "new_muslim": {"ar": "خطواتك الأولى مع الله", "en": "Your First Steps with Allah"}}, "unit_first_steps"),
    ("unit_2", 2, ["explorer", "new_muslim"], {"ar": "معرفة الله", "en": "Knowing Allah"}, None, None),
    ("unit_3", 3, ["explorer", "new_muslim"], {"ar": None, "en": "Prayer: Your Daily Connection"}, None, None),
    ("unit_4", 4, ["explorer", "new_muslim"], {"ar": None, "en": "Living the Five Pillars"}, None, None),
    ("unit_5", 5, ["explorer", "new_muslim"], {"ar": None, "en": "What Muslims Believe"}, None, None),
    ("unit_6", 6, ["explorer", "new_muslim"], {"ar": None, "en": "The Qur'an"}, None, None),
    ("unit_7", 7, ["explorer", "new_muslim"], {"ar": "رسالة واحدة وأنبياء كثيرون", "en": "One Message, Many Prophets"}, None, None),
    ("unit_8", 8, ["explorer", "new_muslim"], {"ar": None, "en": "The Life of Muhammad ﷺ"}, None, None),
    ("unit_9", 9, ["explorer", "new_muslim"], {"ar": None, "en": "Islam in Everyday Life"}, None, None),
    ("unit_10", 10, ["explorer", "new_muslim"], {"ar": "ما بعد الأساسيات", "en": "Beyond the Basics"}, None, None),
]


def rel(p: Path) -> str:
    return str(p.relative_to(MOCKS))


def build_curriculum(plans_dir: Path) -> dict:
    index = json.loads((MOCKS / "unit0/SESSION_INDEX.json").read_text(encoding="utf-8"))
    by_lesson: dict[str, dict] = {}
    for s in index["sessions"]:
        by_lesson.setdefault(s["lesson_id"], {"authoring": s["authoring_lesson_id"], "files": {}})["files"][s["variant"]] = s["path"]

    # concept → introducing lesson, then concept prerequisites → lesson prerequisites
    plans = {}
    for lesson_id, info in by_lesson.items():
        num = int(lesson_id.rsplit("_l", 1)[1])
        plans[lesson_id] = json.loads((plans_dir / f"u0_l{num:02d}.json").read_text(encoding="utf-8"))["plan"]
    introduced = {c: lid for lid, p in plans.items() for c in p["introduced_concept_ids"]}

    unit0_lessons = []
    for lesson_id in sorted(by_lesson, key=lambda x: int(x.rsplit("_l", 1)[1])):
        info, plan = by_lesson[lesson_id], plans[lesson_id]
        sessions = {v: f"unit0/{p}" for v, p in sorted(info["files"].items())}
        titles = {}
        for variant, path in sessions.items():
            titles[variant.split("_", 1)[0]] = json.loads((MOCKS / path).read_text(encoding="utf-8"))["title"]
        prereq_lessons = sorted({introduced[c] for c in plan["prerequisite_concept_ids"]}, key=lambda x: int(x.rsplit("_l", 1)[1]))
        unit0_lessons.append({
            "lesson_id": lesson_id, "index": int(lesson_id.rsplit("_l", 1)[1]) - 1, "title": titles,
            "lesson_type": plan["lesson_type"], "estimated_minutes": plan["estimated_minutes"], "xp": 15,
            "standalone_eligible": plan["standalone_eligible"], "prerequisite_lesson_ids": prereq_lessons,
            "sessions": sessions,
        })

    l11 = {}
    for f in sorted((MOCKS / "test_lessons").glob("u1l1_*.json")):
        variant = f.stem.split("_", 1)[1]
        l11[variant] = rel(f)
    l11_titles = {lang: json.loads((MOCKS / l11[f"{lang}_explorer"]).read_text(encoding="utf-8"))["title"] for lang in ("ar", "en")}
    unit1_lessons = [{
        "lesson_id": "les_u1_l1", "index": 0, "title": l11_titles, "lesson_type": "concept", "estimated_minutes": 9, "xp": 15,
        "standalone_eligible": True, "prerequisite_lesson_ids": [], "sessions": l11,
    }]

    units = []
    for unit_id, idx, tracks, title, subtitle, art in UNITS:
        lessons = unit0_lessons if unit_id == "unit_0" else unit1_lessons if unit_id == "unit_1" else []
        units.append({
            "unit_id": unit_id, "index": idx, "tracks": tracks, "title": title,
            "subtitle": subtitle if subtitle else COMING_SOON, "art_key": art, "has_guide": False,
            "coming_soon": not lessons, "lessons": lessons,
        })
    return {
        "_mock_role": "mock demo curriculum (unpublished review drafts; owner decisions 2026-10-04)",
        "_mock_notes": [
            "Unit 0 = the 12 backend Unit 0 lessons (Explorer only); Unit 1 = lesson 1.1 from TEST_LESSONS; Units 2-10 coming soon.",
            "Salah (les_u1_l3) is NOT in the journey: it opens only from the developer menu preview (backend reply item 4).",
            "Titles with ar = null fall back to English (no approved Arabic title exists yet). The Unit 0 English subtitle is a working translation of the Arabic API example.",
            "No unit tests or guides are served for these units (can_skip false, has_guide false).",
        ],
        "units": units,
    }


def text(value: dict, lang: str) -> str:
    return value.get(lang) or value["en"]


def compute_journey(cur: dict, lang: str, track: str, completed=frozenset(), in_progress=frozenset()) -> dict:
    """GET /journey for a learner. completed/in_progress: sets of lesson IDs."""
    units = [u for u in cur["units"] if track in u["tracks"]]
    lessons = [(u, l) for u in units for l in u["lessons"]]
    order = {l["lesson_id"]: i for i, (_, l) in enumerate(lessons)}
    by_id = {l["lesson_id"]: (u, l) for u, l in lessons}

    def openable(lid: str) -> bool:
        return all(p in completed for p in by_id[lid][1]["prerequisite_lesson_ids"])

    def ref(lid: str) -> dict:
        u, l = by_id[lid]
        return {"lesson_id": lid, "unit_id": u["unit_id"], "title": text(l["title"], lang)}

    def start_with(lid: str) -> str:
        # earliest openable, not completed lesson on the dependency path of `lid`
        seen, stack, path = set(), list(by_id[lid][1]["prerequisite_lesson_ids"]), []
        while stack:
            p = stack.pop()
            if p in seen or p in completed:
                continue
            seen.add(p)
            path.append(p)
            stack.extend(by_id[p][1]["prerequisite_lesson_ids"])
        return min((p for p in path if openable(p)), key=order.__getitem__)

    out_units, current = [], None
    for u in units:
        jl = []
        for l in u["lessons"]:
            lid = l["lesson_id"]
            if lid in completed:
                state = "completed"
            elif lid in in_progress:
                state = "in_progress"
            elif openable(lid):
                state = "available"
            else:
                state = "locked"
            unmet = [p for p in l["prerequisite_lesson_ids"] if p not in completed]
            jl.append({
                "lesson_id": lid, "index": l["index"], "title": text(l["title"], lang), "lesson_type": l["lesson_type"],
                "state": state, "estimated_minutes": l["estimated_minutes"], "xp": l["xp"],
                "standalone_eligible": l["standalone_eligible"],
                "soft_lock": None if state != "locked" else {
                    "prerequisites": [ref(p) for p in sorted(unmet, key=order.__getitem__)],
                    "start_with": ref(start_with(lid)),
                },
            })
            if current is None and state in ("available", "in_progress"):
                current = {"unit_id": u["unit_id"], "lesson_id": lid}
        states = [x["state"] for x in jl]
        if u["coming_soon"] or not jl:
            ustate = "locked"
        elif all(s == "completed" for s in states):
            ustate = "completed"  # mock simplification: no unit tests are served for these units
        elif any(s in ("in_progress", "completed") for s in states):
            ustate = "in_progress"
        elif any(s != "locked" for s in states):
            ustate = "available"
        else:
            ustate = "locked"
        sub = u["subtitle"].get(track, u["subtitle"]) if "explorer" in u["subtitle"] else u["subtitle"]
        out_units.append({
            "unit_id": u["unit_id"], "index": u["index"], "title": text(u["title"], lang), "subtitle": text(sub, lang),
            "art_key": u["art_key"], "has_guide": u["has_guide"], "state": ustate, "coming_soon": u["coming_soon"],
            "pretest": {"state": "not_taken"},
            "unit_test": {"state": "not_passed", "best_percent": None, "pass_percent": 80, "can_skip": False},
            "lessons": jl,
        })
    return {"track": track, "current": current, "units": out_units}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--unit0-plans", type=Path, default=DEFAULT_PLANS)
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    cur = build_curriculum(args.unit0_plans)
    (OUT / "curriculum.json").write_text(json.dumps(cur, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    for lang in ("ar", "en"):
        for track in ("explorer", "new_muslim"):
            j = compute_journey(cur, lang, track)
            (OUT / f"journey_initial_{lang}_{track}.json").write_text(json.dumps(j, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    n = sum(len(u["lessons"]) for u in cur["units"])
    print(f"curriculum: {len(cur['units'])} units, {n} lessons → {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
