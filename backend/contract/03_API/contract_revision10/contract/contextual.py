"""Served-context checks and exact mastery arithmetic; no network or LLM grading.

These functions are contract primitives. A production API must call them inside
the transaction that stores an attempt. They are not a backend implementation.
"""
from collections import Counter
from decimal import Decimal, ROUND_HALF_UP
import hashlib
import json
import re
from urllib.parse import urlsplit
import qabas_contract as C

ANSWER_MODELS = {
    'multiple_choice': C.AOption, 'true_false_reason': C.AReason,
    'match_pairs': C.APairs, 'flashcard': C.ARating, 'fill_blank': C.AFills,
    'categorize': C.AAssignments, 'spot_error': C.ASegment,
    'which_evidence': C.AOption, 'order_steps': C.AOrder,
    'scenario': C.AOption, 'timeline_order': C.AOrder, 'map_place': C.APin,
    'recite_verse': C.ACheck, 'verse_meaning': C.AOption, 'true_false': C.AValue,
}
DETAIL_MODELS = {
    'true_false_reason': C.DReason, 'match_pairs': C.DPairs,
    'fill_blank': C.DFills, 'categorize': C.DAssignments,
    'order_steps': C.DOrder, 'scenario': C.DScenario,
    'timeline_order': C.DTimeline, 'map_place': C.DPins,
}

def _same_once(values, expected, label):
    if Counter(values) != Counter(expected) or len(set(values)) != len(values):
        raise ValueError(f'{label}: every served ID must appear exactly once')

def validate_answer(exercise, answer, *, special=True):
    """Validate shape and served identifiers, independent of private correctness."""
    typ, payload = exercise['type'], exercise['payload']
    if special and typ == 'map_place' and answer == {'unavailable': True}:
        return
    if special and typ == 'recite_verse' and answer == {'skipped': True}:
        if not payload['skippable']:
            raise ValueError('this recitation cannot be skipped')
        return
    a = ANSWER_MODELS[typ].model_validate(answer).model_dump()
    if typ in ('multiple_choice', 'scenario', 'which_evidence', 'verse_meaning'):
        if a['option_id'] not in {x['option_id'] for x in payload['options']}:
            raise ValueError('option_id was not served')
    elif typ == 'true_false_reason':
        if a['reason_option_id'] not in {x['option_id'] for x in payload['reasons']}:
            raise ValueError('reason_option_id was not served')
    elif typ == 'match_pairs':
        _same_once([x['left_id'] for x in a['pairs']], [x['item_id'] for x in payload['left']], 'left')
        _same_once([x['right_id'] for x in a['pairs']], [x['item_id'] for x in payload['right']], 'right')
    elif typ == 'fill_blank':
        _same_once([x['blank_id'] for x in a['fills']], [x['blank_id'] for x in payload['segments'] if x['type'] == 'blank'], 'blanks')
        if set(x['word_id'] for x in a['fills']) - set(x['word_id'] for x in payload['word_bank']):
            raise ValueError('word_id was not served')
    elif typ == 'categorize':
        _same_once([x['item_id'] for x in a['assignments']], [x['item_id'] for x in payload['items']], 'items')
        cats = {x['category_id']: x for x in payload['categories']}
        counts = Counter(x['category_id'] for x in a['assignments'])
        for cid, n in counts.items():
            if cid not in cats or (cats[cid]['capacity'] is not None and n > cats[cid]['capacity']):
                raise ValueError('unknown category or exceeded capacity')
    elif typ == 'spot_error':
        if a['segment_id'] not in {x['segment_id'] for x in payload['segments']}:
            raise ValueError('segment_id was not served')
    elif typ in ('order_steps', 'timeline_order'):
        field, ident = ('steps', 'step_id') if typ == 'order_steps' else ('events', 'event_id')
        _same_once(a['order'], [x[ident] for x in payload[field]], 'order')
    elif typ == 'map_place':
        if a['pin_id'] not in {x['pin_id'] for x in payload['pins']}:
            raise ValueError('pin_id was not served')

