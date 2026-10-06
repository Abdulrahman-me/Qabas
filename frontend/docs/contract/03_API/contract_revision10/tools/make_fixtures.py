"""Generates contract fixtures and validates each against contract/qabas_contract.py.

Outputs under fixtures/:
  exercises/<type>[__<presentation>]/{exercise,correct,incorrect,...}.json  per-type outcomes (§10.6)
  sessions/session_practice_all_types.json                                  every type + predict + framing
  scenes/session_test_scene_lesson.json                                     non-Salah lesson on a generated scene
  challenges/group_challenge.json, group_ws_script.json                     4 players, tie, timeout, disconnect
  curriculum_test/journey_{explorer,new_muslim}.json, lessons/*.json        3 units (unit 1 Explorer-only), both languages;
                                                                            prerequisite Soft Locks and standalone lessons

Test-curriculum text is synthetic ("نص اختباري" / "Test text") on purpose: it exercises journey and
renderer logic without inventing religious content. Exercise examples reuse reviewed contract content.
"""
import hashlib, json, pathlib, sys, copy

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "contract"))
import qabas_contract as C  # noqa: E402
from display_fields import backfill_legacy

OUT = ROOT / "fixtures"
written = []


def T(t):
    return [{"type": "text", "text": t}]


def save(rel, obj, model=None, many=False):
    obj = backfill_legacy(obj)
    if model is not None:
        for o in (obj if many else [obj]):
            model.model_validate(o)
    p = OUT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=1))
    written.append((rel, model.__name__ if model else "-"))


SC = lambda acc=True, combo=True, layer=None: {"accuracy": acc, "combo": combo, "layer": layer}
Q112_1 = {"evidence_id": "src_q_112_1", "kind": "quran", "quran": {"surah": 112, "surah_name": "الإخلاص", "ayah_start": 1, "ayah_end": 1, "segment": None, "text_uthmani": "قُلْ هُوَ اللَّهُ أَحَدٌ", "translation": None, "translation_source": None, "audio": None}, "hadith": None}
Q112_2 = copy.deepcopy(Q112_1); Q112_2["evidence_id"] = "src_q_112_2"; Q112_2["quran"].update(ayah_start=2, ayah_end=2, text_uthmani="اللَّهُ الصَّمَدُ")
H_NIYYAT = {"evidence_id": "src_h_niyyat", "kind": "hadith", "quran": None, "hadith": {"text_ar": "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى", "translation": None, "narrator": "عمر بن الخطاب رضي الله عنه", "collections": ["صحيح البخاري (1)", "صحيح مسلم (1907)"], "grade_label": "صحيح", "grade_category": "authentic", "grade_source": "متفق عليه", "excerpt": False}}
AUDIO_112_1 = {"reciter": "مشاري راشد العفاسي", "url": "mock-asset://audio/test_tone_112001.mp3", "words": [
    {"ayah": 1, "position": 1, "text": "قُلْ", "start_ms": 0, "end_ms": 520}, {"ayah": 1, "position": 2, "text": "هُوَ", "start_ms": 520, "end_ms": 900},
    {"ayah": 1, "position": 3, "text": "اللَّهُ", "start_ms": 900, "end_ms": 1650}, {"ayah": 1, "position": 4, "text": "أَحَدٌ", "start_ms": 1650, "end_ms": 2900}]}
RIVER = lambda beat: {"kind": "builtin", "key": "river_house", "version": 1, "params": {"beat": beat}, "image": None, "scene": None, "fallback_image": None, "fallback_params": None, "alt": "بيت ونخيل ونهر جارٍ", "overlays": []}
MAP = {"kind": "image", "key": None, "version": None, "params": None, "image": {"url": "mock-asset://maps/hijaz_test.webp", "mime_type": "image/webp", "width": 1600, "height": 1200}, "scene": None, "fallback_image": None, "fallback_params": None, "alt": "خريطة منطقة الحجاز بلا أسماء", "overlays": []}

# type -> (payload, answer, correct_answer, details_correct, details_incorrect, wrong_answer, scoring, misconception?)
D = {}
D["multiple_choice"] = dict(payload={"options": [{"option_id": "opt_a", "spans": T("أن الله واحد لا شريك له")}, {"option_id": "opt_b", "spans": T("أن الله أول الآلهة")}, {"option_id": "opt_c", "spans": T("أن الله خاص بالعرب")}]},
    key={"option_id": "opt_a"}, wrong={"option_id": "opt_c"}, det=(None, None), mis=True)
D["true_false_reason"] = dict(payload={"statement": T("يجب على كل من أسلم أن يغيّر اسمه."), "reasons": [{"option_id": "r_1", "spans": T("يُغيَّر الاسم فقط إذا كان معناه مخالفاً للإسلام.")}, {"option_id": "r_2", "spans": T("لأن الأسماء غير العربية لا تجوز.")}, {"option_id": "r_3", "spans": T("لأن تغيير الاسم من أركان الإسلام.")}]},
    key={"value": False, "reason_option_id": "r_1"}, wrong={"value": False, "reason_option_id": "r_2"},
    det=({"value_correct": True, "reason_correct": True}, {"value_correct": True, "reason_correct": False}), mis=True)
D["match_pairs"] = dict(payload={"left": [{"item_id": "l_1", "spans": T("الزكاة")}, {"item_id": "l_2", "spans": T("الصوم")}, {"item_id": "l_3", "spans": T("الحج")}],
    "right": [{"item_id": "r_1", "spans": T("قصد مكة لأداء المناسك")}, {"item_id": "r_2", "spans": T("مال يُعطى للمستحقين")}, {"item_id": "r_3", "spans": T("الامتناع عن الطعام والشراب من الفجر إلى المغرب")}]},
    key={"pairs": [{"left_id": "l_1", "right_id": "r_2"}, {"left_id": "l_2", "right_id": "r_3"}, {"left_id": "l_3", "right_id": "r_1"}]},
    wrong={"pairs": [{"left_id": "l_1", "right_id": "r_3"}, {"left_id": "l_2", "right_id": "r_2"}, {"left_id": "l_3", "right_id": "r_1"}]},
    det=({"pair_results": [{"left_id": "l_1", "correct": True}, {"left_id": "l_2", "correct": True}, {"left_id": "l_3", "correct": True}]},
         {"pair_results": [{"left_id": "l_1", "correct": False}, {"left_id": "l_2", "correct": False}, {"left_id": "l_3", "correct": True}]}))
