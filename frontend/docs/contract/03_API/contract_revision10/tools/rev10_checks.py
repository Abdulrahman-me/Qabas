"""Revision 10 focused checks: new roots, typed shapes, review digest, schema integrity and the
curriculum/learning-design amendment (plans, arcs, sentence roles, claim basis, Soft Locks, onboarding) and the
lesson-composition refinement (arc techniques, primary mode, teaching scenarios) and the lesson-depth
refinement (central question, supporting understandings, depth profile) and the pre-generation audit
(semantic review of scriptural support, scholarly QA flags, media publication gate, visual readiness).

Read-only except for REV10_CHECKS.json. Complements tools/validate.py (examples + fixtures)
and tools/regression.py (revision 9 suite, unchanged). Exit status 1 on any failure.
"""
import copy
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'contract'), str(ROOT / 'tools')]
import jsonschema  # noqa: E402
from pydantic import ValidationError  # noqa: E402
import qabas_contract as C  # noqa: E402
from export_schema import export_all  # noqa: E402
from review import review_digest  # noqa: E402

results = []


def test(label, fn):
    try:
        fn()
        results.append({'label': label, 'passed': True})
    except Exception as e:  # noqa: BLE001 - every failure is reported
        results.append({'label': label, 'passed': False, 'error': f'{type(e).__name__}: {e}'})


def rejects(model, obj):
    def run():
        try:
            model.model_validate(obj)
        except (ValidationError, ValueError):
            return
        raise AssertionError('invalid input was accepted')
    return run


def accepts(model, obj):
    return lambda: model.model_validate(obj)


def doc_examples():
    out, heading = [], ''
    text = (ROOT.parent / 'API_REQUIREMENTS.md').read_text(encoding='utf-8')
    for m in re.finditer(r'^(#{2,4} [^\n]*)$|```json\n(.*?)```', text, re.S | re.M):
        if m.group(1):
            heading = m.group(1).strip('# ').strip()
        else:
            out.append((heading, json.loads(m.group(2))))
    return out


EX = doc_examples()


def example(heading, index=0):
    return copy.deepcopy([o for h, o in EX if h == heading][index])


SCHEMAS = export_all()

# ---------------------------------------------------------------- schema integrity
for name, schema in SCHEMAS.items():
    def resolvable(schema=schema, name=name):
        text = json.dumps(schema)
        for ref in set(re.findall(r'"\$ref": "#/\$defs/([^"]+)"', text)):
            if ref not in schema.get('$defs', {}):
                raise AssertionError(f'{name}: unresolved $ref {ref}')
        jsonschema.Draft202012Validator.check_schema(schema)
    test(f'schema root {name}: valid draft 2020-12 with resolvable refs', resolvable)

GENERIC_ALLOWED = {
    # state maps and free-form details are intentionally open
    ('Visual', 'params'), ('Visual', 'fallback_params'), ('TeachPoint', 'visual_params'), ('Binding', 'set'),
    ('AfterEvaluation', 'correct'), ('AfterEvaluation', 'incorrect'), ('PreviewFrame', 'state'), ('ErrorBody', 'details'),
    ('Exercise', 'payload'), ('ReviewerExercise', 'payload'), ('WsEvent', 'data'), ('WsClientMessage', 'data'),
    ('ConvCreate', 'context'), ('Conversation', 'context'),
}


def no_unexpected_generic_objects():
    """Every object-typed field outside the allow-list must be a typed model (rev 10 goal)."""
    offenders = set()
    for model in [m for m in vars(C).values() if isinstance(m, type) and issubclass(m, C.M)]:
        for field, info in model.model_fields.items():
            ann = str(info.annotation)
            if 'dict[str, Any]' in ann or 'Dict[str, Any]' in ann:
                key = (model.__name__, field)
                if key not in GENERIC_ALLOWED and not any(model.__name__ == base and field == f for base, f in GENERIC_ALLOWED):
                    offenders.add(key)
    if offenders:
        raise AssertionError(f'generic objects remain: {sorted(offenders)}')


test('no undocumented generic dict fields remain in public models', no_unexpected_generic_objects)

ENDPOINT_ROOTS = {
    'POST /auth/guest': ('GuestReq', 'AuthResp'), 'POST /auth/reviewer': ('ReviewerReq', 'AuthResp'),
    'POST /onboarding': ('OnboardingReq', 'OnboardingResp'), 'GET /me': (None, 'User'), 'PATCH /me': ('MePatch', 'User'),
    'GET /me/stats': (None, 'Stats'), 'GET /me/activity': (None, 'Activity'), 'GET /me/quests': (None, 'Quests'),
    'GET /me/achievements': (None, 'Achievements'), 'GET /me/concepts': (None, 'ConceptPage'),
    'GET /journey': (None, 'Journey'), 'GET /units/{id}/guide': (None, 'Guide'), 'GET /journey/next': (None, 'NextStep'),
    'GET /lessons/{id}': (None, 'LessonRead'), 'POST /sessions': ('SessionCreate', 'Session'),
    'GET /sessions/{id}': (None, 'Session'), 'POST /sessions/{id}/answers': ('AnswerSubmit', 'AnswerEvaluation'),
    'POST /sessions/{id}/finish': ('FinishReq', 'SessionResult'), 'POST /recitation/checks': (None, 'RecitationCheck'),
    'GET /glossary': (None, 'GlossaryPage'), 'GET /glossary/{id}': (None, 'TermCard'),
    'POST /raqeeb/conversations': ('ConvCreate', 'Conversation'), 'GET /raqeeb/conversations': (None, 'ConversationPage'),
    'GET /raqeeb/conversations/{id}': (None, 'ConvDetail'), 'POST /raqeeb/conversations/{id}/messages': (None, 'PostMessageResp'),
    'GET /raqeeb/messages/{id}': (None, 'AssistantMessage'), 'POST /raqeeb/messages/{id}/feedback': ('FeedbackReq', None),
    'GET /leagues/current': (None, 'League'), 'GET /friends': (None, 'FriendPage'), 'POST /friends/invites': (None, 'Invite'),
    'POST /friends/invites/accept': ('InviteAccept', 'Friend'), 'POST /duels': ('DuelCreate', 'Duel'),
    'GET /duels/invitations': (None, 'InvitationPage'), 'POST /duels/{id}/accept': (None, 'Duel'), 'GET /duels/{id}': (None, 'Duel'),
    'GET /duels': (None, 'DuelPage'), 'POST /duels/{id}/async': (None, 'Duel'), 'POST /duels/{id}/async/next': (None, 'AsyncNext'),
    'POST /duels/{id}/async/answer': ('AsyncAnswer', 'AsyncAnswerResp'), 'POST /admin/factory/runs': ('RunCreate', 'FactoryRun'),
    'GET /admin/factory/runs': (None, 'RunPage'), 'GET /admin/factory/runs/{id}': (None, 'FactoryRun'),
    'POST /admin/factory/runs/{id}/gate1': ('Gate1', 'FactoryRun'), 'POST /admin/factory/runs/{id}/gate2': ('Gate2', 'FactoryRun'),
    'GET /admin/blind-test/next': (None, 'BlindPair'), 'POST /admin/blind-test/{id}': ('BlindAnswer', None),
    'GET /admin/metrics': (None, 'Metrics'), 'WS client': ('WsClientMessage', None), 'WS server': (None, 'WsEvent'),
    'error envelope': (None, 'ErrorEnvelope'),
}


