import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/features/session/data/dtos/session_dto.dart';
import 'package:qabas/features/session/data/mappers/session_mappers.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/logic/progress.dart';
import 'package:qabas/features/session/domain/logic/teach_params.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';
import 'package:qabas/shared/data/repositories/term_state_store_impl.dart';
import 'package:qabas/shared/domain/entities/content.dart';

Map<String, dynamic> read(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
Session lesson(String path) => SessionDto.fromJson(read(path)).toEntity();
void main() {
  for (final directory in ['salah', 'unit0/sessions', 'test_lessons']) {
    for (final file in Directory('assets/mocks/$directory').listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      test('${file.path}: all content maps, nullable origin and visual are preserved', () {
        final json = read(file.path), session = lesson(file.path);
        expect(session.items.length, (json['items'] as List).length);
        expect(session.terms.length, (json['terms'] as Map).length);
        expect(session.sources.length, (json['sources'] as List).length);
        expect(session.counts.interactions, session.items.where((i) => i is ExerciseItem || i is PredictItem).length);
        if (directory == 'unit0/sessions') {
          expect(session.sourceCount, 0);
          expect(session.reviewedBy, isNull);
          for (final story in session.items.whereType<StoryItem>()) {
            final wire = (json['items'] as List).cast<Map>().firstWhere((b) => b['block_id'] == story.blockId);
            expect(story.origin == null, wire['origin'] == null);
            if (story.origin == null) {
              expect(story.provenance, isNull);
              expect(story.beats.every((b) => b.quote == null), true);
            }
          }
        }
        expect(() => session.items.clear(), throwsUnsupportedError);
        expect(() => session.terms.clear(), throwsUnsupportedError);
        if (session.objectives.isNotEmpty) expect(() => session.objectives.first.clear(), throwsUnsupportedError);
      });
    }
  }
  test('Salah preserves beat order, provenance, terms, counts and day params', () {
    for (final language in ['en', 'ar']) {
      for (final track in ['explorer', 'new_muslim']) {
        final session = lesson('assets/mocks/salah/session_salah_${language}_$track.json');
        final story = session.items.whereType<StoryItem>().single;
        expect(story.beats.map((b) => (b.visual as BuiltinVisual).params['beat']), [0, 1, 2, 3]);
        expect(story.origin!.showCard, false);
        expect(story.provenance, isNotNull);
        expect(session.terms.length, language == 'ar' ? 14 : 13);
        expect(session.counts, const SessionCounts(interactions: 8, exercises: 7, scored: 6));
        final day = session.items.whereType<TeachItem>().singleWhere(
          (t) => t.visual is BuiltinVisual && (t.visual as BuiltinVisual).key == 'day_arc',
        );
        expect([for (var shown = 1; shown <= 4; shown++) teachParams(day, shown)['highlight']], [-1, 1, 4, 4]);
        expect(lessonProgress(session, {story.blockId}), 1 / 14);
        expect(lessonProgress(session, {story.blockId, 'not-served'}), 1 / 14);
      }
    }
  });
  test('unknown discriminators and enum values render safely; missing required fields fail', () {
    expect(SpanDto.fromJson({'type': 'future', 'text': 'retained'}), isA<UnknownSpanDto>());
    final json = read('assets/mocks/salah/session_salah_en_explorer.json');
    (json['items'] as List).add({'block_id': 'new-block', 'type': 'future'});
    json['status'] = 'future';
    json['lesson_type'] = 'future';
    final session = SessionDto.fromJson(json).toEntity();
    expect(session.status, LessonSessionStatus.unknown);
    expect(session.items.last, isA<UnknownItem>());
    final visual = (json['items'] as List).first as Map<String, dynamic>;
    final v = visual['visual'] as Map<String, dynamic>;
    v['kind'] = 'future';
    expect(VisualDto.fromJson(v).toEntity(), isA<UnknownVisual>());
    json.remove('counts');
    expect(() => SessionDto.fromJson(json), throwsA(anything));
  });
  test('malformed scenario provenance and missing Quran body fail, not invented content', () {
    final json = read('assets/mocks/salah/session_salah_en_explorer.json');
    final story = (json['items'] as List).cast<Map<String, dynamic>>().firstWhere((i) => i['type'] == 'story');
    story['origin'] = null;
    expect(() => SessionDto.fromJson(json).toEntity(), throwsFormatException);
    expect(
      () => EvidenceDto.fromJson({'evidence_id': 'e', 'kind': 'quran', 'quran': null, 'hadith': null}).toEntity(),
      throwsFormatException,
    );
  });
  test('term mastery propagates immediately and pinned payload cannot regress it', () async {
    final events = AppEventBus();
    final tracked = TermStateStoreImpl(events);
    final terms = lesson('assets/mocks/salah/session_salah_en_explorer.json').terms;
    tracked.merge(terms);
    final id = terms.keys.first;
    events.publish(TermsMastered({id}));
    await Future<void>.delayed(Duration.zero);
    expect(tracked.states[id], TermState.mastered);
    tracked.merge(terms);
    expect(tracked.states[id], TermState.mastered);
    events.publish(const GuestSessionCleared());
    await Future<void>.delayed(Duration.zero);
    expect(tracked.states, isEmpty);
    await tracked.dispose();
    await events.dispose();
  });
  test('SessionCreate sends only contract keys with explicit null fields', () {
    expect(const SessionCreateDto(lessonId: 'opaque').toJson(), {'kind': 'lesson', 'lesson_id': 'opaque', 'unit_id': null, 'mode': null});
  });
}
