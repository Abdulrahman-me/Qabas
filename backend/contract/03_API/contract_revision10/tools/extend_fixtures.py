"""Add linked assessment banks, contextual evaluation data and outcome coverage.

Run after make_fixtures.py. Every seed here is synthetic, not religious content
approved for publication. Widget smoke examples stay explicitly separate.
"""
import copy
import hashlib
import json
import pathlib
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'contract'), str(ROOT / 'tools')]
import qabas_contract as C
import contextual as X
from display_fields import backfill_legacy

FX = ROOT / 'fixtures'
manifest = json.loads((FX / 'MANIFEST.json').read_text())
contexts = {}
matrix = []

def load(path):
    return json.loads((FX / path).read_text())

def save(path, obj, model=None):
    obj = backfill_legacy(obj)
    if model:
        model.model_validate(obj)
        if not any(r['file'] == path for r in manifest):
            manifest.append({'file': path, 'model': model.__name__})
    target = FX / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(obj, ensure_ascii=False, indent=1) + '\n')

def invalid_answer(ex):
    typ = ex['type']
    return {
        'multiple_choice': {'option_id': 'unserved'}, 'true_false_reason': {'value': False, 'reason_option_id': 'unserved'},
        'match_pairs': {'pairs': []}, 'flashcard': {'rating': 'invalid'}, 'fill_blank': {'fills': []},
        'categorize': {'assignments': []}, 'spot_error': {'segment_id': 'unserved'},
        'which_evidence': {'option_id': 'unserved'}, 'order_steps': {'order': []},
        'scenario': {'option_id': 'unserved'}, 'timeline_order': {'order': []},
        'map_place': {'pin_id': 'unserved'}, 'recite_verse': {'skipped': False},
        'verse_meaning': {'option_id': 'unserved'}, 'true_false': {'value': 'false'},
    }[typ]

for folder in sorted((FX / 'exercises').iterdir()):
    if not folder.is_dir():
        continue
    base = str(folder.relative_to(FX)) + '/'
    ex = load(base + 'exercise.json')
    typ = ex['type']
    kind = 'challenge' if typ == 'true_false' else 'review' if typ == 'flashcard' else 'lesson'
    # Remove the old, inapplicable challenge retry files from the revised copy.
    if typ == 'true_false':
        for suffix in ('answer_retry.json', 'eval_retry_correct.json'):
            (FX / (base + suffix)).unlink(missing_ok=True)
    invalid = {'exercise_id': ex['exercise_id'], 'answer': invalid_answer(ex), 'elapsed_ms': 5000, 'is_retry': False}
    save('negative/' + folder.name + '__invalid.json', invalid)
    row = {'type': typ, 'presentation': ex['payload'].get('presentation'), 'exercise': base + 'exercise.json',
           'sample_kind': kind, 'outcomes': {},
           'session_eligibility': {
               'lesson': typ != 'true_false',
               'review_cards': typ == 'flashcard',
               'review_quick': typ not in ('true_false', 'flashcard', 'recite_verse') and folder.name not in ('categorize__day_arc', 'map_place__hotspots'),
               'pretest': typ not in ('true_false', 'flashcard', 'recite_verse'),
               'unit_test': typ not in ('true_false', 'flashcard', 'recite_verse'),
               'challenge': typ in ('true_false', 'multiple_choice', 'verse_meaning'),
           }}
    row['outcomes']['invalid'] = {'status': 'reject', 'answer': 'negative/' + folder.name + '__invalid.json'}
    aliases = {'passed': 'check', 'failed': 'check', 'retry_correct': 'retry', 'incorrect_misconception': 'incorrect'}
    for evaluation_path in sorted(folder.glob('eval_*.json')):
        rel = str(evaluation_path.relative_to(FX))
        suffix = evaluation_path.stem.removeprefix('eval_')
        if suffix == 'recorded_only':
            row['outcomes'][suffix] = {'status': 'shape_only', 'evaluation': rel, 'reason': 'hidden feedback envelope; replay requires stored attempt context'}
            continue
        answer_path = base + 'answer_' + aliases.get(suffix, suffix) + '.json'
        if not (FX / answer_path).exists():
            raise ValueError(f'unlinked evaluation: {rel}')
        contexts[rel] = {'exercise': ex, 'answer': load(answer_path), 'kind': kind,
                         'mastery_before': {cid: '0.400000' for cid in ex['concept_ids']},
                         'original_correct': False if load(answer_path)['is_retry'] else None,
                         'private_key': load(base + 'answer_correct.json')['answer'] if (FX / (base + 'answer_correct.json')).exists() else None,
                         'recitation_passed': suffix == 'passed' if typ == 'recite_verse' and suffix != 'skipped' else None}
        row['outcomes'][suffix] = {'status': 'fixture', 'answer': answer_path, 'evaluation': rel}
    for outcome in ('correct', 'incorrect', 'timeout', 'retry_correct', 'retry_incorrect', 'passed', 'failed', 'skipped', 'unavailable', 'again', 'hard', 'good', 'easy', 'incorrect_misconception'):
        if outcome not in row['outcomes']:
            row['outcomes'][outcome] = {'status': 'not_applicable', 'reason': 'not part of this type/context policy'}
    if typ in ('true_false', 'recite_verse', 'flashcard'):
        retry = {'exercise_id': ex['exercise_id'], 'answer': ({'value': False} if typ == 'true_false' else {'check_id': 'rchk_55e2'} if typ == 'recite_verse' else {'rating': 'good'}), 'elapsed_ms': 5000, 'is_retry': True}
        save('negative/' + folder.name + '__retry.json', retry)
        row['retry_rejection'] = 'negative/' + folder.name + '__retry.json'
    matrix.append(row)