D["flashcard"] = dict(payload={"front": T("ما معنى «التوحيد»؟"), "back": T("إفراد الله وحده بالعبادة، والإيمان بأنه واحد لا شريك له.")}, key=None, wrong=None, det=(None, None))
D["fill_blank"] = dict(payload={"segments": [{"type": "text", "text": "أركان الإسلام "}, {"type": "blank", "blank_id": "b_1"}, {"type": "text", "text": " أركان، أولها "}, {"type": "blank", "blank_id": "b_2"}, {"type": "text", "text": "."}],
    "word_bank": [{"word_id": "w_1", "text": "خمسة"}, {"word_id": "w_2", "text": "ستة"}, {"word_id": "w_3", "text": "الشهادتان"}, {"word_id": "w_4", "text": "الصوم"}]},
    key={"fills": [{"blank_id": "b_1", "word_id": "w_1"}, {"blank_id": "b_2", "word_id": "w_3"}]}, wrong={"fills": [{"blank_id": "b_1", "word_id": "w_2"}, {"blank_id": "b_2", "word_id": "w_3"}]},
    det=({"blank_results": [{"blank_id": "b_1", "correct": True}, {"blank_id": "b_2", "correct": True}]}, {"blank_results": [{"blank_id": "b_1", "correct": False}, {"blank_id": "b_2", "correct": True}]}))
CAT_B = {"presentation": "buckets", "categories": [{"category_id": "c_1", "label": "أركان الإسلام", "phase": None, "capacity": None}, {"category_id": "c_2", "label": "أركان الإيمان", "phase": None, "capacity": None}],
         "items": [{"item_id": "i_1", "spans": T("الصلاة"), "secondary_label": None}, {"item_id": "i_2", "spans": T("الإيمان بالملائكة"), "secondary_label": None}, {"item_id": "i_3", "spans": T("الزكاة"), "secondary_label": None}, {"item_id": "i_4", "spans": T("الإيمان باليوم الآخر"), "secondary_label": None}]}
D["categorize__buckets"] = dict(payload=CAT_B, key={"assignments": [{"item_id": "i_1", "category_id": "c_1"}, {"item_id": "i_2", "category_id": "c_2"}, {"item_id": "i_3", "category_id": "c_1"}, {"item_id": "i_4", "category_id": "c_2"}]},
    wrong={"assignments": [{"item_id": "i_1", "category_id": "c_1"}, {"item_id": "i_2", "category_id": "c_1"}, {"item_id": "i_3", "category_id": "c_1"}, {"item_id": "i_4", "category_id": "c_2"}]},
    det=({"item_results": [{"item_id": i, "correct": True} for i in ["i_1", "i_2", "i_3", "i_4"]]}, {"item_results": [{"item_id": "i_1", "correct": True}, {"item_id": "i_2", "correct": False}, {"item_id": "i_3", "correct": True}, {"item_id": "i_4", "correct": True}]}),
    invalid={"assignments": [{"item_id": "i_1", "category_id": "c_1"}, {"item_id": "i_1", "category_id": "c_2"}]})
DAY = [("cat_5t", "أول الضوء", "dawn"), ("cat_j8", "منتصف النهار", "midday"), ("cat_2w", "بعد الظهيرة", "afternoon"), ("cat_q1", "الغروب", "sunset"), ("cat_x6", "الليل", "night")]
PR = [("itm_9a", "الفجر"), ("itm_k7", "الظهر"), ("itm_c4", "العصر"), ("itm_b5", "المغرب"), ("itm_e2", "العشاء")]
CAT_D = {"presentation": "day_arc", "categories": [{"category_id": c, "label": l, "phase": ph, "capacity": 1} for c, l, ph in DAY],
         "items": [{"item_id": i, "spans": T(t), "secondary_label": None} for i, t in [PR[2], PR[0], PR[4], PR[1], PR[3]]]}
ok_d = {"assignments": [{"item_id": PR[k][0], "category_id": DAY[k][0]} for k in range(5)]}
bad_d = copy.deepcopy(ok_d); bad_d["assignments"][2]["category_id"], bad_d["assignments"][3]["category_id"] = DAY[3][0], DAY[2][0]
D["categorize__day_arc"] = dict(payload=CAT_D, key=ok_d, wrong=bad_d,
    det=({"item_results": [{"item_id": p[0], "correct": True} for p in PR]}, {"item_results": [{"item_id": p[0], "correct": k not in (2, 3)} for k, p in enumerate(PR)]}),
    invalid={"assignments": ok_d["assignments"][:4] + [{"item_id": PR[4][0], "category_id": DAY[0][0]}]}, layer="apply")
D["spot_error"] = dict(payload={"segments": [{"segment_id": "seg_1", "spans": T("يتّجه المسلمون في صلاتهم إلى الكعبة")}, {"segment_id": "seg_2", "spans": T("لأنهم يعبدونها")}, {"segment_id": "seg_3", "spans": T("وهي قِبلة واحدة لكل المسلمين.")}]},
    key={"segment_id": "seg_2"}, wrong={"segment_id": "seg_3"}, det=(None, None), mis=True)
