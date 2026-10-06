"""Read-only regression suite: models, exported schemas and linked semantics."""
import copy
import hashlib
import json
import pathlib
import sys
from decimal import Decimal
ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'contract'), str(ROOT / 'tools')]
import qabas_contract as C
import contextual as X
import scene_check as S
from export_schema import export_all
import jsonschema

FX = ROOT / 'fixtures'
results = []
def load(path): return json.loads((FX / path).read_text())
def test(label, fn):
    try:
        fn()
        results.append({'label': label, 'passed': True})
    except Exception as e:
        results.append({'label': label, 'passed': False, 'error': f'{type(e).__name__}: {e}'})
def require(value, message='assertion failed'):
    if not value: raise AssertionError(message)
def rejected(fn):
    try: fn()
    except (ValueError, jsonschema.ValidationError): return
    raise AssertionError('invalid input was accepted')

schemas = export_all()
manifest = load('MANIFEST.json')
for row in manifest:
    obj = load(row['file'])
    model = getattr(C, row['model'])
    def check_fixture(obj=obj, model=model, row=row):
        schema = schemas.get(row['model'])
        require(schema is not None, 'fixture model missing from exported schema')
        for value in obj if isinstance(obj, list) else [obj]:
            model.model_validate(value)
            jsonschema.Draft202012Validator(schema).validate(value)
    test('model + JSON Schema: ' + row['file'], check_fixture)

contexts = load('EVALUATION_CONTEXT.json')
for path, context in contexts.items():
    def check_context(path=path, context=context):
        X.validate_attempt(context['exercise'], context['answer'], context['kind'], original_correct=context['original_correct'])
        X.validate_evaluation(context['exercise'], context['answer'], context['kind'], load(path), context['mastery_before'], private_key=context['private_key'], recitation_passed=context['recitation_passed'])
    test('linked attempt + evaluation: ' + path, check_context)

matrix = load('COVERAGE_MATRIX.json')
for row in matrix['rows']:
    ex = load(row['exercise'])
    path = row['outcomes']['invalid']['answer']
    test('reject invalid served answer: ' + row['type'] + str(row['presentation']),
         lambda ex=ex, path=path, row=row: rejected(lambda: X.validate_attempt(ex, load(path), row['sample_kind'])))
    if row.get('retry_rejection'):
        test('reject ineligible retry: ' + row['type'], lambda ex=ex, row=row: rejected(lambda: X.validate_attempt(ex, load(row['retry_rejection']), row['sample_kind'], original_correct=False)))

hist = load('sessions/recovery_after_early_retry.json')
swap = copy.deepcopy(hist); swap['answers'][0], swap['answers'][1] = swap['answers'][1], swap['answers'][0]
test('authored order rejects swapped original attempts', lambda: rejected(lambda: C.Session.model_validate(swap)))
duplicate = copy.deepcopy(hist); duplicate['answers'].append(copy.deepcopy(duplicate['answers'][-1]))
test('duplicate retry identity rejected', lambda: rejected(lambda: C.Session.model_validate(duplicate)))
wrong_count = copy.deepcopy(hist); wrong_count['answered_exercises'] -= 1
test('answered_exercises agrees with original records', lambda: rejected(lambda: C.Session.model_validate(wrong_count)))
mismatch = copy.deepcopy(hist); mismatch['answers'][0]['evaluation']['exercise_id'] = 'other'
test('history evaluation identity mismatch rejected', lambda: rejected(lambda: C.Session.model_validate(mismatch)))
neutral_mismatch = copy.deepcopy(hist); neutral_mismatch['answers'][0]['evaluation']['correct'] = None
test('history result/evaluation mismatch rejected', lambda: rejected(lambda: C.Session.model_validate(neutral_mismatch)))
for path in ('sessions/history_end_active.json', 'sessions/history_none_finished.json'):
    bad = load(path); bad['answers'][0]['result'] = 'correct'
    test('feedback privacy: ' + path, lambda bad=bad: rejected(lambda: C.Session.model_validate(bad)))

test('hard rating 0.400000 becomes 0.490000', lambda: require(X.update_mastery('.4', 'flashcard_hard') == Decimal('.490000')))
test('pretest correct uses half weight', lambda: require(X.update_mastery('.4', 'pretest_correct') == Decimal('.505000')))
test('pretest incorrect uses half weight', lambda: require(X.update_mastery('.4', 'pretest_incorrect') == Decimal('.350000')))
test('incorrect retry is spent with no mastery change', lambda: require(X.update_mastery('.4', 'retry_incorrect') == Decimal('.400000')))
test('decimal half-up rounds 0.545 to 0.55', lambda: require(X.report_mastery('.545000') == .55))
hard = load('exercises/flashcard/eval_hard.json'); hard['mastery_changes'][0]['after'] = .61
c = contexts['exercises/flashcard/eval_hard.json']
test('old incorrect hard rating snapshot rejected contextually', lambda: rejected(lambda: X.validate_evaluation(c['exercise'], c['answer'], c['kind'], hard, c['mastery_before'], private_key=c['private_key'])))