# Paired recitation-check responses: passed, word errors, and unclear. No ASR ran.
words = load('exercises/recite_verse/exercise.json')['payload']['audio']['words']
for status in ('passed', 'errors', 'unclear'):
    rows = [{'index': i, 'expected': w['text'], 'result': 'correct' if status == 'passed' or i != 1 else 'substituted',
             'heard': w['text'] if status == 'passed' or i != 1 else 'TEST', 'audio_segment': None} for i, w in enumerate(words)]
    check = {'check_id': 'rchk_55e2', 'status': 'unclear' if status == 'unclear' else 'evaluated', 'passed': status == 'passed',
             'words': [] if status == 'unclear' else rows,
             'summary': {'correct': len(words) if status == 'passed' else len(words) - 1 if status == 'errors' else 0,
                         'missing': 0, 'substituted': 1 if status == 'errors' else 0, 'extra': 0},
             'message': [{'type': 'text', 'text': 'Synthetic recitation check; no audio was recognized.'}]}
    save(f'recitation/check_{status}.json', check, C.RecitationCheck)

segment = load('exercises/recite_verse/exercise.json')
segment['exercise_id'] = 'ex_test_segment'
segment['payload'].update(word_start=2, word_end=3, text_uthmani='هُوَ اللَّهُ')
segment['payload']['audio']['words'] = [dict(w, start_ms=w['start_ms'] - 520, end_ms=w['end_ms'] - 520) for w in words[1:3]]
segment['payload']['audio']['url'] = 'mock-asset://audio/test_tone_112001.mp3'
save('recitation/exercise_segment.json', segment, C.Exercise)

# Explicit card/quick-review sessions (selection/scheduling remains unimplemented).
template = load('sessions/session_practice_all_types.json')
for mode in ('cards', 'quick'):
    s = copy.deepcopy(template)
    s.update(session_id='ses_review_' + mode, kind='review', mode=mode, unit_id=None,
             lesson_id=None, lesson_version=None, subtitle=None, lesson_type=None, reviewed_by=None,
             objectives=[], completion=None, sources=[], source_count=0, terms={}, answers=[], answered_exercises=0)
    s['items'] = []
    for i in range(3):
        ex = copy.deepcopy(load('exercises/flashcard/exercise.json' if mode == 'cards' else 'exercises/multiple_choice/exercise.json'))
        ex['exercise_id'] = f'ex_review_{mode}_{i}'
        ex['time_limit_ms'] = None if mode == 'cards' else 20000
        s['items'].append({'block_id': f'b_{i}', 'type': 'exercise', 'exercise': ex})
    s['counts'] = {'interactions': 3, 'exercises': 3, 'scored': 3}
    s['total_exercises'] = 3
    save('sessions/review_' + mode + '.json', s, C.Session)

# Ten lessons, two pretest and three unit-test items contributed by each.
units = []
private_keys = {}
tracks_of = {}
for track in ('explorer', 'new_muslim'):
    for unit in load('curriculum_test/journey_' + track + '.json')['units']:
        tracks_of.setdefault(unit['unit_id'], []).append(track)