D["which_evidence"] = dict(payload={"claim": T("الله واحد لا شريك له."), "options": [{"option_id": "ev_1", "evidence": Q112_1}, {"option_id": "ev_2", "evidence": H_NIYYAT}]},
    key={"option_id": "ev_1"}, wrong={"option_id": "ev_2"}, det=(None, None))
D["order_steps"] = dict(payload={"steps": [{"step_id": "st_3", "spans": T("غسل الوجه")}, {"step_id": "st_1", "spans": T("النية")}, {"step_id": "st_4", "spans": T("غسل اليدين إلى المرفقين")}, {"step_id": "st_2", "spans": T("المضمضة والاستنشاق")}]},
    key={"order": ["st_1", "st_2", "st_3", "st_4"]}, wrong={"order": ["st_1", "st_3", "st_2", "st_4"]}, det=({"first_wrong_index": None}, {"first_wrong_index": 1}), layer="remember")
D["scenario"] = dict(payload={"situation": T("دعاك زميلك إلى عشاء عمل، وسيُقدَّم فيه الخمر."), "options": [{"option_id": "s_1", "spans": T("أحضر وأعتذر بلطف عن الخمر، وأشرب شيئاً آخر.")}, {"option_id": "s_2", "spans": T("أشرب قليلاً حتى لا أُحرج زميلي.")}, {"option_id": "s_3", "spans": T("أقاطع زميلي ولا أكلّمه.")}]},
    key={"option_id": "s_1"}, wrong={"option_id": "s_2"}, det=({"option_feedback": [{"option_id": "s_1", "spans": T("تصرف لطيف يحفظ دينك وعلاقتك بزميلك.")}]}, {"option_feedback": [{"option_id": "s_2", "spans": T("الخمر محرّمة قليلها وكثيرها، ويمكنك الاعتذار بلطف.")}]}), layer="apply")
D["timeline_order"] = dict(payload={"events": [{"event_id": "t_2", "spans": T("الهجرة إلى المدينة")}, {"event_id": "t_4", "spans": T("فتح مكة")}, {"event_id": "t_1", "spans": T("نزول الوحي في غار حراء")}, {"event_id": "t_3", "spans": T("غزوة بدر")}]},
    key={"order": ["t_1", "t_2", "t_3", "t_4"]}, wrong={"order": ["t_2", "t_1", "t_3", "t_4"]},
    det=({"event_dates": [{"event_id": "t_1", "label": "نحو 610م"}, {"event_id": "t_2", "label": "1 هـ / 622م"}, {"event_id": "t_3", "label": "2 هـ"}, {"event_id": "t_4", "label": "8 هـ"}]},) * 2)
PINS_MAP = [{"pin_id": "p_1", "x_pct": 58.0, "y_pct": 71.5, "label": None, "radius_pct": None, "anchor_id": None}, {"pin_id": "p_2", "x_pct": 52.5, "y_pct": 38.0, "label": None, "radius_pct": None, "anchor_id": None}, {"pin_id": "p_3", "x_pct": 47.0, "y_pct": 45.2, "label": None, "radius_pct": None, "anchor_id": None}]
D["map_place__map_pins"] = dict(payload={"presentation": "map_pins", "visual": MAP, "question": T("أين تقع المدينة المنورة؟"), "pins": PINS_MAP, "interaction": None}, key={"pin_id": "p_2"}, wrong={"pin_id": "p_1"},
    det=({"pin_labels": [{"pin_id": "p_1", "label": "مكة المكرمة"}, {"pin_id": "p_2", "label": "المدينة المنورة"}, {"pin_id": "p_3", "label": "بدر"}]},) * 2, unavailable=True)
PINS_H = [{"pin_id": "pin_h3", "x_pct": 16.0, "y_pct": 36.0, "label": "النخلة", "radius_pct": None, "anchor_id": None}, {"pin_id": "pin_q8", "x_pct": 55.0, "y_pct": 52.0, "label": "الباب", "radius_pct": None, "anchor_id": None}, {"pin_id": "pin_z1", "x_pct": 80.0, "y_pct": 34.0, "label": "النافذة", "radius_pct": None, "anchor_id": None}, {"pin_id": "pin_m4", "x_pct": 42.0, "y_pct": 86.0, "label": "النهر", "radius_pct": None, "anchor_id": None}]
D["map_place__hotspots"] = dict(payload={"presentation": "hotspots", "visual": RIVER(1), "question": T("أين النهر؟"), "pins": PINS_H, "interaction": None}, key={"pin_id": "pin_m4"}, wrong={"pin_id": "pin_q8"},
    det=({"pin_labels": [{"pin_id": p["pin_id"], "label": p["label"]} for p in PINS_H]},) * 2, unavailable=True)
D["recite_verse"] = dict(payload={"surah": 112, "ayah": 1, "word_start": None, "word_end": None, "text_uthmani": "قُلْ هُوَ اللَّهُ أَحَدٌ", "audio": AUDIO_112_1, "transliteration": "Qul huwa Allahu ahad", "meaning": T("قل: هو الله الواحد لا شريك له."), "source_id": "src_q_112_1", "max_duration_ms": 30000, "skippable": True},
    key=None, wrong=None, det=(None, None), scoring=SC(False, False, None), recite=True)
D["verse_meaning"] = dict(payload={"verse": Q112_2, "options": [{"option_id": "m_1", "spans": T("الذي يحتاج إليه كل الخلق، وهو لا يحتاج إلى أحد")}, {"option_id": "m_2", "spans": T("الذي خلق السماوات في ستة أيام")}]},
    key={"option_id": "m_1"}, wrong={"option_id": "m_2"}, det=(None, None))
D["true_false"] = dict(payload={"statement": T("يؤمن المسلمون بأن لله شريكاً في الخلق.")}, key={"value": False}, wrong={"value": True}, det=(None, None), duel=True)