def every_endpoint_body_exported():
    missing = sorted({r for pair in ENDPOINT_ROOTS.values() for r in pair if r and r not in SCHEMAS})
    if missing:
        raise AssertionError(f'missing exported roots: {missing}')


test('every documented request/response body is an exported schema root', every_endpoint_body_exported)


def pydantic_and_schema_agree():
    """Every API example validated by its model also validates against that model's exported JSON Schema."""
    pairs = [('`GET /admin/metrics`', 'Metrics'), ('`GET /me/stats`', 'Stats'), ('`GET /admin/factory/runs/{run_id}` → `FactoryRun`', 'FactoryRun'),
             ('`POST /admin/factory/runs/{run_id}/gate1`', 'Gate1'), ('`POST /admin/factory/runs/{run_id}/gate2`', 'Gate2'),
             ('`PATCH /me`', 'MePatch'), ('`GET /raqeeb/conversations/{conversation_id}`', 'ConvDetail'),
             ('`POST /sessions/{session_id}/finish`', 'SessionResult'), ('`GET /me/achievements`', 'Achievements'),
             ('`GET /duels/invitations`', 'InvitationPage'), ('`GET /me/concepts`', 'ConceptPage')]
    for heading, root in pairs:
        objs = [o for h, o in EX if h == heading]
        if not objs:
            raise AssertionError(f'no example under {heading}')
        hits = 0
        for obj in objs:
            try:
                getattr(C, root, None) and getattr(C, root).model_validate(obj)
            except (ValidationError, ValueError, AttributeError):
                continue
            jsonschema.Draft202012Validator(SCHEMAS[root]).validate(obj)
            hits += 1
        if not hits:
            raise AssertionError(f'{root}: no example validated')
    for obj in example('8.1 Client → server'):
        jsonschema.Draft202012Validator(SCHEMAS['WsClientMessage']).validate(obj)
    for heading in ('`GET /raqeeb/messages/{message_id}`',):
        for obj in [o for h, o in EX if h == heading]:
            if isinstance(obj, dict) and obj.get('status') in ('processing', 'failed', 'completed'):
                C.AssistantMessage.model_validate(obj)
                jsonschema.Draft202012Validator(SCHEMAS['AssistantMessage']).validate(obj)


test('pydantic models and exported schemas accept the same API examples', pydantic_and_schema_agree)


def schema_rejects_bad_ws_client():
    bad = {'type': 'answer', 'data': {'question_index': 0, 'answer': {'rating': 'good'}}}
    try:
        jsonschema.Draft202012Validator(SCHEMAS['WsClientMessage']).validate(bad)
    except jsonschema.ValidationError:
        return
    raise AssertionError('schema accepted a non-closed answer on the challenge socket')


test('exported WsClientMessage schema rejects a flashcard rating as a challenge answer', schema_rejects_bad_ws_client)

# ---------------------------------------------------------------- MePatch
test('MePatch accepts a partial update', accepts(C.MePatch, {'language': 'en', 'daily_goal_minutes': 15}))
test('MePatch rejects an empty body', rejects(C.MePatch, {}))
test('MePatch rejects explicit null', rejects(C.MePatch, {'timezone': None}))
test('MePatch rejects a 1-character display name', rejects(C.MePatch, {'display_name': 'a'}))
test('MePatch rejects unknown fields (local-only preferences)', rejects(C.MePatch, {'reduced_motion': True}))
test('MePatch rejects an unsupported daily goal', rejects(C.MePatch, {'daily_goal_minutes': 7}))

# ---------------------------------------------------------------- WebSocket client messages
test('ws client ready', accepts(C.WsClientMessage, {'type': 'ready', 'data': {}}))
test('ws client true/false answer', accepts(C.WsClientMessage, {'type': 'answer', 'data': {'question_index': 2, 'answer': {'value': False}}}))
test('ws client rejects unknown type', rejects(C.WsClientMessage, {'type': 'chat', 'data': {}}))
test('ws client rejects answer without index', rejects(C.WsClientMessage, {'type': 'answer', 'data': {'answer': {'option_id': 'a'}}}))
test('ws client rejects negative index', rejects(C.WsClientMessage, {'type': 'answer', 'data': {'question_index': -1, 'answer': {'option_id': 'a'}}}))
test('ws client rejects data on ping', rejects(C.WsClientMessage, {'type': 'ping', 'data': {'x': 1}}))

# ---------------------------------------------------------------- factory run, gates and digest
RUN = example('`GET /admin/factory/runs/{run_id}` → `FactoryRun`')
FRAG = example('Gate 2 draft (`status = awaiting_gate2`)')
G1 = example('`POST /admin/factory/runs/{run_id}/gate1`')
G2 = example('`POST /admin/factory/runs/{run_id}/gate2`')