for unit in load('curriculum_test/journey_explorer.json')['units']:
    if unit['coming_soon']:
        continue
    entry = {'unit_id': unit['unit_id'], 'lessons': [], 'pretest': [], 'unit_test': []}
    for lesson in unit['lessons']:
        lid = lesson['lesson_id']
        contribution = {'lesson_id': lid, 'pretest': [], 'unit_test': []}
        for purpose, count in (('pretest', 2), ('unit_test', 3)):
            for i in range(count):
                # Hashes are opaque IDs; grading is private and varies by item.
                eid = 'ex_' + hashlib.sha256(f'{lid}:{purpose}:{i}'.encode()).hexdigest()[:16]
                links = {'exercise_id': eid, 'source_lesson_id': lid, 'variants': {}}
                private_keys[eid] = {'option_id': ['opt_a', 'opt_b', 'opt_c'][int(hashlib.sha256(eid.encode()).hexdigest(), 16) % 3]}
                for lang in ('ar', 'en'):
                    ex = load('exercises/multiple_choice/exercise.json')
                    ex.update(exercise_id=eid, prompt=[{'type': 'text', 'text': f'Test assessment {i + 1}' if lang == 'en' else f'سؤال اختباري {i + 1}'}], time_limit_ms=None)
                    for j, opt in enumerate(ex['payload']['options']):
                        opt['spans'] = [{'type': 'text', 'text': f'Test option {j + 1}' if lang == 'en' else f'خيار اختباري {j + 1}'}]
                    path = f'curriculum_test/bank/{eid}__{lang}.json'
                    save(path, ex, C.Exercise)
                    links['variants'][lang] = path
                contribution[purpose].append(eid)
                entry[purpose].append(links)
        entry['lessons'].append(contribution)
    units.append(entry)
    for lang in ('ar', 'en'):
        for track in tracks_of[unit['unit_id']]:  # an Explorer-only unit is never served to New Muslims
            for kind in ('pretest', 'unit_test'):
                s = copy.deepcopy(template)
                cap = 8 if kind == 'pretest' else 12
                bank = sorted(entry[kind], key=lambda x: hashlib.sha256(x['exercise_id'].encode()).hexdigest())[:cap]
                s.update(session_id=f"ses_{unit['unit_id']}_{kind}_{lang}_{track}", kind=kind,
                         unit_id=unit['unit_id'], lesson_id=None, lesson_version=None, subtitle=None,
                         lesson_type=None, reviewed_by=None, objectives=[], completion=None,
                         feedback_mode='none' if kind == 'pretest' else 'end', sources=[], source_count=0, terms={}, answers=[], answered_exercises=0)
                s['items'] = [{'block_id': f'b_{i}', 'type': 'exercise', 'exercise': load(x['variants'][lang])} for i, x in enumerate(bank)]
                s['counts'] = {'interactions': len(bank), 'exercises': len(bank), 'scored': len(bank)}
                s['total_exercises'] = len(bank)
                save(f'curriculum_test/assessments/{s["session_id"]}.json', s, C.Session)

save('curriculum_test/ASSESSMENT_BANKS.json', {'role': 'synthetic composition seed; not approved religious content', 'units': units})
save('curriculum_test/PRIVATE_GRADING_KEYS.json', private_keys)
for track in ('explorer', 'new_muslim'):
    journey = load('curriculum_test/journey_' + track + '.json')
    save('curriculum_test/journey_ar_' + track + '.json', journey, C.Journey)
    english = copy.deepcopy(journey)
    for unit in english['units']:
        unit['title'] = 'Coming soon' if unit['coming_soon'] else 'Test unit ' + str(unit['index'])
        unit['subtitle'] = 'Synthetic test curriculum'
        for lesson in unit['lessons']:
            lesson['title'] = 'Test lesson ' + str(lesson['index'] + 1)
    titles = {l['lesson_id']: l['title'] for u in english['units'] for l in u['lessons']}
    for unit in english['units']:
        for lesson in unit['lessons']:
            lock = lesson['soft_lock']
            for ref in (lock['prerequisites'] + [lock['start_with']]) if lock else []:
                ref['title'] = titles[ref['lesson_id']]
    save('curriculum_test/journey_en_' + track + '.json', english, C.Journey)

# Add explicit scene feedback context.
scene_s = load('scenes/session_test_scene_lesson.json')
scene_ex = next(b['exercise'] for b in scene_s['items'] if b['type'] == 'exercise')
scene_answer = {'exercise_id': scene_ex['exercise_id'], 'answer': {'pin_id': 'pin_well'}, 'elapsed_ms': 4000, 'is_retry': False}
save('scenes/answer_hotspot_correct.json', scene_answer, C.AnswerSubmit)
contexts['scenes/eval_hotspot_correct.json'] = {'exercise': scene_ex, 'answer': scene_answer, 'kind': 'lesson', 'mastery_before': {'con_test': '0.400000'}, 'original_correct': None, 'private_key': {'pin_id': 'pin_well'}, 'recitation_passed': None}