def validate_attempt(exercise, submitted, kind, *, original_correct=None):
    """Validate a fresh attempt only, after authenticated recorded-identity lookup.

    A recorded identity must replay before this function inspects the changed
    body. A FastAPI route must preserve that order instead of eagerly validating
    AnswerSubmit at its boundary before checking the attempt table.
    """
    C.Exercise.model_validate(exercise)
    body = C.AnswerSubmit.model_validate(submitted).model_dump()
    if body['exercise_id'] != exercise['exercise_id']:
        raise ValueError('exercise_id does not match the served exercise')
    typ = exercise['type']
    if typ == 'true_false' and kind != 'challenge':
        raise ValueError('true_false is challenge-only')
    if kind in ('pretest', 'unit_test') and typ in ('flashcard', 'recite_verse'):
        raise ValueError('assessment excludes flashcard and recitation')
    if kind == 'challenge' and typ not in ('multiple_choice', 'true_false', 'verse_meaning'):
        raise ValueError('unsupported challenge question type')
    if body['is_retry'] and (kind != 'lesson' or original_correct is not False or typ in ('recite_verse', 'flashcard')):
        raise ValueError('retry requires an eligible incorrect original in a lesson')
    if body['elapsed_ms'] < 0:
        raise ValueError('elapsed_ms cannot be negative')
    if body['answer'] is None:
        if exercise['time_limit_ms'] is None or typ in ('flashcard', 'recite_verse'):
            raise ValueError('timeout requires a timed exercise')
        if body['elapsed_ms'] < exercise['time_limit_ms']:
            raise ValueError('timeout cannot precede the served deadline')
    else:
        validate_answer(exercise, body['answer'])
    return body

def grade_answer(exercise, submitted, private_key, *, recitation_passed=None):
    """Deterministic key comparison after served-context validation.

    The caller owns authentication, the immutable private key lookup, timer
    authority and stored recitation-check binding. This is not ASR.
    """
    answer = submitted['answer']
    typ = exercise['type']
    if answer is None:
        return False
    if answer in ({'skipped': True}, {'unavailable': True}):
        return None
    validate_answer(exercise, answer)
    if typ == 'flashcard':
        return answer['rating'] != 'again'
    if typ == 'recite_verse':
        if type(recitation_passed) is not bool:
            raise ValueError('bound recitation result required')
        return recitation_passed
    validate_answer(exercise, private_key, special=False)
    def normalized(value):
        if typ in ('match_pairs', 'fill_blank', 'categorize'):
            return sorted(json.dumps(row, sort_keys=True) for row in next(iter(value.values())))
        return value
    return normalized(answer) == normalized(private_key)

def mastery_rule(exercise, submitted, kind, correct):
    a = submitted['answer']
    if submitted['is_retry']:
        return 'retry_correct' if correct is True else 'retry_incorrect'
    if exercise['type'] == 'recite_verse':
        return 'recitation_passed' if correct is True else 'none'
    if correct is None:
        return 'none'
    if exercise['type'] == 'flashcard' and a['rating'] == 'hard':
        return 'flashcard_hard'
    if kind == 'pretest':
        return 'pretest_correct' if correct else 'pretest_incorrect'
    if kind == 'challenge':
        return 'none'
    return 'correct' if correct else 'incorrect'

def update_mastery(before, rule):
    b = Decimal(str(before))
    if not Decimal(0) <= b <= Decimal(1):
        raise ValueError('mastery must be in [0,1]')
    gain = {'correct': '.35', 'retry_correct': '.10', 'recitation_passed': '.15',
            'flashcard_hard': '.15', 'pretest_correct': '.175'}
    loss = {'incorrect': '.25', 'pretest_incorrect': '.125'}
    if rule in gain:
        b += Decimal(gain[rule]) * (1 - b)
    elif rule in loss:
        b -= Decimal(loss[rule]) * b
    elif rule not in ('none', 'retry_incorrect'):
        raise ValueError(f'unknown mastery rule: {rule}')
    return b.quantize(Decimal('.000001'), rounding=ROUND_HALF_UP)

