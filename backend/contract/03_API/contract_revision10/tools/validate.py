"""Contract package validation (revision 10 candidate). Writes report and checksums.

Stages, reported separately:
  1. JSON syntax           — every ```json block in ../API_REQUIREMENTS.md and every fixture parses.
  2. Model validation      — each object validates against contract/qabas_contract.py (extra keys
                             forbidden; nullable fields required) via an explicit example→model map.
  3. Semantic checks       — cross-object rules models can't see: scene manifests vs. visual states,
                             anchors/pins/fallback states, bindings, mock-asset resolution (MIME,
                             dimensions, checksums), workflow recomputation (score, layers, perfect,
                             XP), challenge scoring (incl. the half-up boundary), fresh-device recovery.
  4. Negative tests        — known violations must be rejected.
  5. Runtime verification  — NONE in this package (no Flutter app, renderer, or backend was run).
"""
import copy, hashlib, json, pathlib, re, sys
from pydantic import TypeAdapter, ValidationError
from PIL import Image as PILImage

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "contract")); sys.path.insert(0, str(ROOT / "tools"))
import qabas_contract as C  # noqa: E402
import scene_check  # noqa: E402
import recovery  # noqa: E402

BLOCK = TypeAdapter(C.Block); SPANS = TypeAdapter(C.Spans)
FX = ROOT / "fixtures"
page = lambda m: C.Page(m).model_validate
EXPLICIT = {
    "3.6 Rich text (`Span[]`)": [SPANS.validate_python],
    "5.1 `User`": [C.User.model_validate], "5.9 `NextStep`": [C.NextStep.model_validate],
    "`POST /auth/guest`": [C.GuestReq.model_validate, C.AuthResp.model_validate],
    "`POST /auth/reviewer`": [C.ReviewerReq.model_validate, C.AuthResp.model_validate],
    "`POST /onboarding`": [C.OnboardingReq.model_validate, C.OnboardingResp.model_validate],
    "`GET /me/stats`": [C.Stats.model_validate],
    "`GET /me/activity?from=2026-09-27&to=2026-10-10`": [C.Activity.model_validate],
    "`GET /me/quests`": [C.Quests.model_validate], "`GET /me/achievements`": [C.Achievements.model_validate],
    "`GET /me/concepts`": [page(C.ConceptRow)], "`GET /units/{unit_id}/guide`": [C.Guide.model_validate],
    "`POST /sessions`": [C.SessionCreate.model_validate] * 4 + [C.Session.model_validate, BLOCK.validate_python],
    "`POST /sessions/{session_id}/answers`": [C.AnswerSubmit.model_validate],
    "`POST /sessions/{session_id}/finish`": [C.FinishReq.model_validate, C.SessionResult.model_validate],
    "`POST /recitation/checks` (multipart/form-data)": [C.RecitationCheck.model_validate] * 3 + [C.AnswerSubmit.model_validate] * 2,
    "`GET /glossary?state=all|new|learning|mastered&cursor=&limit=`": [page(C.TermCard)],
    "`POST /raqeeb/conversations`": [C.ConvCreate.model_validate, C.Conversation.model_validate],
    "`GET /raqeeb/conversations?cursor=&limit=`": [page(C.ConvRow)],
    "`GET /raqeeb/conversations/{conversation_id}`": [C.ConvDetail.model_validate],
    "`POST /raqeeb/conversations/{conversation_id}/messages` (multipart/form-data)": [C.PostMessageResp.model_validate],
    "`GET /raqeeb/messages/{message_id}`": [C.AssistantProcessing.model_validate, C.AssistantFailed.model_validate, C.Referral.model_validate] + [C.RaqeebCompleted.model_validate] * 8,
    "`POST /raqeeb/messages/{message_id}/feedback`": [C.FeedbackReq.model_validate],
    "`GET /leagues/current`": [C.League.model_validate], "`GET /friends`": [page(C.Friend)],
    "`POST /friends/invites` → `201`": [C.Invite.model_validate], "`POST /friends/invites/accept`": [C.InviteAccept.model_validate],
    "`Duel` object": [C.Duel.model_validate, C.DuelResult.model_validate], "`POST /duels`": [C.DuelCreate.model_validate] * 3,
    "`GET /duels/invitations`": [page(C.Invitation)],
    "Async fallback": [C.AsyncNext.model_validate, C.AsyncAnswer.model_validate, C.AsyncAnswerResp.model_validate],
    "`POST /admin/factory/runs`": [C.RunCreate.model_validate], "`GET /admin/factory/runs?status=&cursor=&limit=`": [page(C.RunRow)],
    "`GET /admin/factory/runs/{run_id}` → `FactoryRun`": [C.FactoryRun.model_validate],
    "`POST /admin/factory/runs/{run_id}/gate1`": [C.Gate1.model_validate],
    "Gate 2 draft (`status = awaiting_gate2`)": [C.DraftFragment.model_validate],
    "`POST /admin/factory/runs/{run_id}/gate2`": [C.Gate2.model_validate],
    "`GET /admin/blind-test/next`": [C.BlindPair.model_validate], "`POST /admin/blind-test/{pair_id}`": [C.BlindAnswer.model_validate],
    "`GET /admin/metrics`": [C.Metrics.model_validate],
    # rev 10 examples
    "`PATCH /me`": [C.MePatch.model_validate],
    "8.1 Client → server": [lambda v: [C.WsClientMessage.model_validate(x) for x in v]],
}