MIS = {"misconception_id": "mis_test", "title": "مفهوم خاطئ شائع", "card": T("بطاقة تصحيح معتمدة لهذا المفهوم."), "source_ids": ["src_q_112_1"]}


def exercise(name, spec, ex_id=None, framing=None):
    typ = name.split("__")[0]
    layer = spec.get("layer", "understand")
    sc = spec.get("scoring") or SC(True, True, layer)
    return {"exercise_id": ex_id or f"ex_{name}", "type": typ, "concept_ids": ["con_test"], "prompt": T("اختر الإجابة المناسبة."),
            "time_limit_ms": 15000 if spec.get("duel") else (None if typ in ("recite_verse", "flashcard") else 20000), "scoring": sc, "framing": framing, "payload": spec["payload"]}


def mastery_after(before, event):
    """Backend §7.1 (full precision internally; responses round half-up to 2 decimals)."""
    import decimal
    D = decimal.Decimal; b = D(str(before))
    m = {"correct": b + D("0.35") * (1 - b), "incorrect": b - D("0.25") * b, "retry_correct": b + D("0.10") * (1 - b),
         "recitation_passed": b + D("0.15") * (1 - b), "flashcard_hard": b + D("0.15") * (1 - b), "retry_incorrect": b, "none": b}[event]
    return float(m.quantize(D("0.01"), rounding=decimal.ROUND_HALF_UP))


def evaluation(ex_id, correct, key, details, mis=None, xp=0, rule=None):
    rule = rule or ("none" if correct is None else ("correct" if correct else "incorrect"))
    changes = [] if rule == "none" else [{"concept_id": "con_test", "title": "مفهوم اختباري", "before": 0.4, "after": mastery_after(0.4, rule)}]
    return {"exercise_id": ex_id, "recorded": True, "correct": correct, "correct_answer": key, "details": details,
            "explanation": T("شرح مختصر مرتبط بالدليل."), "source_ids": ["src_q_112_1"], "misconception": mis,
            "mastery_changes": changes, "term_changes": [], "xp_awarded": xp}


def timeout_details(details):
    result = copy.deepcopy(details)
    if isinstance(result, dict):
        if 'value_correct' in result:
            result.update(value_correct=False, reason_correct=False)
        if 'first_wrong_index' in result:
            result['first_wrong_index'] = 0
        for values in result.values():
            if isinstance(values, list):
                for value in values:
                    if isinstance(value, dict) and 'correct' in value:
                        value['correct'] = False
    return result

for name, spec in D.items():
    ex = exercise(name, spec)
    base = f"exercises/{name}/"
    save(base + "exercise.json", ex, C.Exercise)
    eid = ex["exercise_id"]
    if spec.get("recite"):
        save(base + "answer_check.json", {"exercise_id": eid, "answer": {"check_id": "rchk_55e2"}, "elapsed_ms": 41000, "is_retry": False}, C.AnswerSubmit)
        save(base + "eval_passed.json", evaluation(eid, True, None, None, xp=3, rule="recitation_passed"), C.AnswerEvaluation)
        save(base + "eval_failed.json", evaluation(eid, False, None, None, rule="none"), C.AnswerEvaluation)
        save(base + "answer_skipped.json", {"exercise_id": eid, "answer": {"skipped": True}, "elapsed_ms": 5000, "is_retry": False}, C.AnswerSubmit)
        save(base + "eval_skipped.json", evaluation(eid, None, None, None), C.AnswerEvaluation)
        continue
    if name == "flashcard":
        for r in ["again", "hard", "good", "easy"]:
            save(base + f"answer_{r}.json", {"exercise_id": eid, "answer": {"rating": r}, "elapsed_ms": 4000, "is_retry": False}, C.AnswerSubmit)
            save(base + f"eval_{r}.json", evaluation(eid, r != "again", None, None, rule="flashcard_hard" if r == "hard" else None), C.AnswerEvaluation)
        continue
    save(base + "answer_correct.json", {"exercise_id": eid, "answer": spec["key"], "elapsed_ms": 6000, "is_retry": False}, C.AnswerSubmit)
    save(base + "eval_correct.json", evaluation(eid, True, spec["key"], spec["det"][0], rule="none" if spec.get("duel") else None), C.AnswerEvaluation)
    save(base + "answer_incorrect.json", {"exercise_id": eid, "answer": spec["wrong"], "elapsed_ms": 7000, "is_retry": False}, C.AnswerSubmit)
    save(base + "eval_incorrect.json", evaluation(eid, False, spec["key"], spec["det"][1], rule="none" if spec.get("duel") else None), C.AnswerEvaluation)
    if spec.get("mis"):
        save(base + "eval_incorrect_misconception.json", evaluation(eid, False, spec["key"], spec["det"][1], MIS), C.AnswerEvaluation)
    save(base + "answer_timeout.json", {"exercise_id": eid, "answer": None, "elapsed_ms": ex["time_limit_ms"], "is_retry": False}, C.AnswerSubmit)
    save(base + "eval_timeout.json", evaluation(eid, False, spec["key"], timeout_details(spec["det"][1]), rule="none" if spec.get("duel") else None), C.AnswerEvaluation)
    if not spec.get("duel"):
        save(base + "answer_retry.json", {"exercise_id": eid, "answer": spec["key"], "elapsed_ms": 5000, "is_retry": True}, C.AnswerSubmit)
        save(base + "eval_retry_correct.json", evaluation(eid, True, spec["key"], spec["det"][0], rule="retry_correct"), C.AnswerEvaluation)
        save(base + "answer_retry_incorrect.json", {"exercise_id": eid, "answer": spec["wrong"], "elapsed_ms": 5000, "is_retry": True}, C.AnswerSubmit)
        save(base + "eval_retry_incorrect.json", evaluation(eid, False, spec["key"], spec["det"][1], rule="none"), C.AnswerEvaluation)
    save(base + "eval_recorded_only.json", {"exercise_id": eid, "recorded": True}, C.AnswerRecorded)
    if "invalid" in spec:
        save(base + "answer_invalid.json", {"exercise_id": eid, "answer": spec["invalid"], "elapsed_ms": 6000, "is_retry": False}, C.AnswerSubmit)
        save(base + "error_invalid.json", {"error": {"code": "validation_error", "message": "each item must be assigned exactly once within capacity", "details": {"reason": "duplicate_or_missing_item"}}}, C.ErrorEnvelope)
    if spec.get("unavailable"):
        save(base + "answer_unavailable.json", {"exercise_id": eid, "answer": {"unavailable": True}, "elapsed_ms": 2000, "is_retry": False}, C.AnswerSubmit)
        save(base + "eval_unavailable.json", evaluation(eid, None, None, None), C.AnswerEvaluation)