def digest_matches_examples():
    if review_digest(RUN) != RUN['review_digest'] or G1['review_digest'] != RUN['review_digest']:
        raise AssertionError('Gate 1 example digest does not match review.py')
    run2 = {'status': 'awaiting_gate2', 'run_id': RUN['run_id'], 'draft': FRAG['draft'], 'qa_report': FRAG['qa_report']}
    if review_digest(run2) != G2['review_digest']:
        raise AssertionError('Gate 2 example digest does not match review.py')


test('API example digests equal review.py output', digest_matches_examples)


def digest_sensitive_and_stable():
    a = review_digest(RUN)
    reordered = json.loads(json.dumps(RUN))
    reordered['plan'] = dict(reversed(list(reordered['plan'].items())))
    if review_digest(reordered) != a:
        raise AssertionError('key order changed the digest')
    edited = copy.deepcopy(RUN)
    edited['plan']['estimated_minutes'] += 1
    if review_digest(edited) == a:
        raise AssertionError('a plan edit did not change the digest')
    other = copy.deepcopy(RUN)
    other['run_id'] = 'run_43'
    if review_digest(other) == a:
        raise AssertionError('digest is not bound to the run')
    try:
        review_digest({**RUN, 'status': 'running'})
    except ValueError:
        return
    raise AssertionError('digest computed for a run that is not at a gate')


test('review digest ignores key order, changes on edits, binds run_id, refuses non-gate runs', digest_sensitive_and_stable)
test('FactoryRun example validates', accepts(C.FactoryRun, RUN))
test('FactoryRun at a gate without digest is rejected', rejects(C.FactoryRun, {**RUN, 'review_digest': None}))
test('running FactoryRun with a digest is rejected', rejects(C.FactoryRun, {**RUN, 'status': 'running'}))
test('published FactoryRun without published ref is rejected', rejects(C.FactoryRun, {**RUN, 'status': 'published', 'review_digest': None}))
test('failed FactoryRun without error is rejected', rejects(C.FactoryRun, {**RUN, 'status': 'failed', 'review_digest': None}))
test('FactoryRun rejects an unknown stage', rejects(C.FactoryRun, {**RUN, 'stage': 'polish'}))
test('Gate 1 rejects an edited plan with reject', rejects(C.Gate1, {**G1, 'decision': 'reject', 'plan': RUN['plan']}))
test('Gate 1 rejects a malformed digest', rejects(C.Gate1, {**G1, 'review_digest': 'abc'}))
test('Gate 1 rejects a missing digest', rejects(C.Gate1, {k: v for k, v in G1.items() if k != 'review_digest'}))
test('Gate 2 request_changes needs a reason', rejects(C.Gate2, {**G2, 'decision': 'request_changes', 'sentence_edits': [], 'reason': ' '}))
test('Gate 2 edits only with approve', rejects(C.Gate2, {**G2, 'decision': 'reject'}))
test('Gate 2 rejects a sentence edit without text', rejects(C.Gate2, {**G2, 'sentence_edits': [{**G2['sentence_edits'][0], 'new_text': ''}]}))
test('QA issue accepts kind validation', accepts(C.QAIssue, {'severity': 'blocker', 'kind': 'validation', 'location': {'sentence_id': None, 'exercise_id': 'ex_1', 'scene_id': None}, 'message': '4 content sources'}))
test('supported claim without supporting evidence is rejected', rejects(C.Claim, {'claim_id': 'c', 'text': 't', 'status': 'supported', 'evidence': []}))

MCQ = {'exercise_id': 'ex_r', 'type': 'multiple_choice', 'concept_ids': ['con_a'], 'prompt': [{'type': 'text', 'text': 'q'}],
       'time_limit_ms': None, 'scoring': {'accuracy': True, 'combo': True, 'layer': 'understand'}, 'framing': None,
       'payload': {'options': [{'option_id': 'o1', 'spans': [{'type': 'text', 'text': 'a'}]}, {'option_id': 'o2', 'spans': [{'type': 'text', 'text': 'b'}]}]},
       'answer_key': {'option_id': 'o1'}, 'option_misconceptions': {'o2': 'mis_x'}, 'duel_eligible': True}
test('ReviewerExercise accepts an MCQ with an option key', accepts(C.ReviewerExercise, MCQ))
test('ReviewerExercise rejects a missing key on an MCQ', rejects(C.ReviewerExercise, {**MCQ, 'answer_key': None}))
test('ReviewerExercise rejects a wrong-shaped key', rejects(C.ReviewerExercise, {**MCQ, 'answer_key': {'value': True}}))
FLASH = {**MCQ, 'type': 'flashcard', 'scoring': {'accuracy': True, 'combo': False, 'layer': 'remember'},
         'payload': {'front': [{'type': 'text', 'text': 'f'}], 'back': [{'type': 'text', 'text': 'b'}]},
         'answer_key': {'option_id': 'o1'}, 'option_misconceptions': {}, 'duel_eligible': False}
test('ReviewerExercise rejects a stored key on a flashcard', rejects(C.ReviewerExercise, FLASH))
test('control: flashcard without a stored key is accepted', accepts(C.ReviewerExercise, {**FLASH, 'answer_key': None}))
SCEN = {**MCQ, 'type': 'scenario', 'payload': {'situation': [{'type': 'text', 'text': 's'}], 'options': MCQ['payload']['options']}}
test('control: scenario that is not duel eligible is accepted', accepts(C.ReviewerExercise, {**SCEN, 'duel_eligible': False}))
test('control: Gate 2 reject without edits is accepted', accepts(C.Gate2, {**G2, 'decision': 'reject', 'sentence_edits': []}))
test('control: Gate 2 request_changes with a reason is accepted', accepts(C.Gate2, {**G2, 'decision': 'request_changes', 'sentence_edits': [], 'reason': 'Simplify beat 2'}))
test('control: Gate 1 reject without plan is accepted', accepts(C.Gate1, {**G1, 'decision': 'reject'}))
test('ReviewerExercise rejects duel eligibility for an open type', rejects(C.ReviewerExercise, {**MCQ, 'type': 'scenario',
     'payload': {'situation': [{'type': 'text', 'text': 's'}], 'options': MCQ['payload']['options']}}))