def strip_mock(o):
    if isinstance(o, dict): return {k: strip_mock(v) for k, v in o.items() if not k.startswith("_mock")}
    if isinstance(o, list): return [strip_mock(v) for v in o]
    return o


def classify(o):
    if isinstance(o, list):
        return ("WsEvent[]", lambda v: [C.WsEvent.model_validate(x) for x in v]) if o and all(isinstance(x, dict) and set(x) == {"type", "data"} for x in o) else (None, None)
    k = set(o)
    if k == {"exercise_id", "recorded"}: return "AnswerRecorded", C.AnswerRecorded.model_validate
    if o.get("role") == "assistant" and o.get("status") == "completed": return "RaqeebCompleted", C.RaqeebCompleted.model_validate
    for need, model in [({"session_id", "items"}, C.Session), ({"lesson_id", "blocks", "version"}, C.LessonRead), ({"duel_id", "players"}, C.Duel),
                        ({"exercise_id", "correct_answer"}, C.AnswerEvaluation), ({"exercise_id", "payload"}, C.Exercise), ({"evidence_id"}, C.Evidence),
                        ({"term_id", "definition"}, C.TermCard), ({"source_id", "displayed"}, C.Source), ({"track", "units"}, C.Journey)]:
        if need <= k: return model.__name__, model.model_validate
    if o.get("kind") in ("builtin", "image", "scene") and "alt" in k: return "Visual", C.Visual.model_validate
    if "block_id" in k: return "Block", BLOCK.validate_python
    if k == {"url", "mime_type", "width", "height"}: return "Image", C.Image.model_validate
    if o.get("type") == "medallion": return "Overlay", C.Overlay.model_validate
    if k == {"error"}: return "ErrorEnvelope", C.ErrorEnvelope.model_validate
    for name, model in C.PAYLOADS.items():
        try:
            model.model_validate(o); return f"payload:{name}", model.model_validate
        except ValidationError:
            pass
    return None, None


def doc_examples(path):
    out, heading = [], ""
    for m in re.finditer(r"^(#{2,4} [^\n]*)$|```json\n(.*?)```", path.read_text(encoding="utf-8"), re.S | re.M):
        if m.group(1): heading = m.group(1).strip("# ").strip()
        else: out.append((heading, m.group(2)))
    return out


R = ["# Validation report (revision 10 candidate)", "",
     "Generated by `tools/validate.py`. Stages are reported separately. **Runtime verification: none** — no Flutter app, scene renderer, or backend was executed for this report.", ""]
fail = 0