# ---------------------------------------------------------------- session with every type + predict + framing
def session(sid, items, sources, title="جلسة اختبارية", kind="lesson", lesson_id="les_test_all", subtitle=None, completion=None, terms=None, objectives=None, unit_id="unit_test_1"):
    exs = [b for b in items if b["type"] == "exercise"]
    pr = [b for b in items if b["type"] == "predict"]
    return {"session_id": sid, "kind": kind, "mode": None, "status": "active", "feedback_mode": "immediate", "unit_id": unit_id, "lesson_id": lesson_id,
            "lesson_version": 1, "title": title, "subtitle": subtitle, "lesson_type": "concept", "reviewed_by": "لجنة المراجعة الشرعية",
            "objectives": objectives or [T("هدف اختباري.")],
            "counts": {"interactions": len(exs) + len(pr), "exercises": len(exs), "scored": sum(1 for b in exs if b["exercise"]["scoring"]["accuracy"])},
            "source_count": sum(1 for s in sources if s["displayed"]), "total_exercises": len(exs), "answered_exercises": 0, "started_at": "2026-10-04T09:00:00Z",
            "items": items, "completion": completion or {"challenge": T("تحدٍّ اختباري."), "review_topics": [{"topic_id": "rt_1", "title": "موضوع اختباري", "concept_ids": ["con_test"]}], "check_in": T("سؤال الغد الاختباري.")},
            "sources": sources, "terms": terms or {}, "answers": []}


SRC_112 = {"source_id": "src_q_112_1", "kind": "quran", "provider": "quran_com", "title": "سورة الإخلاص", "reference": "الإخلاص: 1", "excerpt": "قُلْ هُوَ اللَّهُ أَحَدٌ", "url": "https://quran.com/112/1", "displayed": True, "display_role": "content"}
items = [{"block_id": "blk_predict", "type": "predict", "prompt": T("ماذا تتوقع؟"), "options": [{"option_id": "po_1", "spans": T("الخيار الأول")}, {"option_id": "po_2", "spans": T("الخيار الثاني")}], "reveal": T("فكرة جميلة! سنكتشف الجواب في الدرس."), "visual": None},
         {"block_id": "blk_ev", "type": "evidence", "evidence": Q112_1, "caption": None}]
for i, (name, spec) in enumerate(D.items()):
    if spec.get("duel"):
        continue
    fr = {"kind": "myth", "statement": T("فكرة خاطئة شائعة للتصحيح.")} if name == "multiple_choice" else None
    items.append({"block_id": f"blk_x{i}", "type": "exercise", "exercise": exercise(name, spec, framing=fr)})
save("sessions/session_practice_all_types.json", session("ses_all_types", items, [SRC_112]), C.Session)

# ---------------------------------------------------------------- generated-scene test lesson (non-Salah)
raw = (ROOT / "fixtures/scenes/scn_test_desert_well.v2.scene.json").read_bytes()
SCENE = json.loads(raw)
def scene_visual(params):
    vb = SCENE["view_box"]
    return {"kind": "scene", "key": None, "version": None, "params": params, "image": None,
            "scene": {"scene_id": SCENE["scene_id"], "version": SCENE["version"], "schema_version": "qabas.scene/1",
                      "url": "mock-asset://scenes/scn_test_desert_well/v2/scene.json", "mime_type": "application/json",
                      "sha256": hashlib.sha256(raw).hexdigest(), "view_box": vb, "required_capabilities": SCENE["required_capabilities"]},
            "fallback_image": {"url": f"mock-asset://scenes/scn_test_desert_well/v2/fallback_b{params['beat']}_f{params['focus']}.webp", "mime_type": "image/webp", "width": vb["width"], "height": vb["height"]},
            "fallback_params": dict(params),
            "alt": "صحراء ليلاً فيها بئر ونخلة وخيمة", "overlays": []}
anchors = {a["anchor_id"]: a for a in SCENE["anchors"]}
pins = [{"pin_id": f"pin_{k}", "x_pct": round(100 * a["x"] / SCENE["view_box"]["width"], 2), "y_pct": round(100 * a["y"] / SCENE["view_box"]["height"], 2), "label": lab, "radius_pct": round(100 * a["radius"] / SCENE["view_box"]["width"], 2), "anchor_id": k}
        for k, lab in [("palm", "النخلة"), ("well", "البئر"), ("tent", "الخيمة")] for a in [anchors[k]]]