# ---------------------------------------------------------------- learner shapes
FIN = example('`POST /sessions/{session_id}/finish`', 1)
test('SessionResult example validates', accepts(C.SessionResult, FIN))
test('SessionResult rejects xp.total != sum(breakdown)', rejects(C.SessionResult, {**FIN, 'xp': {'total': 16, 'breakdown': FIN['xp']['breakdown']}}))
test('SessionResult rejects an unknown XP reason', rejects(C.SessionResult, {**FIN, 'xp': {'total': 1, 'breakdown': [{'reason': 'bonus', 'xp': 1}]}}))
test('SessionResult rejects passed on a lesson', rejects(C.SessionResult, {**FIN, 'passed': True}))
test('SessionResult rejects review_items on a lesson', rejects(C.SessionResult, {**FIN, 'review_items': []}))
test('unit_test SessionResult needs passed and review_items', rejects(C.SessionResult, {**FIN, 'kind': 'unit_test', 'passed': True}))
REC = example('`POST /recitation/checks` (multipart/form-data)', 0)
test('RecitationCheck example validates', accepts(C.RecitationCheck, REC))
test('RecitationCheck rejects a summary that miscounts words', rejects(C.RecitationCheck, {**REC, 'summary': {**REC['summary'], 'correct': 3}}))
test('RecitationCheck rejects passed with substitutions', rejects(C.RecitationCheck, {**REC, 'passed': True}))
UNC = example('`POST /recitation/checks` (multipart/form-data)', 2)
test('unclear RecitationCheck rejects words', rejects(C.RecitationCheck, {**UNC, 'words': REC['words'], 'summary': REC['summary']}))
STATS = example('`GET /me/stats`')
test('Stats accepts league null (no league this week)', accepts(C.Stats, {**STATS, 'league': None}))
test('Stats rejects an untyped league object', rejects(C.Stats, {**STATS, 'league': {'rank': 4}}))
CONV = example('`GET /raqeeb/conversations/{conversation_id}`')
PROC = example('`GET /raqeeb/messages/{message_id}`', 0)
FAILED = example('`GET /raqeeb/messages/{message_id}`', 1)
test('ConvDetail accepts mixed typed history', accepts(C.ConvDetail, {**CONV, 'messages': [
    example('`POST /raqeeb/conversations/{conversation_id}/messages` (multipart/form-data)')['user_message'], PROC, FAILED]}))
test('ConvDetail rejects an untyped message', rejects(C.ConvDetail, {**CONV, 'messages': [{'role': 'assistant', 'status': 'done'}]}))
test('failed message rejects an unknown error code', rejects(C.AssistantMessage, {**FAILED, 'error': {'code': 'boom', 'message': 'x'}}))
test('failed message accepts input_unreadable', accepts(C.AssistantMessage, {**FAILED, 'error': {'code': 'input_unreadable', 'message': 'x'}}))
ASYNC = example('Async fallback', 1)
test('AsyncAnswer accepts a timeout (null answer)', accepts(C.AsyncAnswer, {**ASYNC, 'answer': None}))
test('AsyncAnswer rejects a non-closed answer', rejects(C.AsyncAnswer, {**ASYNC, 'answer': {'order': ['a']}}))
JOUR = example('`GET /journey`')
test('Journey rejects an untyped pretest state', rejects(C.Journey, {**JOUR, 'units': [{**JOUR['units'][0], 'pretest': {'state': 'done'}}] + JOUR['units'][1:]}))
MET = example('`GET /admin/metrics`')
test('Metrics accepts no benchmark yet and empty averages', accepts(C.Metrics, {**MET, 'raqeeb_benchmark': None,
     'factory': {**MET['factory'], 'avg_generation_minutes': None, 'avg_review_minutes': None}}))

test('control: unit_test SessionResult with passed and review_items is accepted', accepts(C.SessionResult, {**FIN, 'kind': 'unit_test', 'passed': False, 'layers': FIN['layers'], 'review_items': [
    {'exercise_id': 'ex_u2_l1_01', 'correct': True, 'correct_answer': {'option_id': 'opt_a'}, 'explanation': [{'type': 'text', 'text': 'x'}], 'source_ids': []}]}))
test('control: ConvDetail with a completed answer is accepted', accepts(C.ConvDetail, {**CONV, 'messages': [example('`GET /raqeeb/messages/{message_id}`', 3)]}))

# ---------------------------------------------------------------- curriculum and learning-design amendment
import contextual as X  # noqa: E402


def require_true(value):
    if not value:
        raise AssertionError('condition not met')


