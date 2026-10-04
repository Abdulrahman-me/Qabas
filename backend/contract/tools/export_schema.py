"""Export typed revision 10 schemas (revision 9 display metadata + final-review typing)."""
import copy
import json
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'contract'))
import qabas_contract as C
from contextual import ANSWER_MODELS, DETAIL_MODELS

# Tagged unions whose variant depends on a sibling `type` field. Each is exported as a
# oneOf with an OpenAPI discriminator so OpenAPI/Dart generators produce typed variants.
BASES = {'Exercise': C.Exercise, 'ReviewerExercise': C.ReviewerExercise,
         'WsEvent': C.WsEvent, 'WsClientMessage': C.WsClientMessage}
DISPATCH = {'Exercise': ('payload', C.PAYLOADS), 'ReviewerExercise': ('payload', C.PAYLOADS),
            'WsEvent': ('data', C.WS_DATA), 'WsClientMessage': ('data', C.WS_CLIENT_DATA)}


def _typed_base(base, defs):
    field, mapping = DISPATCH[base]
    refs = []
    for tag, payload in mapping.items():
        ps = copy.deepcopy(payload.model_json_schema(by_alias=True))
        defs.update(ps.pop('$defs', {}))
        defs[payload.__name__] = ps
        variant = copy.deepcopy(BASES[base].model_json_schema(by_alias=True))
        defs.update(variant.pop('$defs', {}))
        variant['properties']['type'] = {'const': tag, 'type': 'string'}
        variant['properties'][field] = {'$ref': f'#/$defs/{payload.__name__}'}
        variant_name = f'{base}_{tag}'
        variant['title'] = variant_name
        defs[variant_name] = variant
        refs.append({'$ref': f'#/$defs/{variant_name}'})
    return {'oneOf': refs, 'discriminator': {
        'propertyName': 'type', 'mapping': {k: f'#/$defs/{base}_{k}' for k in mapping}}}


def export_all():
    schemas = {}
    for name, model in C.EXPORTED.items():
        root = copy.deepcopy(model.model_json_schema(by_alias=True))
        defs = root.setdefault('$defs', {})
        typed, done = {}, set()
        # Replace every reachable tagged base (transitively: e.g. WsEvent -> WQuestion -> Exercise).
        while True:
            text = json.dumps(root)
            pending = [b for b in BASES if b not in done and (b == name or f'"#/$defs/{b}"' in text)]
            if not pending:
                break
            for base in pending:
                typed[base] = _typed_base(base, defs)
                done.add(base)
        defs.update(typed)
        if name in BASES:
            root = {**defs[name], '$defs': defs, 'title': name}
        root['$schema'] = 'https://json-schema.org/draft/2020-12/schema'
        schemas[name] = root
    return schemas


def write():
    (ROOT / 'contract/qabas_contract.schema.json').write_text(json.dumps(export_all(), indent=1) + '\n')
    mapping = {
        'contract_revision': 10,
        'wire_format_changed': True,
        'wire_changes_since_revision_9': {
            'FactoryRun': ['review_digest', 'published'], 'Gate1': ['review_digest'], 'Gate2': ['review_digest'],
            'QAIssue.kind': ['validation'], 'Stats.league': 'nullable',
            'Metrics': 'nullable averages/rates and raqeeb_benchmark', 'AsyncAnswer.answer': 'nullable (timeout)'},
        'display_amendment': {'TermCard': 'arabic', 'Step': 'secondary_label', 'Category': 'art_key', 'POrderSteps': 'presentation'},
        'exercise_discriminator': 'type', 'reviewer_exercise_discriminator': 'type',
        'server_event_discriminator': 'type', 'client_event_discriminator': 'type',
        'raqeeb_message_discriminator': 'status',
        'answer_discriminator': 'served exercise.type (request exercise_id lookup)',
        'answer_by_type': {k: m.__name__ for k, m in ANSWER_MODELS.items()},
        'details_by_type': {k: m.__name__ for k, m in DETAIL_MODELS.items()},
        'recitation_specials': ['ASkipped'], 'map_specials': ['AUnavailable'],
        'context_required': ['served IDs', 'retry eligibility', 'order', 'private grading key', 'feedback privacy', 'six-decimal mastery snapshot', 'recitation ownership/version/range/text', 'reviewer gate digest'],
    }
    (ROOT / 'contract/dispatch_map.json').write_text(json.dumps(mapping, indent=2) + '\n')
    registry = {'scope': 'existing compiled UnitArtIcon drawings; no downloads',
                'keys': C.EXERCISE_ART, 'default': None,
                'unknown_key': 'reject content before publication', 'null': 'omit bucket artwork'}
    (ROOT / 'contract/exercise_art_registry.json').write_text(json.dumps(registry, indent=2) + '\n')


if __name__ == '__main__':
    write()