scene_items = [
    {"block_id": "blk_s_hook", "type": "hook", "situation": T("نص اختباري: موقف افتتاحي."), "question": T("سؤال اختباري؟"), "visual": scene_visual({"beat": 0, "focus": -1}), "cta": None},
    {"block_id": "blk_s_story", "type": "story", "label": "قصة", "title": "قصة اختبارية", "provenance": None,
     "beats": [{"beat_id": f"beat_s_{b}", "beat_index": b, "narration": [{"sentence_id": f"sen_s_b{b}", "spans": T(f"نص اختباري للمرحلة {b}."), "source_ids": []}],
                "narration_audio_url": None, "quote": None, "quote_meaning": None, "visual": scene_visual({"beat": b, "focus": -1})} for b in range(3)],
     "origin": {"title": "من أين جاءت هذه القصة؟", "source_ids": ["src_test_story"], "show_card": False}},
    {"block_id": "blk_s_teach", "type": "teach", "eyebrow": "تعلّم", "title": T("بطاقة تعليمية اختبارية"), "style": "standard", "visual": scene_visual({"beat": 1, "focus": -1}), "evidence": None,
     "points": [{"point_id": f"pt_s_{k}", "sentence": {"sentence_id": f"sen_s_t{k}", "spans": T(f"نقطة اختبارية {k + 1}."), "source_ids": []}, "visual_params": {"focus": k}} for k in range(3)]},
    {"block_id": "blk_s_map", "type": "exercise", "exercise": {"exercise_id": "ex_s_hotspot", "type": "map_place", "concept_ids": ["con_test"], "prompt": T("اضغط على البئر."), "time_limit_ms": None,
        "scoring": SC(True, True, "understand"), "framing": None, "payload": {"presentation": "hotspots", "visual": scene_visual({"beat": 1, "focus": -1}), "question": T("أين البئر؟"), "pins": pins,
        "interaction": {"bindings": [{"pin_id": "pin_palm", "set": {"focus": 1}}, {"pin_id": "pin_well", "set": {"focus": 0}}, {"pin_id": "pin_tent", "set": {"focus": 2}}],
                        "reset_on_deselect": True, "after_evaluation": {"correct": {"beat": 2}, "incorrect": None}}}}},
    {"block_id": "blk_s_sum", "type": "teach", "eyebrow": None, "title": T("الخلاصة"), "style": "summary", "visual": None, "evidence": None,
     "points": [{"point_id": f"pt_sum_{k}", "sentence": {"sentence_id": f"sen_sum_{k}", "spans": T(f"خلاصة اختبارية {k + 1}."), "source_ids": []}, "visual_params": None} for k in range(2)]}]
save("scenes/session_test_scene_lesson.json", session("ses_scene_test", scene_items, [], title="درس اختباري: البئر في الصحراء", lesson_id="les_test_scene"), C.Session)
save("scenes/eval_hotspot_correct.json", evaluation("ex_s_hotspot", True, {"pin_id": "pin_well"}, {"pin_labels": [{"pin_id": p["pin_id"], "label": p["label"]} for p in pins]}), C.AnswerEvaluation)

# ---------------------------------------------------------------- group challenge (4 players, tie, disconnect)
players = [("usr_7f3k2a", "مسافر ٤٧", True), ("usr_f1", "Seeker 21", False), ("usr_f2", "سالك ٥", False), ("usr_f3", "نور ١٢", False)]
cfg = {"question_count": 3, "time_limit_ms": 10000, "scoring": {"base": 100, "speed_bonus": 50, "rounding": "half_up"}, "reveal_ms": 2200}
def duel(status, result=None, pstat="joined"):
    return {"duel_id": "duel_g1", "status": status, "mode": "live", "preset": "group", "opponent_type": "friends",
            "players": [{"user_id": u, "display_name": n, "avatar_key": f"traveler_0{i + 1}", "is_me": me, "is_bot": False, "status": "joined" if me else pstat} for i, (u, n, me) in enumerate(players)],
            "config": cfg, "ws_url": "mock-ws://duels/duel_g1", "created_at": "2026-10-04T13:00:00Z", "expires_at": "2026-10-04T13:01:00Z", "result": result}
def pts(correct, rem):
    return C.challenge_points(correct, rem, C.DuelConfig.model_validate(cfg))
Q = [{"exercise_id": f"ex_g_{q}", "type": "multiple_choice", "concept_ids": ["con_test"], "prompt": T(f"سؤال جماعي {q + 1}"), "time_limit_ms": 10000, "scoring": SC(), "framing": None,
      "payload": {"options": [{"option_id": "opt_a", "spans": T("أ")}, {"option_id": "opt_b", "spans": T("ب")}]}} for q in range(3)]
# answers: elapsed ms or None (timeout); correctness
ANS = [[(5000, True), (5000, True), (None, False), (7100, False)],
       [(3000, True), (3000, True), (6000, True), (9000, True)],
       [(4000, False), (6000, False), (8000, True), (None, False)]]
totals = {u: 0 for u, _, _ in players}
script = [{"type": "state", "data": {"duel": duel("pending", pstat="invited"), "server_ts": "2026-10-04T13:00:01Z", "live": None}}]
for u, _, me in players[1:]:
    script.append({"type": "player_status", "data": {"user_id": u, "status": "joined"}})
script += [{"type": "state", "data": {"duel": duel("ready"), "server_ts": "2026-10-04T13:00:20Z", "live": None}},
           {"type": "countdown", "data": {"starts_at": "2026-10-04T13:00:24Z", "seconds": 3}}]