PLAN = RUN['plan']
DRAFT = FRAG['draft']
L = lambda t: {'ar': t, 'en': t}  # noqa: E731
test('LessonPlan example with arc, reasoning tools, standalone flag and budgets validates', accepts(C.LessonPlan, PLAN))
test('LessonPlan rejects a missing primary learning outcome', rejects(C.LessonPlan, {k: v for k, v in PLAN.items() if k != 'primary_learning_outcome'}))
test('LessonPlan rejects an empty primary learning outcome', rejects(C.LessonPlan, {**PLAN, 'primary_learning_outcome': L(' ')}))
test('LessonPlan rejects more than three intro objectives', rejects(C.LessonPlan, {**PLAN, 'objectives': PLAN['objectives'] * 4}))
test('LessonPlan rejects standalone eligibility with mandatory prerequisites', rejects(C.LessonPlan, {**PLAN, 'standalone_eligible': True}))
test('control: standalone lesson without prerequisites is accepted', accepts(C.LessonPlan, {**PLAN, 'standalone_eligible': True, 'prerequisite_concept_ids': []}))
test('LessonPlan rejects a concept that is both prerequisite and introduced', rejects(C.LessonPlan, {**PLAN, 'introduced_concept_ids': ['con_allah_one']}))
test('LessonPlan rejects an unknown reasoning tool', rejects(C.LessonPlan, {**PLAN, 'reasoning_tools': [{'tool': 'metaphysics', 'justification': L('x')}]}))
test('LessonPlan rejects an unjustified reasoning tool', rejects(C.LessonPlan, {**PLAN, 'reasoning_tools': [{'tool': 'observation', 'justification': L('')}]}))
test('LessonPlan rejects a repeated reasoning tool', rejects(C.LessonPlan, {**PLAN, 'reasoning_tools': PLAN['reasoning_tools'][:1] * 2}))
test('control: LessonPlan with no reasoning tools (none needed) is accepted', accepts(C.LessonPlan, {**PLAN, 'reasoning_tools': []}))
test('LessonPlan rejects an exercise budget of 1', rejects(C.LessonPlan, {**PLAN, 'exercise_budget': 1}))
test('LessonPlan rejects an exercise budget of 7', rejects(C.LessonPlan, {**PLAN, 'exercise_budget': 7}))
ARC = PLAN['lesson_arc']
test('LessonArc rejects a single-step arc', rejects(C.LessonArc, {**ARC, 'steps': ARC['steps'][:1]}))
test('LessonArc rejects duplicate step ids', rejects(C.LessonArc, {**ARC, 'steps': [ARC['steps'][0], ARC['steps'][0]]}))
test('LessonArc rejects an arc without any interactive step', rejects(C.LessonArc, {**ARC, 'steps': [{**st, 'interactive': False} for st in ARC['steps']]}))
test('control: a custom arc pattern name is accepted (patterns are not a closed list)', accepts(C.LessonArc, {**ARC, 'pattern': 'two-voices'}))
SM = {'sentence_id': 's', 'role': 'claim', 'claim_ids': ['clm_1']}
test('claim sentence without a claim is rejected', rejects(C.SentenceClaims, {**SM, 'claim_ids': []}))
test('hypothetical sentence that links a claim is rejected', rejects(C.SentenceClaims, {**SM, 'role': 'hypothetical'}))
for role in ('framing', 'hypothetical', 'instruction', 'question'):
    test(f'control: {role} sentence without evidence is accepted', accepts(C.SentenceClaims, {'sentence_id': 's', 'role': role, 'claim_ids': []}))
test('sentence map without a role is rejected', rejects(C.SentenceClaims, {'sentence_id': 's', 'claim_ids': ['clm_1']}))
CLAIM = DRAFT['claims'][0]
QURAN_EV = CLAIM['evidence'][0]
REASON = {'tool': 'causal_reasoning', 'premises': ['Everything that begins to exist has a cause.'], 'inference': 'So the universe, which began, has a cause.'}
test('control: reasoning claim with reasoning support is accepted', accepts(C.Claim, {**CLAIM, 'basis': 'reasoning', 'evidence': [], 'reasoning': REASON}))
test('reasoning claim without reasoning support is rejected', rejects(C.Claim, {**CLAIM, 'basis': 'reasoning', 'evidence': [], 'reasoning': None}))
test('reasoning claim supported by scripture is rejected (no circular support)', rejects(C.Claim, {**CLAIM, 'basis': 'reasoning', 'reasoning': REASON}))
test('control: reasoning claim may show scripture that does not support it', accepts(C.Claim, {**CLAIM, 'basis': 'reasoning', 'reasoning': REASON, 'evidence': [{**QURAN_EV, 'supports': False}]}))
test('source claim carrying reasoning support is rejected', rejects(C.Claim, {**CLAIM, 'reasoning': REASON}))
test('reasoning support needs a premise', rejects(C.ReasoningSupport, {**REASON, 'premises': []}))
test('Draft example with sentence roles, claim basis and arc map validates', accepts(C.Draft, DRAFT))
test('Draft rejects an arc step mapped twice', rejects(C.Draft, {**DRAFT, 'arc_map': DRAFT['arc_map'] + DRAFT['arc_map'][:1]}))
test('Draft rejects an arc step with no blocks', rejects(C.Draft, {**DRAFT, 'arc_map': [{'step_id': 'setting', 'block_ids': []}]}))
AR_EDIT = G2['sentence_edits'][0]
test('Gate 2 rejects an Arabic edit without its English localization', rejects(C.Gate2, {**G2, 'sentence_edits': [AR_EDIT]}))
test('Gate 2 rejects an English edit for another variant as the pair', rejects(C.Gate2, {**G2, 'sentence_edits': [AR_EDIT, {**G2['sentence_edits'][1], 'variant': 'new_muslim'}]}))
test('control: English-only localization polish is accepted', accepts(C.Gate2, {**G2, 'sentence_edits': G2['sentence_edits'][1:]}))
test('FactoryRun accepts the localize stage', accepts(C.StageStatus, {'stage': 'localize', 'status': 'pending', 'started_at': None, 'finished_at': None}))
for kind in ('pedagogy', 'belief_grading', 'circular_reasoning', 'localization'):
    test(f'QA issue accepts kind {kind}', accepts(C.QAIssue, {'severity': 'blocker' if kind != 'pedagogy' else 'warning', 'kind': kind, 'location': {'sentence_id': None, 'exercise_id': None, 'scene_id': None}, 'message': 'm'}))

U0 = JOUR['units'][0]
LOCKED = U0['lessons'][2]
test('Journey example with Soft Locks and standalone lessons validates', accepts(C.Journey, JOUR))
test('locked lesson without soft_lock is rejected', rejects(C.JLesson, {**LOCKED, 'soft_lock': None}))
test('available lesson with a soft_lock is rejected', rejects(C.JLesson, {**LOCKED, 'state': 'available'}))
test('locked standalone-eligible lesson is rejected', rejects(C.JLesson, {**LOCKED, 'standalone_eligible': True}))
test('Soft Lock needs at least one prerequisite', rejects(C.SoftLock, {**LOCKED['soft_lock'], 'prerequisites': []}))


def journey_with(lesson_index, **changes):
    units = copy.deepcopy(JOUR['units'])
    units[0]['lessons'][lesson_index] = {**units[0]['lessons'][lesson_index], **changes}
    return {**JOUR, 'units': units}