def report_mastery(value):
    return float(Decimal(str(value)).quantize(Decimal('.01'), rounding=ROUND_HALF_UP))

def validate_evaluation(exercise, submitted, kind, evaluation, mastery_before, *, private_key=None, recitation_passed=None):
    """Verify feedback using a private six-decimal snapshot, never a filename."""
    ev = C.AnswerEvaluation.model_validate(evaluation).model_dump()
    if ev['exercise_id'] != exercise['exercise_id'] or submitted['exercise_id'] != exercise['exercise_id']:
        raise ValueError('evaluation identity mismatch')
    typ = exercise['type']
    computed = grade_answer(exercise, submitted, private_key, recitation_passed=recitation_passed)
    if ev['correct'] is not computed:
        raise ValueError('evaluation correctness disagrees with the private key/check')
    if typ not in ('flashcard', 'recite_verse') and computed is not None and ev['correct_answer'] != private_key:
        raise ValueError('disclosed correct_answer must match the pinned private key')
    if ev['correct_answer'] is not None:
        if typ in ('flashcard', 'recite_verse'):
            raise ValueError('this type does not disclose a correct_answer')
        validate_answer(exercise, ev['correct_answer'], special=False)
    if ev['details'] is not None:
        if typ not in DETAIL_MODELS:
            raise ValueError('details are not defined for this type')
        DETAIL_MODELS[typ].model_validate(ev['details'])
        a = submitted['answer'] or {}
        if typ == 'true_false_reason':
            expected = {'value_correct': a.get('value') == private_key['value'],
                        'reason_correct': a.get('reason_option_id') == private_key['reason_option_id']}
            if ev['details'] != expected:
                raise ValueError('reason feedback disagrees with the answer/key')
        if typ in ('match_pairs', 'fill_blank', 'categorize'):
            answer_field, ident, chosen, feedback_field = {
                'match_pairs': ('pairs', 'left_id', 'right_id', 'pair_results'),
                'fill_blank': ('fills', 'blank_id', 'word_id', 'blank_results'),
                'categorize': ('assignments', 'item_id', 'category_id', 'item_results'),
            }[typ]
            targets = {x[ident]: x[chosen] for x in private_key[answer_field]}
            supplied = {x[ident]: x[chosen] for x in a.get(answer_field, [])}
            for row in ev['details'][feedback_field]:
                if row['correct'] != (supplied.get(row[ident]) == targets.get(row[ident])):
                    raise ValueError('per-item correctness disagrees with the answer/key')
        if typ == 'order_steps':
            supplied = a.get('order', [])
            expected_index = next((i for i, key in enumerate(private_key['order'])
                                   if i >= len(supplied) or supplied[i] != key), None)
            if ev['details']['first_wrong_index'] != expected_index:
                raise ValueError('first_wrong_index disagrees with the answer/key')
        if typ in ('match_pairs', 'fill_blank', 'categorize', 'timeline_order', 'map_place'):
            key, ident, expected = {
                'match_pairs': ('pair_results', 'left_id', [x['item_id'] for x in exercise['payload'].get('left', [])]),
                'fill_blank': ('blank_results', 'blank_id', [x['blank_id'] for x in exercise['payload'].get('segments', []) if x['type'] == 'blank']),
                'categorize': ('item_results', 'item_id', [x['item_id'] for x in exercise['payload'].get('items', [])]),
                'timeline_order': ('event_dates', 'event_id', [x['event_id'] for x in exercise['payload'].get('events', [])]),
                'map_place': ('pin_labels', 'pin_id', [x['pin_id'] for x in exercise['payload'].get('pins', [])]),
            }[typ]
            _same_once([x[ident] for x in ev['details'][key]], expected, 'feedback IDs')
        if typ == 'scenario' and set(x['option_id'] for x in ev['details']['option_feedback']) - set(x['option_id'] for x in exercise['payload']['options']):
            raise ValueError('feedback option was not served')
        if typ == 'order_steps' and ev['details']['first_wrong_index'] is not None and ev['details']['first_wrong_index'] >= len(exercise['payload']['steps']):
            raise ValueError('first_wrong_index is outside the served steps')
    elif typ in DETAIL_MODELS and computed is not None:
        raise ValueError('this type requires evaluation details')
    if typ == 'flashcard':
        if ev['correct'] != (submitted['answer']['rating'] != 'again'):
            raise ValueError('flashcard rating and correct disagree')
    if submitted['answer'] in ({'skipped': True}, {'unavailable': True}) and ev['correct'] is not None:
        raise ValueError('skipped/unavailable must be neutral')
    rule = mastery_rule(exercise, submitted, kind, ev['correct'])
    changes = {m['concept_id']: m for m in ev['mastery_changes']}
    if len(changes) != len(ev['mastery_changes']):
        raise ValueError('duplicate mastery change')
    if rule in ('none', 'retry_incorrect'):
        if changes:
            raise ValueError('no-change outcome must not report mastery changes')
    else:
        if set(changes) != set(exercise['concept_ids']):
            raise ValueError('mastery changes must cover the served concepts')
        for cid, mc in changes.items():
            before = mastery_before[cid]
            if (mc['before'], mc['after']) != (report_mastery(before), report_mastery(update_mastery(before, rule))):
                raise ValueError(f'incorrect mastery snapshot for {cid}: {rule}')
    return ev