results = []
for qi, q in enumerate(Q):
    script.append({"type": "question", "data": {"question_index": qi, "total": 3, "exercise": q, "issued_at": f"2026-10-04T13:0{qi}:30Z", "deadline_at": f"2026-10-04T13:0{qi}:40Z"}})
    if qi == 0:
        script.append({"type": "opponent_disconnected", "data": {"user_id": "usr_f2", "grace_ms": 10000}})
    for (u, _, me), (el, ok) in zip(players, ANS[qi]):
        if el is None:
            continue
        script.append({"type": "answer_received" if me else "opponent_answered", "data": {"question_index": qi} if me else {"question_index": qi, "user_id": u}})
    rows = []
    for (u, _, me), (el, ok) in zip(players, ANS[qi]):
        p = pts(ok, 10000 - el) if el is not None else 0
        totals[u] += p
        rows.append({"user_id": u, "correct": ok and el is not None, "elapsed_ms": el if el is not None else 10000, "points": p})
    data = {"question_index": qi, "correct_answer": {"option_id": "opt_a"}, "explanation": T("شرح اختباري."), "players": rows, "totals": [{"user_id": u, "points": totals[u]} for u in totals]}
    results.append(data)
    script.append({"type": "question_result", "data": data})
    if qi == 0:
        script.append({"type": "opponent_reconnected", "data": {"user_id": "usr_f2"}})
        script.append({"type": "state", "data": {"duel": duel("in_progress"), "server_ts": "2026-10-04T13:00:43Z",
                       "live": {"phase": "result", "question_index": 0, "question": None, "deadline_at": None, "answered_user_ids": ["usr_7f3k2a", "usr_f1", "usr_f3"],
                                "my_answer": {"answer": {"option_id": "opt_a"}, "locked": True}, "totals": [{"user_id": u, "points": totals[u]} for u in totals], "results_so_far": [data]}}})
order = sorted(totals.items(), key=lambda kv: -kv[1])
top = order[0][1]
ranks, r = {}, 0
for i, (u, p) in enumerate(order):
    ranks[u] = ranks.get(u) or (1 if p == top else i + 1)
scores = [{"user_id": u, "rank": ranks[u], "points": totals[u], "correct": sum(1 for qi in range(3) if ANS[qi][[x[0] for x in players].index(u)][1] and ANS[qi][[x[0] for x in players].index(u)][0] is not None)} for u in totals]
winners = [u for u in totals if ranks[u] == 1]
result = {"winner_user_ids": winners, "is_draw": len(winners) == len(players), "scores": scores, "xp_awarded": 15}
script.append({"type": "finished", "data": {"result": result, "summary": []}})
save("challenges/group_challenge.json", duel("finished", result), C.Duel)
save("challenges/group_ws_script.json", script, C.WsEvent, many=True)
for ev in script:
    if ev["type"] == "state":
        C.Duel.model_validate(ev["data"]["duel"])
assert len(winners) == 2, f"expected a two-way rank-1 tie, got {totals}"

# ---------------------------------------------------------------- multi-unit test curriculum
types = [["concept", "story", "practice"], ["concept", "concept", "story", "practice"], ["practice", "concept", "story"]]
# Curriculum amendment: unit_test_1 is Explorer-only (the Unit 0 pattern); units 2-3 are shared.
# Access follows mandatory prerequisites, never curriculum position: (u, l) -> prerequisite lesson.
# Standalone-eligible lessons (Discover) have no prerequisites; (3, 1) has none but is not standalone.
UNIT_TRACKS = {1: ("explorer",), 2: ("explorer", "new_muslim"), 3: ("explorer", "new_muslim")}
PREREQ = {(1, 1): (1, 0), (1, 2): (1, 1), (2, 1): (2, 0), (2, 3): (2, 1), (3, 0): (2, 3)}
STANDALONE = {(1, 0), (2, 0), (2, 2), (3, 2)}
def lesson_ref(u, l):
    return {"lesson_id": f"les_t{u}_{l}", "unit_id": f"unit_test_{u}", "title": f"درس اختباري {u}.{l + 1}"}
def start_with(u, l):
    while (u, l) in PREREQ:
        u, l = PREREQ[(u, l)]
    return lesson_ref(u, l)
def jlesson(u, l, typ):
    lock = {"prerequisites": [lesson_ref(*PREREQ[(u, l)])], "start_with": start_with(u, l)} if (u, l) in PREREQ else None
    return {"lesson_id": f"les_t{u}_{l}", "index": l, "title": f"درس اختباري {u}.{l + 1}", "lesson_type": typ, "state": "locked" if lock else "available",
            "estimated_minutes": 5, "xp": 15, "standalone_eligible": (u, l) in STANDALONE, "soft_lock": lock}
for track, start in [("explorer", 1), ("new_muslim", 2)]:
    units = []
    for u in range(1, 4):
        if track not in UNIT_TRACKS[u]:
            continue
        lessons = [jlesson(u, l, t) for l, t in enumerate(types[u - 1])]
        st = "in_progress" if u == start else ("available" if any(x["state"] != "locked" for x in lessons) else "locked")
        units.append({"unit_id": f"unit_test_{u}", "index": u - 1, "title": f"وحدة اختبارية {u}", "subtitle": "اختبار", "art_key": None, "has_guide": False, "state": st, "coming_soon": False,
                      "pretest": {"state": "not_taken"}, "unit_test": {"state": "not_passed", "best_percent": None, "pass_percent": 80, "can_skip": True},
                      "lessons": lessons})
    units.append({"unit_id": "unit_test_4", "index": 3, "title": "قريباً", "subtitle": "قريباً", "art_key": None, "has_guide": False, "state": "locked", "coming_soon": True,
                  "pretest": {"state": "not_taken"}, "unit_test": {"state": "not_passed", "best_percent": None, "pass_percent": 80, "can_skip": False}, "lessons": []})
    save(f"curriculum_test/journey_{track}.json", {"track": track, "current": {"unit_id": f"unit_test_{start}", "lesson_id": f"les_t{start}_0"}, "units": units}, C.Journey)
def localize_test_session(value):
    # Synthetic curriculum copy, not a translation of approved religious content.
    count = [0]
    def visit(o, key=""):
        if isinstance(o, dict):
            return {k: visit(v, k) for k, v in o.items()}
        if isinstance(o, list):
            return [visit(x, key) for x in o]
        if isinstance(o, str) and any("\u0600" <= c <= "\u06ff" for c in o):
            if key in {"text_uthmani", "text_ar", "surah_name", "secondary_label", "transliteration"}:
                return o
            count[0] += 1
            return f"Test {key or 'text'} {count[0]}"
        return o
    result = visit(value)
    for b in result["items"]:
        if b["type"] == "exercise":
            b["exercise"]["prompt"] = T("Complete this test activity.")
    return result