test('Soft Lock naming a lesson outside the journey is rejected', rejects(C.Journey, journey_with(2, soft_lock={**LOCKED['soft_lock'], 'start_with': {'lesson_id': 'les_unknown', 'unit_id': 'unit_0', 'title': 'x'}})))
test('Soft Lock start_with pointing at a locked lesson is rejected', rejects(C.Journey, journey_with(3, soft_lock={**U0['lessons'][3]['soft_lock'], 'start_with': {k: LOCKED[k] for k in ('lesson_id', 'title')} | {'unit_id': 'unit_0'}})))
test('Soft Lock with a wrong unit for its lesson is rejected', rejects(C.Journey, journey_with(2, soft_lock={**LOCKED['soft_lock'], 'start_with': {**LOCKED['soft_lock']['start_with'], 'unit_id': 'unit_1'}})))
test('control: a later-unit lesson without prerequisites is available (position is not a prerequisite)',
     lambda: require_true(next(l for u in JOUR['units'] if u['unit_id'] == 'unit_7' for l in u['lessons'] if l['lesson_id'] == 'les_u7_l1')['state'] == 'available'))
JNM = json.loads((ROOT / 'fixtures/curriculum_test/journey_new_muslim.json').read_text())
JEX = json.loads((ROOT / 'fixtures/curriculum_test/journey_explorer.json').read_text())
test('test curriculum: the Explorer-only unit is absent from the New Muslim journey',
     lambda: require_true('unit_test_1' in {u['unit_id'] for u in JEX['units']} and 'unit_test_1' not in {u['unit_id'] for u in JNM['units']}))
test('test curriculum: shared lessons keep the same identity and access in both tracks',
     lambda: require_true([l for u in JEX['units'] if u['unit_id'] != 'unit_test_1' for l in u['lessons']] == [l for u in JNM['units'] for l in u['lessons']]))
test('test curriculum: no New Muslim variant exists for the Explorer-only unit',
     lambda: require_true(not list((ROOT / 'fixtures/curriculum_test').rglob('*unit_test_1*new_muslim*')) and not list((ROOT / 'fixtures/curriculum_test/lessons').glob('les_t1_*new_muslim*'))))

ONB = example('`POST /onboarding`')
test('Onboarding accepts a skipped curiosity question', accepts(C.OnboardingReq, {**ONB, 'goal_anchor': None}))
test('Onboarding requires the goal_anchor field (explicit null when skipped)', rejects(C.OnboardingReq, {k: v for k, v in ONB.items() if k != 'goal_anchor'}))
test('Onboarding has no religion field', rejects(C.OnboardingReq, {**ONB, 'religion': 'christian'}))
test('User has no religion field', rejects(C.User, {**example('5.1 `User`'), 'religion': 'atheist'}))
test('MePatch accepts a goal_anchor change', accepts(C.MePatch, {'goal_anchor': 'why_pray'}))


def scored_lesson(n):
    ex = json.loads((ROOT / 'fixtures/exercises/multiple_choice/exercise.json').read_text())
    items = [{'block_id': f'b{i}', 'type': 'exercise', 'exercise': {**ex, 'exercise_id': f'ex_{i}'}} for i in range(n)]
    return {'kind': 'lesson', 'mode': None, 'feedback_mode': 'immediate', 'items': items}


test('lesson composition rejects 1 scored exercise', lambda: require_true(bool(X.session_composition_errors(scored_lesson(1)))))
test('control: lesson composition accepts 2 scored exercises', lambda: require_true(not X.session_composition_errors(scored_lesson(2))))
test('control: lesson composition accepts 6 scored exercises (reference ceiling)', lambda: require_true(not X.session_composition_errors(scored_lesson(6))))
test('lesson composition rejects 7 scored exercises', lambda: require_true(bool(X.session_composition_errors(scored_lesson(7)))))

# ---------------------------------------------------------------- lesson-composition refinement
STEP = ARC['steps'][0]
test('ArcStep rejects an unknown technique', rejects(C.ArcStep, {**STEP, 'technique': 'lecture'}))
test('ArcStep requires a technique', rejects(C.ArcStep, {k: v for k, v in STEP.items() if k != 'technique'}))
test('LessonArc rejects two takeaway steps', rejects(C.LessonArc, {**ARC, 'steps': ARC['steps'] + [
    {**STEP, 'step_id': 't1', 'technique': 'takeaway'}, {**STEP, 'step_id': 't2', 'technique': 'takeaway'}]}))
test('story lesson whose arc has no story step is rejected', rejects(C.LessonPlan, {**PLAN, 'lesson_arc': {**ARC, 'steps': [
    {**st, 'technique': 'explanation' if st['technique'] == 'story' else st['technique']} for st in ARC['steps']]}}))
test('practice lesson whose arc has no practice step is rejected', rejects(C.LessonPlan, {**PLAN, 'lesson_type': 'practice', 'lesson_arc': {**ARC, 'steps': [
    {**st, 'technique': 'example' if st['technique'] == 'practice' else st['technique']} for st in ARC['steps']]}}))
test('control: a concept lesson may use story, scenario and practice techniques', accepts(C.LessonPlan, {**PLAN, 'lesson_type': 'concept'}))
STORY_EX = example('`POST /sessions`', 5)
SCENARIO = {**STORY_EX, 'label': 'موقف', 'provenance': None, 'origin': None,
            'beats': [{**b, 'quote': None, 'quote_meaning': None} for b in STORY_EX['beats']]}
BLOCK_ADAPTER = __import__('pydantic').TypeAdapter(C.Block)
def block_rejects(obj):
    def run():
        try:
            BLOCK_ADAPTER.validate_python(obj)
        except (ValidationError, ValueError):
            return
        raise AssertionError('invalid input was accepted')
    return run