ctx = contexts['exercises/multiple_choice/eval_correct.json']
false_result = load('exercises/multiple_choice/eval_correct.json')
false_result['correct'] = False
false_result['mastery_changes'][0]['after'] = .30
# Even mathematically consistent feedback cannot lie about the private key.
test('context rejects a wrong correctness result with matching arithmetic', lambda: rejected(lambda: X.validate_evaluation(ctx['exercise'], ctx['answer'], ctx['kind'], false_result, ctx['mastery_before'], private_key=ctx['private_key'])))
for typ in ('flashcard', 'recite_verse'):
    ex_assessment = load('exercises/' + typ + '/exercise.json')
    body_assessment = load('exercises/' + typ + ('/answer_good.json' if typ == 'flashcard' else '/answer_check.json'))
    test('assessment rejects ' + typ, lambda ex=ex_assessment, body=body_assessment: rejected(lambda: X.validate_attempt(ex, body, 'pretest')))

timeout_context = contexts['exercises/match_pairs/eval_timeout.json']
misleading_timeout = load('exercises/match_pairs/eval_timeout.json')
misleading_timeout['details']['pair_results'][0]['correct'] = True
test('timeout cannot report a correct unanswered pair', lambda: rejected(lambda: X.validate_evaluation(timeout_context['exercise'], timeout_context['answer'], timeout_context['kind'], misleading_timeout, timeout_context['mastery_before'], private_key=timeout_context['private_key'])))

ex = load('exercises/multiple_choice/exercise.json'); malformed = copy.deepcopy(ex); malformed['payload'] = {}
test('Exercise exported schema rejects malformed payload', lambda: rejected(lambda: jsonschema.Draft202012Validator(schemas['Exercise']).validate(malformed)))
for event_type in ('question', 'state', 'question_result', 'opponent_answered'):
    event = {'type': event_type, 'data': {}}
    test('typed event model rejects empty ' + event_type, lambda event=event: rejected(lambda: C.WsEvent.model_validate(event)))
    test('typed event schema rejects empty ' + event_type, lambda event=event: rejected(lambda: jsonschema.Draft202012Validator(schemas['WsEvent']).validate(event)))
session = load('sessions/session_practice_all_types.json'); session['items'][2]['exercise']['payload'] = {}
test('nested Session Exercise schema uses typed payload', lambda: rejected(lambda: jsonschema.Draft202012Validator(schemas['Session']).validate(session)))
test('hadith evidence must contain hadith body', lambda: rejected(lambda: C.Evidence.model_validate({'evidence_id':'x', 'kind':'hadith', 'quran':None, 'hadith':None})))

banks = load('curriculum_test/ASSESSMENT_BANKS.json')
exercise_types = {}
for file in sorted((FX / 'curriculum_test/lessons').glob('*.json')):
    s = json.loads(file.read_text())
    def check_seed(s=s, file=file):
        unit = next(u for u in banks['units'] if any(l['lesson_id'] == s['lesson_id'] for l in u['lessons']))
        require(s['unit_id'] == unit['unit_id'], 'unit ownership')
        require(not X.session_composition_errors(s), 'production lesson composition')
        for b in s['items']:
            if b['type'] != 'exercise': continue
            e = b['exercise']; exercise_types.setdefault(e['exercise_id'], set()).add(e['type'])
            if '__en_' in file.name:
                require(not any('\u0600' <= ch <= '\u06ff' for ch in json.dumps(e['prompt'], ensure_ascii=False)), 'untranslated English prompt')
    test('synthetic lesson ownership/composition/language: ' + file.name, check_seed)
test('exercise identity/type stable across language and track', lambda: require(all(len(types) == 1 for types in exercise_types.values())))
for unit in banks['units']:
    def check_banks(unit=unit):
        for purpose, per_lesson, minimum in [('pretest', 2, 6), ('unit_test', 3, 9)]:
            ids = [e['exercise_id'] for e in unit[purpose]]
            require(len(ids) == len(set(ids)) >= minimum)
            require(all(len(l[purpose]) == per_lesson for l in unit['lessons']))
            require(set(ids) == {eid for l in unit['lessons'] for eid in l[purpose]})
    test('linked per-unit assessment supply: ' + unit['unit_id'], check_banks)