# Serialized asset-bearing manifest and negative specimens supplement the
# original vector-only sample. They are scene-validator fixtures, not C models.
asset_meta = load('mock_assets/mock_assets.json')['mock-asset://test/u1l0.webp']
asset_scene = load('scenes/scn_test_desert_well.v2.scene.json')
asset_scene.update(scene_id='scn_test_desert_well_asset', version=1)
asset_scene['required_capabilities'].append('asset.raster/1')
asset_scene['assets'] = [{'asset_id': 'test_raster', 'url': 'mock-asset://test/u1l0.webp',
                         **{k: asset_meta[k] for k in ('mime_type', 'width', 'height', 'bytes', 'sha256')}}]
asset_scene['layers'].append({'id': 'raster_test', 'type': 'asset', 'x': 0, 'y': 0, 'w': 100, 'h': 62.5, 'asset_id': 'test_raster'})
save('scenes/asset_positive.scene.json', asset_scene)
wrong_dimensions = copy.deepcopy(asset_scene)
wrong_dimensions['assets'][0]['width'] += 1
save('negative/scene_asset_wrong_dimensions.json', wrong_dimensions)
wrong_checksum = copy.deepcopy(asset_scene)
wrong_checksum['assets'][0]['sha256'] = '0' * 64
save('negative/scene_asset_wrong_checksum.json', wrong_checksum)
(FX / 'negative/corrupt_asset.webp').write_bytes(b'not an image')

# Avoid obsolete paths surviving generation from the original package.
generic_base = copy.deepcopy(load('exercises/categorize__buckets/exercise.json'))
generic_base.update(exercise_id='ex_generic_colors', prompt=[{'type':'text','text':'Group these test items by color.'}])
generic_base['payload'] = {'presentation':'buckets',
    'categories':[{'category_id':'warm','label':'Warm colors','phase':None,'capacity':None,'art_key':None},
                  {'category_id':'cool','label':'Cool colors','phase':None,'capacity':None,'art_key':None}],
    'items':[{'item_id':'blue','spans':[{'type':'text','text':'Blue'}],'secondary_label':None},
             {'item_id':'red','spans':[{'type':'text','text':'Red'}],'secondary_label':None},
             {'item_id':'green','spans':[{'type':'text','text':'Green'}],'secondary_label':None}]}
save('presentation/generic_categorize.json', generic_base, C.Exercise)
generic_order = copy.deepcopy(load('exercises/order_steps/exercise.json'))
generic_order.update(exercise_id='ex_generic_notebook', prompt=[{'type':'text','text':'Put these test actions in order.'}])
generic_order['payload'] = {'presentation':'plain', 'steps':[
    {'step_id':'write','spans':[{'type':'text','text':'Write the date'}],'secondary_label':None},
    {'step_id':'open','spans':[{'type':'text','text':'Open the bag'}],'secondary_label':None},
    {'step_id':'take','spans':[{'type':'text','text':'Take out the notebook'}],'secondary_label':None}]}
save('presentation/generic_order.json', generic_order, C.Exercise)
manifest = [row for row in manifest if (FX / row['file']).exists()]
save('MANIFEST.json', sorted(manifest, key=lambda r: r['file']))
save('EVALUATION_CONTEXT.json', contexts)
save('COVERAGE_MATRIX.json', {'scope': 'fixtures + contextual contract primitives, no API/UI runtime', 'rows': matrix,
     'reviews': ['sessions/review_cards.json', 'sessions/review_quick.json'],
     'recitation': ['recitation/check_passed.json', 'recitation/check_errors.json', 'recitation/check_unclear.json', 'recitation/exercise_segment.json'],
     'scene_assets': ['scenes/asset_positive.scene.json', 'negative/scene_asset_wrong_dimensions.json', 'negative/scene_asset_wrong_checksum.json', 'negative/corrupt_asset.webp'],
     'limitations': ['all mode/type cross-products need UI/backend execution', 'recitation samples use test tones', 'no live scheduler/FSRS or API transaction runtime implemented']})
save('FIXTURE_ROLES.json', {row['file']: ('synthetic_seed' if row['file'].startswith('curriculum_test/') else 'widget_smoke' if row['file'] in ('sessions/session_practice_all_types.json', 'sessions/recovery_after_early_retry.json', 'sessions/history_immediate_active.json', 'scenes/session_test_scene_lesson.json') else 'contract_example') for row in manifest})
print(f'{len(manifest)} positive fixture files; {len(contexts)} linked evaluations; {len(matrix)} type/presentation rows')