test('control: sourced story example still validates', lambda: BLOCK_ADAPTER.validate_python(STORY_EX))
test('control: a teaching scenario (origin null, no provenance or quotes) validates', lambda: BLOCK_ADAPTER.validate_python(SCENARIO))
test('teaching scenario with provenance is rejected', block_rejects({**SCENARIO, 'provenance': STORY_EX['provenance']}))
test('teaching scenario with a scripture quote is rejected', block_rejects({**SCENARIO, 'beats': STORY_EX['beats']}))
test('exported Block schema accepts a teaching scenario', lambda: jsonschema.Draft202012Validator(SCHEMAS['Session']).validate(
    {**example('`POST /sessions`', 4), 'items': example('`POST /sessions`', 4)['items'] + [{**SCENARIO, 'block_id': 'blk_scenario'}]}))

# ---------------------------------------------------------------- lesson-depth refinement
test('LessonPlan rejects an unknown depth profile', rejects(C.LessonPlan, {**PLAN, 'depth_profile': 'deep'}))
test('LessonPlan requires a central learner question', rejects(C.LessonPlan, {k: v for k, v in PLAN.items() if k != 'central_question'}))
test('LessonPlan rejects an empty central question', rejects(C.LessonPlan, {**PLAN, 'central_question': L(' ')}))
test('LessonPlan rejects a supporting understanding missing a language', rejects(C.LessonPlan, {**PLAN, 'supporting_understandings': [{'ar': 'x', 'en': ''}]}))
test('control: a foundational plan with several supporting understandings is accepted',
     accepts(C.LessonPlan, {**PLAN, 'depth_profile': 'foundational', 'supporting_understandings': PLAN['supporting_understandings'] * 2}))
test('control: a focused plan with no supporting understandings is accepted',
     accepts(C.LessonPlan, {**PLAN, 'depth_profile': 'focused', 'supporting_understandings': []}))

# ---------------------------------------------------------------- pre-generation audit (semantic review, media readiness)
import contextual as X  # noqa: E402

SEM = {'fit': 'exact', 'concerns': [], 'note': 'The verse states the claim as worded.'}
test('control: an exact semantic review is accepted', accepts(C.SemanticReview, SEM))
test('a partial fit without a named concern is rejected', rejects(C.SemanticReview, {**SEM, 'fit': 'partial'}))
test('a repeated semantic concern is rejected', rejects(C.SemanticReview, {**SEM, 'fit': 'partial', 'concerns': ['needs_tafsir', 'needs_tafsir']}))
test('an unknown semantic concern is rejected', rejects(C.SemanticReview, {**SEM, 'fit': 'partial', 'concerns': ['vibes']}))
test('API example: supporting Quran evidence carries a semantic review', lambda: C.ClaimEvidence.model_validate(QURAN_EV) and QURAN_EV['semantic_review']['fit'])
test('supporting Quran evidence without a semantic review is rejected', rejects(C.ClaimEvidence, {**QURAN_EV, 'semantic_review': None}))
test('stretched evidence cannot support a claim', rejects(C.ClaimEvidence, {**QURAN_EV, 'semantic_review': {**SEM, 'fit': 'stretched', 'concerns': ['generalised_from_specific']}}))
test('unrelated evidence cannot support a claim', rejects(C.ClaimEvidence, {**QURAN_EV, 'semantic_review': {**SEM, 'fit': 'unrelated'}}))
test('control: stretched evidence recorded as not supporting is accepted',
     accepts(C.ClaimEvidence, {**QURAN_EV, 'supports': False, 'semantic_review': {**SEM, 'fit': 'stretched', 'concerns': ['beyond_source']}}))
test('control: a partial fit with a concern may support a claim',
     accepts(C.ClaimEvidence, {**QURAN_EV, 'semantic_review': {**SEM, 'fit': 'partial', 'concerns': ['addressee_specific']}}))
test('control: supporting book evidence may omit the semantic review',
     accepts(C.ClaimEvidence, {**QURAN_EV, 'source': {**QURAN_EV['source'], 'kind': 'book', 'provider': 'islamhouse'}, 'semantic_review': None}))
test('QA issue accepts kind scholarly_review', accepts(C.QAIssue, {'severity': 'warning', 'kind': 'scholarly_review', 'location': {'sentence_id': None, 'exercise_id': None, 'scene_id': None}, 'message': 'm'}))


def flagged(concerns, status='supported'):
    ev = {**QURAN_EV, 'semantic_review': {**SEM, 'fit': 'partial' if concerns else 'exact', 'concerns': concerns}}
    return X.scholarly_review_issues([{**CLAIM, 'status': status, 'evidence': [ev]}])


def expect(value, wanted):
    assert value == wanted, value


test('scholarly flags: a tafsir-dependent reading is a warning for the specialist', lambda: expect([i['severity'] for i in flagged(['needs_tafsir'])], ['warning']))
test('scholarly flags: wording beyond the source blocks', lambda: expect([i['severity'] for i in flagged(['context_dependent', 'beyond_source'])], ['blocker']))
test('scholarly flags: one opinion presented as the only view blocks', lambda: expect([i['severity'] for i in flagged(['single_opinion_as_consensus'])], ['blocker']))
test('scholarly flags: an exact fit raises nothing', lambda: expect(flagged([]), []))
test('scholarly flags: dropped claims are not reported', lambda: expect(flagged(['needs_tafsir'], status='dropped'), []))
test('scholarly flags: issues validate as QA issues', lambda: [C.QAIssue.model_validate(i) for i in flagged(['oversimplified'])])

test('publication gate: example-host, mock-asset, http and .test URLs are rejected', lambda: expect(len(X.placeholder_media_errors(
    {'a': {'url': 'https://cdn.example.com/x.webp'}, 'b': [{'asset_url': 'mock-asset://t/x.webp'}], 'c': {'pronunciation_audio_url': 'http://cdn.qabas.app/a.mp3'},
     'd': {'url': 'https://media.local.test/x.png'}})), 4))
test('control: production https media passes the publication gate', lambda: expect(X.placeholder_media_errors({'image': {'url': 'https://cdn.qabas.app/scenes/a/v1/x.webp'}}), []))
test('publication gate flags the documentation draft (example URLs are illustrative only)', lambda: expect(bool(X.placeholder_media_errors(DRAFT)), True))

