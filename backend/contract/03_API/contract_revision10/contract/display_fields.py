"""Explicit null/plain backfill for pre-amendment test content.

This never infers Arabic text, decoration or bank order from translated labels.
Source-backed values are supplied by the actual Dart reference exporter.
"""
import copy
import qabas_contract as C


def backfill_legacy(value):
    value = copy.deepcopy(value)
    def walk(obj):
        if isinstance(obj, list):
            for item in obj: walk(item)
        elif isinstance(obj, dict):
            if {'term_id', 'transliteration', 'definition', 'example'} <= obj.keys():
                obj.setdefault('arabic', None)
            if {'category_id', 'label', 'phase', 'capacity'} <= obj.keys():
                obj.setdefault('art_key', None)
            if {'step_id', 'spans'} <= obj.keys():
                obj.setdefault('secondary_label', None)
            if 'steps' in obj and isinstance(obj['steps'], list) and obj['steps'] and all(
                    isinstance(step, dict) and {'step_id', 'spans'} <= step.keys() for step in obj['steps']):
                obj.setdefault('presentation', 'plain')
            for item in list(obj.values()): walk(item)
    walk(value)
    return value


def project_term(record, language, *, state='new', level='basic', lesson_title=None):
    """One canonical projection for glossary, sessions, guides and Raqeeb."""
    stored = C.StoredGlossaryTerm.model_validate(record).model_dump()
    if language not in ('ar', 'en'):
        raise ValueError('unsupported glossary language')
    definitions = stored['definition'][level] or stored['definition']['basic']
    return C.TermCard.model_validate({
        'term_id': stored['term_id'], 'text': stored['text'][language],
        'arabic': stored['arabic'], 'transliteration': stored['transliteration'],
        'state': state, 'level': level, 'definition': definitions[language],
        'example': stored['example'][language], 'pronunciation_audio_url': stored['pronunciation_audio_url'],
        'source_id': stored['source_id'], 'lesson_id': stored['lesson_id'], 'lesson_title': lesson_title,
    }).model_dump()
