import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_db.dart';

/// Read-only fixture routing. The synthetic curriculum is a developer choice.
final class MockLearningCatalog {
  const MockLearningCatalog(this.fixtures, this.db);
  final Fixtures fixtures;
  final MockDb db;
  Future<Map<String, dynamic>?> extraLesson(String id, String language, String track) async {
    if (id == 'les_test_all') {
      return fixtures.object(
        'contract/sessions/session_practice_all_types.json',
      ); // TODO(contract): A-45 — exact supplied practice fixture identity.
    }
    if (!db.contractCurriculum) return null;
    final journey = await fixtures.object('contract/curriculum_test/journey_${language}_$track.json');
    final exists = (journey['units'] as List)
        .cast<Map>()
        .expand((u) => (u['lessons'] as List).cast<Map>())
        .any((l) => l['lesson_id'] == id);
    return exists ? fixtures.object('contract/curriculum_test/lessons/${id}__${language}_$track.json') : null;
  }

  Future<Map<String, dynamic>?> readerSource(String id, String language, String track) async {
    final extra = await extraLesson(id, language, track);
    if (extra != null) return extra;
    if (id == 'les_u1_l3') return fixtures.object('salah/session_salah_${language}_$track.json');
    if (id == 'les_u1_l1') return fixtures.object('test_lessons/u1l1_${language}_$track.json');
    if (track != 'explorer') return null;
    final index = await fixtures.object('unit0/SESSION_INDEX.json');
    final row = (index['sessions'] as List)
        .cast<Map>()
        .where((r) => r['lesson_id'] == id && r['variant'] == '${language}_explorer')
        .firstOrNull;
    return row == null ? null : fixtures.object('unit0/${row['path']}');
  }

  Future<Map<String, dynamic>?> flow(String kind, String? unit, String? mode, String language, String track) async {
    if (kind == 'review') {
      if (!['cards', 'quick'].contains(mode)) return null;
      final session = await fixtures.object(
        fixtures.recording ? 'recording/review_${mode}_$language.json' : 'contract/sessions/review_$mode.json',
      );
      if (mode == 'cards') {
        session['items'] = (session['items'] as List).take(db.dueReviews.clamp(0, 12)).toList();
        final count = (session['items'] as List).length;
        session['counts'] = {'interactions': count, 'exercises': count, 'scored': 0};
        session['total_exercises'] = count;
      }
      return session;
    }
    if (!db.contractCurriculum || !['pretest', 'unit_test'].contains(kind)) return null;
    final journey = await fixtures.object('contract/curriculum_test/journey_${language}_$track.json');
    final entry = (journey['units'] as List).cast<Map>().where((u) => u['unit_id'] == unit && u['coming_soon'] != true).firstOrNull;
    if (entry == null) return null;
    return fixtures.object('contract/curriculum_test/assessments/ses_${unit}_${kind}_${language}_$track.json');
  }

  Future<Map<String, dynamic>> keys(Map<String, dynamic> session) async {
    if (fixtures.recording && session['kind'] == 'review') {
      final language = db.user?['language'] ?? 'en';
      return fixtures.object('recording/review_keys_$language.json');
    }
    final supplied = await fixtures.object('contract/curriculum_test/PRIVATE_GRADING_KEYS.json');
    final keys = <String, dynamic>{};
    for (final item in (session['items'] as List).cast<Map>().where((i) => i['type'] == 'exercise')) {
      final e = item['exercise'] as Map, id = e['exercise_id'] as String;
      if (supplied.containsKey(id)) {
        keys[id] = {'answer_key': supplied[id]};
        continue;
      }
      final type = e['type'] as String, payload = e['payload'] as Map;
      if (type == 'flashcard' || type == 'recite_verse') {
        keys[id] = {'answer_key': null};
        continue;
      }
      final directory = ['categorize', 'map_place'].contains(type) ? '${type}__${payload['presentation']}' : type;
      final sample = await fixtures.object('contract/exercises/$directory/eval_correct.json');
      keys[id] = {
        'answer_key': sample['correct_answer'],
        'explanation': sample['explanation'],
        'details': sample['details'],
        'source_ids': sample['source_ids'],
      };
    }
    return keys;
  }
}

Future<Map<String, dynamic>> mockContractJourney(Fixtures fixtures, MockDb db, String language, String track) async {
  final journey = await fixtures.object('contract/curriculum_test/journey_${language}_$track.json');
  return projectContractJourney(journey, db);
}

Map<String, dynamic> projectContractJourney(Map<String, dynamic> journey, MockDb db) {
  Map<String, dynamic>? current;
  final lessonUnits = <Object?, Object?>{
    for (final u in (journey['units'] as List).cast<Map>())
      for (final l in (u['lessons'] as List).cast<Map>()) l['lesson_id']: u['unit_id'],
  };
  for (final unit in (journey['units'] as List).cast<Map>()) {
    final id = unit['unit_id'];
    final score = db.unitBestScores[id];
    if (db.pretestedUnits.contains(id)) (unit['pretest'] as Map)['state'] = 'taken';
    if (score != null) (unit['unit_test'] as Map)['best_percent'] = score;
    if (db.passedUnits.contains(id)) {
      (unit['unit_test'] as Map).addAll(<String, dynamic>{'state': 'passed', 'can_skip': false});
      unit['state'] = 'skipped';
    }
    for (final lesson in (unit['lessons'] as List).cast<Map>()) {
      final lessonId = lesson['lesson_id'];
      if (db.completedLessons.contains(lessonId)) {
        lesson['state'] = 'completed';
      } else if (db.inProgressLessons.contains(lessonId)) {
        lesson['state'] = 'in_progress';
      } else if (lesson['state'] == 'locked' && lesson['soft_lock'] is Map) {
        final missing = ((lesson['soft_lock'] as Map)['prerequisites'] as List)
            .cast<Map>()
            .where((p) => !db.completedLessons.contains(p['lesson_id']) && !db.passedUnits.contains(lessonUnits[p['lesson_id']]))
            .toList();
        if (missing.isEmpty) {
          lesson['state'] = 'available';
          lesson['soft_lock'] = null;
        } else {
          (lesson['soft_lock'] as Map)['prerequisites'] = missing;
        }
      }
      if (current == null && !db.passedUnits.contains(id) && ['available', 'in_progress'].contains(lesson['state'])) {
        current = {'unit_id': id, 'lesson_id': lessonId};
      }
    }
    if (!db.passedUnits.contains(id) &&
        (unit['lessons'] as List).isNotEmpty &&
        (unit['lessons'] as List).cast<Map>().every((l) => l['state'] == 'completed')) {
      unit['state'] = 'completed';
    }
  }
  journey['current'] = current ?? {'unit_id': null, 'lesson_id': null};
  return journey;
}