PROD_CAPS = [c['id'] for c in json.loads((ROOT / 'contract/scene_capabilities.production.json').read_text())['capabilities'] if c['status'] == 'released']
SIM_CAPS = [c['id'] for c in json.loads((ROOT / 'contract/scene_capabilities.json').read_text())['capabilities'] if c['status'] == 'released']
REAL = json.loads(json.dumps(DRAFT['visuals']).replace('cdn.example.com', 'cdn.qabas.app'))
SCENE_DV = next(v for v in REAL if v['origin'] == 'generated_scene')
BUILTIN_DV = next(v for v in REAL if v['origin'] == 'builtin')
test('readiness: no production scene capability is released yet', lambda: expect(PROD_CAPS, []))
test('readiness: a builtin visual is compiled', lambda: expect(X.visual_readiness(BUILTIN_DV, released_capabilities=PROD_CAPS), 'compiled'))
test('readiness: a generated scene is capability_blocked against the production registry', lambda: expect(X.visual_readiness(SCENE_DV, released_capabilities=PROD_CAPS), 'capability_blocked'))
test('readiness: an audited scene rendered by qabas_scene is audited (simulation registry)', lambda: expect(X.visual_readiness(SCENE_DV, released_capabilities=SIM_CAPS), 'audited'))
test('readiness: frames from the non-normative SVG preview are preview_only', lambda: expect(X.visual_readiness(
    {**SCENE_DV, 'previews': {**SCENE_DV['previews'], 'renderer_version': 'scene_check.render_svg (non-normative)'}}, released_capabilities=SIM_CAPS), 'preview_only'))
test('readiness: a failed audit is audit_failed', lambda: expect(X.visual_readiness({**SCENE_DV, 'audit': {'passed': False, 'issues': ['text in image']}}, released_capabilities=SIM_CAPS), 'audit_failed'))
test('readiness: a missing audit is unaudited', lambda: expect(X.visual_readiness({**SCENE_DV, 'audit': None}, released_capabilities=SIM_CAPS), 'unaudited'))
test('readiness: the documentation draft generated visuals are placeholders (the builtin is compiled)', lambda: expect(sorted(X.visual_readiness(v, released_capabilities=SIM_CAPS) for v in DRAFT['visuals']), ['compiled', 'placeholder', 'placeholder']))

test('publication gate rejects a relative draft path, but such a real asset is not a placeholder', lambda: expect(
    (len(X.placeholder_media_errors({'url': 'assets/scenes/a/v1/fallback.webp'})), X.visual_readiness({**SCENE_DV, 'visual': json.loads(json.dumps(SCENE_DV['visual']).replace('https://cdn.qabas.app/', 'assets/'))}, released_capabilities=SIM_CAPS)), (1, 'audited')))

# ---------------------------------------------------------------- scene semantics (static rules, rev 10)
import scene_check as S  # noqa: E402
SCENE = json.loads((ROOT / 'fixtures/scenes/scn_test_desert_well.v2.scene.json').read_text())
ASSET_SCENE = json.loads((ROOT / 'fixtures/scenes/asset_positive.scene.json').read_text())


def scene_errors_contain(mutate, needle, base=None, **kw):
    def run():
        m = copy.deepcopy(base or SCENE)
        mutate(m)
        errs = S.semantic_rule_errors(m, kw.get('token_table'))
        if not any(needle in e for e in errs):
            raise AssertionError(f'expected "{needle}" in {errs}')
    return run


def layer(m, lid):
    return next(l for l in S.walk(m['layers']) if l['id'] == lid)


def no_semantic_errors_on_samples():
    for m in (SCENE, ASSET_SCENE):
        errs = S.semantic_rule_errors(m, set())
        if errs:
            raise AssertionError(errs)
    if S.check(copy.deepcopy(SCENE)):
        raise AssertionError('sample scene no longer passes the full checker')


test('control: sample scenes pass the rev 10 semantic rules and the full checker', no_semantic_errors_on_samples)
test('scene: zero scale keyframe rejected', scene_errors_contain(
    lambda m: layer(m, 'well_glow')['tracks'][0]['keyframes'].__setitem__(0, {'t': 0, 'v': 0}), 'scale keyframes must be > 0'))
test('scene: negative rule scale rejected', scene_errors_contain(
    lambda m: layer(m, 'moon')['state_rules'][0]['set'].__setitem__('scale', -1), 'state rule scale must be > 0'))
test('scene: animated clip source rejected', scene_errors_contain(
    lambda m: layer(m, 'tent').__setitem__('clip', 'moon'), 'clip sources are definitions only'))
test('scene: gradient sparkles rejected', scene_errors_contain(
    lambda m: layer(m, 'stars').__setitem__('fill', {'gradient': 'linear', 'from': [0, 0], 'to': [1, 1], 'stops': [{'at': 0, 'color': 'star'}, {'at': 1, 'color': 'glow'}]}),
    'sparkles need a solid palette fill'))


def stretch_asset(m):
    l = next(x for x in S.walk(m['layers']) if x['type'] == 'asset')
    l['w'] = l['w'] * 1.2


test('scene: distorted asset box rejected', scene_errors_contain(stretch_asset, 'asset box proportion', base=ASSET_SCENE))
test('scene: unknown theme token rejected when a token table is supplied', scene_errors_contain(
    lambda m: m['palette'].__setitem__('accent', 'token:neon'), 'unknown theme token', token_table={'emerald', 'flame_gold'}))

failed = [r for r in results if not r['passed']]
report = {'suite': 'revision 10 focused checks', 'roots_exported': len(SCHEMAS), 'tests': len(results),
          'passed': len(results) - len(failed), 'failed': failed,
          'checks': [{'label': r['label'], 'passed': r['passed']} for r in results],
          'runtime_verification': 'none: models/schemas/examples only; no backend, Flutter app or renderer was executed'}
(ROOT / 'REV10_CHECKS.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k != 'failed'}, indent=2))
for f in failed:
    print('FAILED', f['label'], '-', f['error'])
sys.exit(1 if failed else 0)