ex = doc_examples(ROOT.parent / "API_REQUIREMENTS.md"); seen = {}; parsed = []; mok = 0; mbad = []
for heading, raw in ex:
    obj = strip_mock(json.loads(raw)); parsed.append((heading, obj))
    i = seen.get(heading, 0); seen[heading] = i + 1
    name, fn = (heading, EXPLICIT[heading][i]) if heading in EXPLICIT and i < len(EXPLICIT[heading]) else classify(obj)
    if not fn: mbad.append(f"{heading}: no model"); continue
    try: fn(obj); mok += 1
    except ValidationError as e: mbad.append(f"{heading} #{i}: " + " | ".join(str(e).splitlines()[:3]))
fx = json.loads((FX / "MANIFEST.json").read_text()); fok = 0; fbad = []
for f in fx:
    obj = json.loads((FX / f["file"]).read_text()); model = getattr(C, f["model"])
    try:
        for o in (obj if isinstance(obj, list) else [obj]): model.model_validate(o)
        fok += 1
    except ValidationError as e: fbad.append(f"{f['file']}: {str(e).splitlines()[0]}")
fail += len(mbad) + len(fbad)
R += ["## 1. JSON syntax", f"- Handoff examples parsed: {len(ex)}/{len(ex)}", f"- Fixture files parsed: {len(fx)}/{len(fx)}", "",
      "## 2. Model validation", f"- Handoff examples: **{mok}/{len(ex)}** (explicit example → model map)", f"- Fixtures: **{fok}/{len(fx)}** (`fixtures/MANIFEST.json`)"]
R += [f"  - FAILED {x}" for x in mbad + fbad]

sem = []
def check(label, errs):
    global fail
    sem.append(f"- {'✓' if not errs else '✗'} {label}" + ("" if not errs else ": " + "; ".join(errs[:5])))
    fail += bool(errs)

assets = json.loads((FX / "mock_assets/mock_assets.json").read_text())
def asset_errs():
    errs = []
    for f in fx:
        for url in re.findall(r'mock-asset://[^"\s]+', (FX / f["file"]).read_text()):
            if url not in assets: errs.append(f"{f['file']}: unresolved {url}")
    for url, m in assets.items():
        p = FX / m["path"]; b = p.read_bytes()
        if hashlib.sha256(b).hexdigest() != m["sha256"]: errs.append(f"{url}: checksum")
        if m["mime_type"].startswith("image/"):
            with PILImage.open(p) as im:
                if (im.width, im.height) != (m["width"], m["height"]) or im.format.lower() != m["mime_type"].split("/")[1]:
                    errs.append(f"{url}: dimensions/format")
        if m["mime_type"] == "audio/mpeg" and not (b[:3] == b"ID3" or b[0] == 0xFF): errs.append(f"{url}: not MP3")
    for f in fx:
        for path, d in walk(json.loads((FX / f["file"]).read_text())):
            if {"url", "mime_type", "width", "height"} == set(d) and d["url"].startswith("mock-asset://"):
                m = assets.get(d["url"])
                if m and (m["mime_type"], m["width"], m["height"]) != (d["mime_type"], d["width"], d["height"]): errs.append(f"{f['file']}{path}: declared image ≠ file")
    return errs