ex_names = [n for n in D if not D[n].get("duel") and n not in ("flashcard", "recite_verse")]
k = 0
for u in range(1, 4):
    for l, typ in enumerate(types[u - 1]):
        for lang in ("ar", "en"):
            for track in UNIT_TRACKS[u]:  # an Explorer-only unit has no New Muslim variant
                txt = (lambda t: f"[{track}] " + ("نص اختباري: " if lang == "ar" else "Test text: ") + t)
                image_only = (u, l) == (2, 1)
                vis = {"kind": "image", "key": None, "version": None, "params": None, "image": {"url": f"mock-asset://test/u{u}l{l}.webp", "mime_type": "image/webp", "width": 1600, "height": 1000}, "scene": None, "fallback_image": None, "fallback_params": None, "alt": txt("صورة"), "overlays": []}
                if (u, l) == (3, 2):
                    vis = scene_visual({"beat": 0, "focus": -1})
                its = [{"block_id": "b_p", "type": "paragraph", "sentences": [{"sentence_id": "s1", "spans": T(txt(f"الدرس {u}.{l + 1}")), "source_ids": []}]},
                       {"block_id": "b_v", "type": "visual", "visual": vis, "caption": None}]
                for j in range(4):
                    nm = ex_names[(k + j) % len(ex_names)]
                    sp = D[nm]
                    if image_only and sp["payload"].get("visual", {}).get("kind") == "builtin":
                        nm = "multiple_choice"; sp = D[nm]
                    its.append({"block_id": f"b_x{j}", "type": "exercise", "exercise": exercise(nm, sp, ex_id=f"ex_t{u}{l}_{j}")})
                sess = session(f"ses_t{u}{l}_{lang}_{track}", its, [], title=txt(f"درس {u}.{l + 1}"), lesson_id=f"les_t{u}_{l}", unit_id=f"unit_test_{u}")
                sess["lesson_type"] = typ
                if lang == "en":
                    sess = localize_test_session(sess)
                save(f"curriculum_test/lessons/les_t{u}_{l}__{lang}_{track}.json", sess, C.Session)

        k += 4

# ---------------------------------------------------------------- answer history per feedback mode (§6.5.5)
base = json.loads((OUT / "sessions/session_practice_all_types.json").read_text())
exs = [b["exercise"] for b in base["items"] if b["type"] == "exercise"]
def ev_for(e, correct):
    return evaluation(e["exercise_id"], correct, D_KEYS.get(e["exercise_id"]), None)
D_KEYS = {}
def hist(mode, status, kind):
    h = copy.deepcopy(base)
    h.update(session_id=f"ses_hist_{mode}_{status}", kind=kind, feedback_mode=mode, status=status)
    if kind != "lesson":
        h.update(objectives=[], completion=None, lesson_id=None, lesson_version=None, subtitle=None, lesson_type=None, reviewed_by=None,
                 items=[b for b in h["items"] if b["type"] == "exercise" and b["exercise"]["type"] not in ("recite_verse", "flashcard")])
        h["items"] = h["items"][:(8 if kind == "pretest" else 12)]
        e2 = [b for b in h["items"]]
        h["counts"] = {"interactions": len(e2), "exercises": len(e2), "scored": sum(1 for b in e2 if b["exercise"]["scoring"]["accuracy"])}
        h["total_exercises"] = len(e2); h["sources"] = []; h["source_count"] = 0
    visible = mode == "immediate" or (mode == "end" and status == "finished")
    ex2 = [b["exercise"] for b in h["items"] if b["type"] == "exercise"]
    plan = [(ex2[0], False, True), (ex2[1], False, False)] + ([(ex2[1], True, True)] if mode == "immediate" else [])
    ans = []
    for e, retry, ok in plan:
        ans.append({"exercise_id": e["exercise_id"], "is_retry": retry,
                    "result": ("correct" if ok else "incorrect") if visible else "hidden", "recorded_at": "2026-10-04T09:05:00Z",
                    "evaluation": ev_for(e, ok) if mode == "immediate" else None})
    h["answers"] = ans; h["answered_exercises"] = len({a["exercise_id"] for a in ans if not a["is_retry"]})
    return h
for mode, status, kind in [("immediate", "active", "lesson"), ("end", "active", "unit_test"), ("end", "finished", "unit_test"), ("none", "finished", "pretest")]:
    save(f"sessions/history_{mode}_{status}.json", hist(mode, status, kind), C.Session)
save("sessions/duplicate_answer_hidden_response.json", {"exercise_id": exs[1]["exercise_id"], "recorded": True}, C.AnswerRecorded)

# ---------------------------------------------------------------- fresh-device recovery case: retry of an early exercise
rec = copy.deepcopy(base)
rex = [b["exercise"] for b in rec["items"] if b["type"] == "exercise"]
rec_answers = [{"exercise_id": e["exercise_id"], "is_retry": False, "result": "incorrect" if i == 0 else ("neutral" if e["type"] == "recite_verse" else "correct"),
                "recorded_at": "2026-10-04T09:10:00Z", "evaluation": ev_for(e, None if e["type"] == "recite_verse" else i != 0)} for i, e in enumerate(rex)]
rec_answers.append({"exercise_id": rex[0]["exercise_id"], "is_retry": True, "result": "correct", "recorded_at": "2026-10-04T09:30:00Z", "evaluation": ev_for(rex[0], True)})
rec.update(session_id="ses_recovery_retry", answers=rec_answers, answered_exercises=len(rex))
save("sessions/recovery_after_early_retry.json", rec, C.Session)

(OUT / "MANIFEST.json").write_text(json.dumps([{"file": f, "model": m} for f, m in written], ensure_ascii=False, indent=1))
print(len(written), "fixtures written and validated")