def validate_recitation_binding(exercise, check, *, user_id, exercise_version):
    p = exercise['payload']
    expected = (user_id, exercise['exercise_id'], exercise_version, p['surah'], p['ayah'], p['word_start'], p['word_end'],
                hashlib.sha256(p['text_uthmani'].encode()).hexdigest())
    actual = tuple(check[k] for k in ('user_id', 'exercise_id', 'exercise_version', 'surah', 'ayah', 'word_start', 'word_end', 'text_sha256'))
    if actual != expected:
        raise ValueError('recitation check is not bound to this user and served version/range/text')

def session_composition_errors(s, *, production_lesson=True):
    errors = []
    xs = [b['exercise'] for b in s['items'] if b['type'] == 'exercise']
    kind = s['kind']
    # Structural bound only (rev 10 curriculum amendment; was 4–8). Per-type targets (concept/practice
    # 2–4, story 2–3) are pedagogical QA warnings in the factory, not composition errors.
    if kind == 'lesson' and production_lesson and not 2 <= sum(e['scoring']['accuracy'] for e in xs) <= 6:
        errors.append('production lessons require 2–6 scored exercises')
    if kind == 'pretest' and not 6 <= len(xs) <= 8:
        errors.append('pretests require 6–8 distinct exercises')
    if kind == 'unit_test' and not 9 <= len(xs) <= 12:
        errors.append('unit tests require 9–12 distinct exercises')
    if kind == 'review':
        if s['mode'] == 'cards' and (not 1 <= len(xs) <= 12 or any(e['type'] != 'flashcard' or e['time_limit_ms'] is not None for e in xs)):
            errors.append('cards require 1–12 untimed flashcards')
        elif s['mode'] == 'quick' and (not 1 <= len(xs) <= 10 or any(e['time_limit_ms'] != 20000 or e['type'] in ('recite_verse', 'flashcard') or
            (e['type'] == 'categorize' and e['payload']['presentation'] == 'day_arc') or
            (e['type'] == 'map_place' and e['payload']['visual']['kind'] == 'builtin') for e in xs)):
            errors.append('invalid quick-review composition')
        elif s['mode'] not in ('cards', 'quick'):
            errors.append('review mode required')
    elif s['mode'] is not None:
        errors.append('mode is review-only')
    feedback = {'lesson': 'immediate', 'review': 'immediate', 'pretest': 'none', 'unit_test': 'end'}[kind]
    if s['feedback_mode'] != feedback:
        errors.append('feedback_mode does not match session kind')
    return errors