for file in sorted((FX / 'curriculum_test/assessments').glob('*.json')):
    s = json.loads(file.read_text())
    def check_assessment(s=s):
        require(not X.session_composition_errors(s))
        served = [b['exercise']['exercise_id'] for b in s['items']]
        bank = next(u for u in banks['units'] if u['unit_id'] == s['unit_id'])
        require(len(served) == len(set(served)))
        require(set(served) <= {e['exercise_id'] for e in bank[s['kind']]})
    test('assessment pool membership/no repeats/composition: ' + file.name, check_assessment)
for path in matrix['reviews']:
    test('review composition: ' + path, lambda path=path: require(not X.session_composition_errors(load(path))))

scene = load('scenes/scn_test_desert_well.v2.scene.json')
test('positive declarative scene', lambda: require(not S.check(scene)))
motion = copy.deepcopy(scene)
next(l for l in S.walk(motion['layers']) if l['id'] == 'palm_ring')['state_rules'] = [{'when': {'beat': {'gte': 1}}, 'set': {'scale': 20, 'rotation': 180}}]
test('descendant rule scale/rotation limits', lambda: require(bool(S.check(motion))))
path = copy.deepcopy(scene)
next(l for l in S.walk(path['layers']) if l['type'] == 'path')['d'] = 'M 0 0 A 10 10 0 0 0 20 20 Z'
test('unsupported SVG path arc rejected', lambda: require(bool(S.check(path))))
missing = copy.deepcopy(scene); missing['layers'].append({'id': 'incomplete', 'type': 'rect'})
test('scene shape geometry required in schema', lambda: require(bool(S.check(missing))))
test('malformed path argument count rejected', lambda: rejected(lambda: S.path_commands('M 0 0 C 1 2 3 Z')))
test('implicit path commands counted', lambda: require(S.path_commands('M 0 0 1 1 L 2 2 Z') == 4))
test('path command limit per layer', lambda: require(bool(S.check({**scene, 'layers': scene['layers'] + [{'id':'many_paths','type':'path','d':'M 0 0 ' + 'L 1 1 ' * 401, 'fill':next(iter(scene['palette']))}]}))))
unused = copy.deepcopy(scene); unused['required_capabilities'].append('clip/1')
test('declared but unused capability rejected', lambda: require(bool(S.check(unused))))
test('simulation registry cannot authorize publication', lambda: require(bool(S.check(scene, publication=True))))
production = json.loads((ROOT / 'contract/scene_capabilities.production.json').read_text())
test('unreleased production capabilities rejected', lambda: require(bool(S.check(scene, publication=True, registry=production))))

# Resolve a real raster file, then alter declarations and bytes independently.
asset_meta = load('mock_assets/mock_assets.json')['mock-asset://test/u1l0.webp']
asset_scene = load('scenes/asset_positive.scene.json')
resolved = {'mock-asset://test/u1l0.webp': FX / asset_meta['path']}
test('positive asset-bearing scene verifies actual bytes', lambda: require(not S.check(asset_scene, asset_files=resolved)))
wrong = load('negative/scene_asset_wrong_dimensions.json')
test('asset dimensions mismatch rejected', lambda: require(bool(S.check(wrong, asset_files=resolved))))
wrong = load('negative/scene_asset_wrong_checksum.json')
test('asset checksum mismatch rejected', lambda: require(bool(S.check(wrong, asset_files=resolved))))
damaged = FX / 'negative/corrupt_asset.webp'
test('corrupted asset rejected', lambda: require(bool(S.check(asset_scene, asset_files={'mock-asset://test/u1l0.webp':damaged}))))

rec = load('exercises/recite_verse/exercise.json'); p = rec['payload']
binding = {'user_id':'test_user', 'exercise_id':rec['exercise_id'], 'exercise_version':1, 'surah':p['surah'], 'ayah':p['ayah'], 'word_start':p['word_start'], 'word_end':p['word_end'], 'text_sha256':hashlib.sha256(p['text_uthmani'].encode()).hexdigest()}
test('recitation check bound to served content and owner', lambda: X.validate_recitation_binding(rec, binding, user_id='test_user', exercise_version=1))
for key, value in [('user_id','other'), ('exercise_version',2), ('word_start',2), ('text_sha256','0'*64)]:
    bad = {**binding, key:value}
    test('recitation binding rejects changed ' + key, lambda bad=bad: rejected(lambda: X.validate_recitation_binding(rec, bad, user_id='test_user', exercise_version=1)))

report = {'scope': {'pydantic': True, 'json_schema': True, 'contextual_semantics': True, 'flutter_scene_renderer': False, 'backend_runtime': False},
          'tests': len(results), 'passed': sum(r['passed'] for r in results), 'failed': [r for r in results if not r['passed']], 'results': results}
(ROOT / 'REGRESSION_REPORT.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k:v for k,v in report.items() if k != 'results'}, ensure_ascii=False, indent=2))
raise SystemExit(bool(report['failed']))