def walk(o, path=""):
    if isinstance(o, dict):
        yield path, o
        for k, v in o.items(): yield from walk(v, f"{path}.{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o): yield from walk(v, f"{path}[{i}]")

check("every mock-asset URL resolves to a file whose MIME type, dimensions, and checksum match the declarations", asset_errs())

def manifest_for(ref):
    m = assets.get(ref["url"])
    raw = (FX / m["path"]).read_bytes() if m else (FX / "scenes" / f"{ref['scene_id']}.v{ref['version']}.scene.json").read_bytes()
    return json.loads(raw), raw

def scene_semantics(obj, where):
    errs = []
    for path, d in walk(obj):
        if d.get("kind") == "scene" and isinstance(d.get("scene"), dict):
            man, raw = manifest_for(d["scene"])
            if hashlib.sha256(raw).hexdigest() != d["scene"]["sha256"]: errs.append(f"{where}{path}: sha256 mismatch")
            if man["view_box"] != d["scene"]["view_box"]: errs.append(f"{where}{path}: view_box mismatch")
            if sorted(man["required_capabilities"]) != sorted(d["scene"]["required_capabilities"]): errs.append(f"{where}{path}: capabilities mismatch")
            errs += [f"{where}{path}: {e}" for e in scene_check.check(man, raw)]
            errs += scene_check.state_values_errors(man, d["params"], f"{where}{path}.params")
            errs += scene_check.state_values_errors(man, d["fallback_params"], f"{where}{path}.fallback_params")
        if d.get("type") == "teach" and d.get("visual") and d["visual"]["kind"] == "scene":
            man, _ = manifest_for(d["visual"]["scene"]); cur = dict(d["visual"]["params"])
            for p in d["points"]:
                cur.update(p["visual_params"] or {}); errs += scene_check.state_values_errors(man, cur, f"{where}{path} merged")
        if d.get("type") == "story":
            for b in d["beats"]:
                if b["visual"]["kind"] == "scene":
                    man, _ = manifest_for(b["visual"]["scene"]); errs += scene_check.state_values_errors(man, b["visual"]["params"], f"{where}{path} beat")
        if d.get("presentation") == "hotspots" and isinstance(d.get("visual"), dict) and d["visual"]["kind"] == "scene":
            man, _ = manifest_for(d["visual"]["scene"])
            errs += [f"{where}{path}: {e}" for e in scene_check.pin_alignment_errors(man, d["pins"])]
            inter = d.get("interaction") or {}
            for b in inter.get("bindings", []):
                errs += scene_check.state_values_errors(man, {**d["visual"]["params"], **b["set"]}, f"{where}{path} binding {b['pin_id']}")
            for k, v in (inter.get("after_evaluation") or {}).items():
                if v: errs += scene_check.state_values_errors(man, {**d["visual"]["params"], **v}, f"{where}{path} after_evaluation.{k}")
    return errs

errs = []
for f in fx: errs += scene_semantics(json.loads((FX / f["file"]).read_text()), f["file"])
for heading, obj in parsed:
    if '"kind": "scene"' in json.dumps(obj): errs += scene_semantics(obj, f"doc:{heading}")
check("scene visuals (fixtures + handoff): manifest checksum/view box/capabilities, schema + semantic + anchor stability, params/fallback/merged-teach/beat/binding/after-evaluation states, pin–anchor alignment", errs)

def recompute(session, hist):
    ex = {b["exercise"]["exercise_id"]: b["exercise"] for b in session["items"] if b["type"] == "exercise"}
    first = {}
    for a in hist["answers"]:
        if not a["is_retry"]: first.setdefault(a["exercise_id"], a)
    graded = [(ex[e], a) for e, a in first.items() if ex[e]["scoring"]["accuracy"] and a["result"] in ("correct", "incorrect")]
    def lay(L):
        g = [x for x in graded if x[0]["scoring"]["layer"] == L]
        if not g: return None
        c = sum(1 for _, a in g if a["result"] == "correct"); return {"correct": c, "total": len(g), "percent": round(100 * c / len(g))}
    c = sum(1 for _, a in graded if a["result"] == "correct"); t = len(graded); perfect = t >= 1 and c == t
    xp = [{"reason": "lesson_complete", "xp": 10}] + ([{"reason": "lesson_perfect", "xp": 3}] if perfect else [])
    xp += [{"reason": "recitation_passed", "xp": 3} for e, a in first.items() if ex[e]["type"] == "recite_verse" and a.get("recitation_passed")]
    xp += [{"reason": "daily_goal_met", "xp": 2}] if hist.get("daily_goal_met") else []
    return {"score": {"correct": c, "total": t, "percent": round(100 * c / t) if t else 0},
            "layers": {"understanding": lay("understand"), "applying": lay("apply"), "remembering": None},
            "xp": {"total": sum(x["xp"] for x in xp), "breakdown": xp}}

sess = next(o for h, o in parsed if isinstance(o, dict) and o.get("session_id") == "ses_91ab" and "items" in o)
fin = next(o for h, o in parsed if isinstance(o, dict) and o.get("session_id") == "ses_91ab" and "score" in o)
hist = json.loads((FX / "workflows/ses_91ab.json").read_text())
exp = recompute(sess, hist)
check("workflow: §6.5 finish example = recomputation from the §6.5 session + `fixtures/workflows/ses_91ab.json` (score, layers, perfect, XP)",
      [f"{k}: expected {exp[k]}, got {fin[k]}" for k in exp if fin[k] != exp[k]])

g = json.loads((FX / "challenges/group_challenge.json").read_text()); cfg = C.DuelConfig.model_validate(g["config"])
d_cfg = C.DuelConfig.model_validate({"question_count": 7, "time_limit_ms": 15000, "scoring": {"base": 100, "speed_bonus": 100, "rounding": "floor"}, "reveal_ms": 3000})
cerr = []
if C.challenge_points(True, 500, cfg) != 103: cerr.append(f"group half-up boundary gave {C.challenge_points(True, 500, cfg)} (expected 103)")
if round(2.5) == 2 and C.challenge_points(True, 500, cfg) == 100 + round(2.5): cerr.append("banker's rounding used")
if C.challenge_points(True, 5000, cfg) != 125: cerr.append("group 5000 ms ≠ 125")
if C.challenge_points(True, 7500, d_cfg) != 150: cerr.append("duel floor 7500 ms ≠ 150")
script = json.loads((FX / "challenges/group_ws_script.json").read_text()); tot = {}
for e in script:
    if e["type"] == "question_result":
        for p in e["data"]["players"]:
            e_p = C.challenge_points(p["correct"], 10000 - p["elapsed_ms"], cfg)
            if p["points"] != e_p: cerr.append(f"q{e['data']['question_index']} {p['user_id']}: {p['points']} ≠ {e_p}")
            tot[p["user_id"]] = tot.get(p["user_id"], 0) + p["points"]
        if {x["user_id"]: x["points"] for x in e["data"]["totals"]} != tot: cerr.append("running totals mismatch")
    if e["type"] in ("opponent_answered", "opponent_disconnected", "opponent_reconnected", "player_status") and "user_id" not in e["data"]: cerr.append(f"{e['type']} without user_id")
fin_g = next(e for e in script if e["type"] == "finished")["data"]["result"]; top = max(tot.values())
if sorted(fin_g["winner_user_ids"]) != sorted(u for u, v in tot.items() if v == top): cerr.append("winner_user_ids ≠ rank-1 players")
if g["config"]["reveal_ms"] != 2200: cerr.append("group reveal_ms ≠ 2200")
check("challenges: half-up boundary (500 ms of 10 000 → 103, not banker's 102), duel floor, every scripted point and total recomputed, per-player event identity, shared rank-1 winners, group reveal 2200 ms", cerr)

import decimal
D = decimal.Decimal
def q6(x): return D(str(x)).quantize(D("0.000001"), rounding=decimal.ROUND_HALF_UP)
def q2(x): return float(D(str(x)).quantize(D("0.01"), rounding=decimal.ROUND_HALF_UP))
# Decimal arithmetic, state stored at 6 decimals (backend §7.1)
F = {"correct": lambda m: q6(D(str(m)) + D("0.35") * (1 - D(str(m)))), "incorrect": lambda m: q6(D(str(m)) - D("0.25") * D(str(m))),
     "retry_correct": lambda m: q6(D(str(m)) + D("0.10") * (1 - D(str(m)))), "retry_incorrect": lambda m: q6(m),
     "recitation_passed": lambda m: q6(D(str(m)) + D("0.15") * (1 - D(str(m)))),
     "flashcard_hard": lambda m: q6(D(str(m)) + D("0.15") * (1 - D(str(m)))), "none": lambda m: q6(m)}
EVALUATION_CONTEXT = json.loads((FX / "EVALUATION_CONTEXT.json").read_text())
unlinked = []
def eval_rule(ev, where):
    context = EVALUATION_CONTEXT.get(where)
    if context is None:
        unlinked.append(where)
        return None
    from contextual import mastery_rule
    return mastery_rule(context["exercise"], context["answer"], context["kind"], ev["correct"])
merr = []; n_ev = 0
def check_ev(ev, where):
    global n_ev
    rule = eval_rule(ev, where)
    if rule is None: return
    n_ev += 1
    if rule == "none" and ev["mastery_changes"]: merr.append(f"{where}: unexpected mastery change"); return
    for mc in ev["mastery_changes"]:
        exp_after = q2(F[rule](mc["before"]))
        if mc["after"] != exp_after: merr.append(f"{where}: {mc['before']}→{mc['after']} expected {exp_after} ({rule})")
for f in fx:
    if f["model"] == "AnswerEvaluation":
        check_ev(json.loads((FX / f["file"]).read_text()), f["file"])
for heading, obj in parsed:
    if isinstance(obj, dict) and {"exercise_id", "correct_answer", "mastery_changes"} <= set(obj):
        check_ev(obj, f"doc:{heading}")
# workflow mastery simulation
state = dict(hist["initial_mastery"]); start = dict(state)
concepts = {b["exercise"]["exercise_id"]: (b["exercise"]["concept_ids"], b["exercise"]["type"]) for b in sess["items"] if b["type"] == "exercise"}
for a in hist["answers"]:
    cids, typ = concepts[a["exercise_id"]]
    if a["is_retry"]: rule = "retry_correct" if a["result"] == "correct" else "retry_incorrect"
    elif typ == "recite_verse": rule = "recitation_passed" if a.get("recitation_passed") else "none"
    else: rule = a["result"]
    for c in cids: state[c] = F[rule](state[c])
summary = {m["concept_id"]: (m["before"], m["after"]) for m in fin["mastery_summary"]}
for c in state:
    if summary.get(c) != (q2(start[c]), q2(state[c])): merr.append(f"mastery_summary {c}: got {summary.get(c)}, expected {(q2(start[c]), q2(state[c]))}")
ev58 = next(o for h, o in parsed if h.startswith("5.8") and isinstance(o, dict) and "mastery_changes" in o)
if [(m["before"], m["after"]) for m in ev58["mastery_changes"]] != [(0.4, 0.3)]: merr.append("§5.8 snapshot ≠ first-attempt update of the workflow")
check(f"mastery: {n_ev} linked fixture evaluation changes and the §6.5 `mastery_summary` (session start → end incl. retry and recitation) match backend §7.1 with half-up 2-decimal reporting", merr)

rec = json.loads((FX / "sessions/recovery_after_early_retry.json").read_text()); rerr = []
r1 = recovery.resume_point(rec["items"], rec["answers"])
if {k: r1[k] for k in ("stage", "next_item_index", "retry_queue")} != {"stage": "completion", "next_item_index": None, "retry_queue": []}: rerr.append(f"after early retry: {r1}")
firsts = [a for a in rec["answers"] if not a["is_retry"]]
r2 = recovery.resume_point(rec["items"], firsts)
if r2["stage"] != "retries" or r2["retry_queue"] != [firsts[0]["exercise_id"]]: rerr.append(f"before retry: {r2}")
idx = [i for i, b in enumerate(rec["items"]) if b["type"] == "exercise"]
r3 = recovery.resume_point(rec["items"], firsts[:2])
if r3["next_item_index"] != idx[1] + 1: rerr.append(f"mid-lesson: {r3}")
r4 = recovery.resume_point(rec["items"], firsts[:2] + [dict(firsts[0], is_retry=True, result="correct")])
if r4["next_item_index"] != idx[1] + 1: rerr.append(f"early retry mid-lesson rewound the cursor: {r4}")
bad_retry = firsts + [dict(firsts[0], is_retry=True, result="incorrect")]
r5 = recovery.resume_point(rec["items"], bad_retry)
if r5["retry_queue"] != [] or r5["stage"] != "completion": rerr.append(f"incorrect retry was requeued: {r5}")
gap = [firsts[0], firsts[2]]
r6 = recovery.resume_point(rec["items"], gap)
if r6["next_item_index"] != idx[0] + 1 or not r6["gap"]: rerr.append(f"gap: {r6}")
check("fresh-device recovery (`tools/recovery.py`): early correct retry, early **incorrect** retry (spent, not requeued), unrecorded retry (still queued), mid-lesson cursor, defensive gap (resume before the earliest unanswered exercise), no rewind by retries", rerr)
R += ["", "## 3. Semantic checks"] + sem + ["- ✓ feedback-mode history redaction (`immediate` / `end` active / `end` finished / `none`) — enforced by the `Session` model rules in stage 2 on `fixtures/sessions/history_*.json`"]

def summary_ok(m):
    return (m["before"], m["after"]) != (q2(start[m["concept_id"]]), q2(state[m["concept_id"]]))
neg = []
def expect_exception(label, fn):
    global fail
    try:
        fn()
        neg.append(f"- ✗ NOT rejected: {label}"); fail += 1
    except (ValidationError, ValueError, AssertionError):
        neg.append(f"- ✓ rejected: {label}")

def expect_errors(label, fn):
    global fail
    errors = fn()
    if not isinstance(errors, list):
        raise TypeError("semantic negative checks must return an error list")
    if errors:
        neg.append(f"- ✓ rejected: {label}")
    else:
        neg.append(f"- ✗ NOT rejected: {label}"); fail += 1

# A successful truthy model MUST produce a failed negative check.
before = fail
expect_exception("HARNESS valid model control (must not be rejected)",
                 lambda: C.AnswerRecorded(exercise_id="control", recorded=True))
if fail != before + 1:
    raise AssertionError("negative harness accepted its own success control")
fail = before
neg[-1] = "- ✓ harness control: successful truthy model is not counted as rejected"

exd = json.loads((FX / "exercises/categorize__day_arc/exercise.json").read_text())
leak = copy.deepcopy(exd); leak["payload"]["answer_key"] = {"x": 1}
expect_exception("answer key inside a learner payload", lambda: C.Exercise.model_validate(leak))
ph = copy.deepcopy(exd); ph["payload"]["categories"][0]["phase"] = "night"
expect_exception("day_arc slots out of order", lambda: C.Exercise.model_validate(ph))
rv = json.loads((FX / "exercises/recite_verse/exercise.json").read_text()); rv["scoring"]["accuracy"] = True
expect_exception("recitation counted in accuracy", lambda: C.Exercise.model_validate(rv))
ss = json.loads((FX / "sessions/session_practice_all_types.json").read_text())
four = copy.deepcopy(ss); src = four["sources"][0]; four["sources"] = [dict(src, source_id=f"s{i}") for i in range(4)]; four["source_count"] = 4
expect_exception("four content sources", lambda: C.Session.model_validate(four))
gg = copy.deepcopy(g); gg["config"]["scoring"]["rounding"] = "floor"
expect_exception("group preset with floor rounding", lambda: C.Duel.model_validate(gg))
sc = json.loads((FX / "scenes/session_test_scene_lesson.json").read_text())
hot = next(b for b in sc["items"] if b["type"] == "exercise")["exercise"]
v = copy.deepcopy(sc["items"][0]["visual"]); v["fallback_image"]["height"] = 1200
expect_exception("scene fallback with a different proportion", lambda: C.Visual.model_validate(v))
mis = copy.deepcopy(hot); [p.update(x_pct=20.0, y_pct=20.0) for p in mis["payload"]["pins"] if p["pin_id"] == "pin_well"]
expect_errors("same proportion but the target pin is not over its object (pin_well at 20%/20%)", lambda: scene_semantics(mis, "neg"))
fbp = copy.deepcopy(hot); fbp["payload"]["visual"]["fallback_params"] = {"beat": 0, "focus": -1}
expect_exception("hotspot fallback rendered at a different state than the exercise", lambda: C.Exercise.model_validate(fbp))
man = json.loads((FX / "scenes/scn_test_desert_well.v2.scene.json").read_text())
mv = copy.deepcopy(man); next(l for l in mv["layers"] if l["id"] == "well")["state_rules"] = [{"when": {"beat": {"gte": 1}}, "set": {"x": 300}}]
expect_errors("anchored object that moves by state", lambda: scene_check.check(mv))
mv2 = copy.deepcopy(man); next(l for l in mv2["layers"] if l["id"] == "palm")["tracks"] = [{"property": "translate_x", "duration_ms": 2000, "easing": "linear", "loop": "repeat", "keyframes": [{"t": 0, "v": 0}, {"t": 1, "v": 400}]}]
expect_errors("anchored object with a large translate track", lambda: scene_check.check(mv2))
ub = copy.deepcopy(hot); ub["payload"]["interaction"]["bindings"][0]["pin_id"] = "pin_nowhere"
expect_exception("binding to an unknown pin", lambda: C.Exercise.model_validate(ub))
ob = copy.deepcopy(hot); ob["payload"]["interaction"]["bindings"][0]["set"] = {"focus": 9}
expect_errors("binding to an out-of-range scene state", lambda: scene_semantics(ob, "neg"))
hh = json.loads((FX / "sessions/history_end_active.json").read_text()); hh["answers"][0]["result"] = "correct"
expect_exception("end-mode active session leaking a result in history", lambda: C.Session.model_validate(hh))
hn = json.loads((FX / "sessions/history_none_finished.json").read_text()); hn["answers"][0]["result"] = "incorrect"
expect_exception("none-mode session leaking a result after finish", lambda: C.Session.model_validate(hn))
bad_fin = copy.deepcopy(fin); bad_fin["score"] = {"correct": 2, "total": 3, "percent": 67}
expect_errors("finish result counting the recitation (2/3)", lambda: [k for k in exp if bad_fin[k] != exp[k]])
bt = {"kind": "builtin", "key": "day_arc", "version": 1, "params": {"highlight": 7}, "image": None, "scene": None, "fallback_image": None, "fallback_params": None, "alt": "x", "overlays": []}
expect_exception("built-in param out of range", lambda: C.Visual.model_validate(bt))
mu = copy.deepcopy(man); mu["required_capabilities"].append("fx.water/1")
expect_errors("scene using an unreleased capability", lambda: scene_check.check(mu))
dv = {"scene_id": "x", "origin": "generated_scene", "visual": sc["items"][0]["visual"], "audit": None, "attempts": 1, "previews": None}
expect_exception("generated_scene draft visual without previews", lambda: C.DraftVisual.model_validate(dv))
rs = json.loads((FX / "sessions/recovery_after_early_retry.json").read_text())
two = copy.deepcopy(rs); two["answers"].append(dict(two["answers"][-1]))
expect_exception("history with two retry records for one exercise (attempt identity must be unique)", lambda: C.Session.model_validate(two))
rc = copy.deepcopy(rs); rc["answers"].append({**rc["answers"][1], "is_retry": True})
expect_exception("a retry after a correct first attempt", lambda: C.Session.model_validate(rc))
oo = copy.deepcopy(rs); oo["answers"] = [oo["answers"][1], oo["answers"][0]] + oo["answers"][2:]
expect_exception("first attempts out of authored order", lambda: C.Session.model_validate(oo))
old = copy.deepcopy(fin); old["mastery_summary"][0]["after"] = 0.62
expect_errors("finish mastery_summary 0.62 (old example, ignores the formulas)", lambda: [m for m in old["mastery_summary"] if summary_ok(m)])
R += ["", "## 4. Negative tests"] + neg
R += ["", "## Contextual coverage limits", f"- Unlinked handoff evaluations skipped by the generic mastery pass: {unlinked}. The separate workflow recomputation still checks the authored finish summary."]

import export_schema
schema = export_schema.export_all()
export_schema.write()
R += ["", "## 5. Runtime verification", "- None. Not run for this report: Flutter app (mock or live), `packages/qabas_scene` renderer, `tools/scene_preview`, backend, devices.",
      "", "## 6. Exported schema", f"- `contract/qabas_contract.schema.json`: {len(schema)} models."]
files = sorted(p for p in ROOT.rglob("*") if p.is_file() and p.name not in ("VALIDATION_REPORT.md", "SHA256SUMS") and "__pycache__" not in p.parts)
sums = "".join(f"{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(ROOT)}\n" for p in files)
pkg = hashlib.sha256(sums.encode()).hexdigest()
R += ["", "## 7. Package identity", f"- Files covered: {len(files)} (checksums in `SHA256SUMS`)", f"- Package digest (sha256 of the `SHA256SUMS` content): `{pkg}`",
      f"- Result: **{'PASS' if not fail else f'FAIL ({fail})'}**"]
(ROOT / "SHA256SUMS").write_text(sums)
(ROOT / "VALIDATION_REPORT.md").write_text("\n".join(R) + "\n", encoding="utf-8")
print("\n".join(R)); sys.exit(1 if fail else 0)