# ---------------------------------------------------------------- pre-generation audit (factory §13.4, §13.5)
SEMANTIC_BLOCKING_CONCERNS = {'beyond_source', 'single_opinion_as_consensus'}


def scholarly_review_issues(claims):
    """`scholarly_review` QA issues from the Evidence Verifier's semantic reviews of supporting evidence.
    The flags are for the specialist, who stays authoritative. A sentence that says more than its source, or presents
    one scholarly opinion as the only view, blocks until the wording is narrowed or the specialist records an edit."""
    issues = []
    for claim in claims:
        if claim['status'] != 'supported':
            continue
        for item in claim['evidence']:
            review = item.get('semantic_review')
            if not item['supports'] or not review or not review['concerns']:
                continue
            severity = 'blocker' if SEMANTIC_BLOCKING_CONCERNS & set(review['concerns']) else 'warning'
            issues.append({'severity': severity, 'kind': 'scholarly_review',
                           'location': {'sentence_id': None, 'exercise_id': None, 'scene_id': None},
                           'message': f"{claim['claim_id']} / {item['source']['source_id']} ({review['fit']}; "
                                      f"{', '.join(review['concerns'])}): {review['note']}"})
    return issues


PLACEHOLDER_HOST = re.compile(r'(^|\.)(example\.(com|net|org)|localhost)$|\.(example|test|invalid|localhost)$')


def _media_urls(payload, path='$'):
    if isinstance(payload, dict):
        for key, value in payload.items():
            here = f'{path}.{key}'
            if isinstance(value, str) and (key == 'url' or key.endswith('_url')):
                yield here, value
            else:
                yield from _media_urls(value, here)
    elif isinstance(payload, list):
        for i, value in enumerate(payload):
            yield from _media_urls(value, f'{path}[{i}]')


def _is_placeholder(url):
    parts = urlsplit(url)
    return parts.scheme == 'mock-asset' or bool(parts.hostname and PLACEHOLDER_HOST.search(parts.hostname))


def placeholder_media_errors(payload):
    """Publication gate: no URL in a lesson version, session or draft may point at a reserved example host,
    `mock-asset://` test media or a non-https location. Test fixtures use these on purpose and are never published."""
    errors = []
    for here, value in _media_urls(payload):
        parts = urlsplit(value)
        if _is_placeholder(value):
            errors.append(f'{here}: placeholder media URL {value}')
        elif parts.scheme != 'https' or not parts.hostname:
            errors.append(f'{here}: not a published https media URL {value}')
    return errors


VISUAL_PUBLISHABLE = {'compiled', 'audited'}


def visual_readiness(draft_visual, *, released_capabilities):
    """Readiness of one `DraftVisual`, derived from existing fields (factory §13.4 visual readiness):
    `placeholder` (a media URL is a reserved example host or `mock-asset://`), `compiled` (builtin scene shipped in the app),
    `capability_blocked` (a generated scene needs a capability that is not released), `preview_only` (scene frames
    not rendered by a `qabas_scene` build, e.g. the non-normative SVG preview), `unaudited`, `audit_failed`, `audited`.
    Gate 2 approval requires every visual to be `compiled` or `audited`, and publication additionally requires
    `placeholder_media_errors` to be empty (immutable https CDN URLs)."""
    visual = draft_visual['visual']
    if any(_is_placeholder(url) for _, url in _media_urls(visual)):
        return 'placeholder'
    if draft_visual['origin'] == 'builtin':
        return 'compiled'
    if draft_visual['origin'] == 'generated_scene':
        if not set(visual['scene']['required_capabilities']) <= set(released_capabilities):
            return 'capability_blocked'
        if not draft_visual['previews']['renderer_version'].startswith('qabas_scene '):
            return 'preview_only'
    audit = draft_visual['audit']
    if audit is None:
        return 'unaudited'
    return 'audited' if audit['passed'] else 'audit_failed'
