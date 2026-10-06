import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/handlers/mock_learning_catalog.dart';
import 'package:qabas/mock_backend/mock_db.dart';
import 'package:qabas/mock_backend/mock_router.dart';

/// Ports tool/build_demo_curriculum.py's prerequisite traversal and ordering.
Map<String, dynamic> computeJourney(
  Map<String, dynamic> curriculum,
  String language,
  String track, {
  Set<String> completed = const {},
  Set<String> inProgress = const {},
}) {
  final units = (curriculum['units'] as List).cast<Map<String, dynamic>>().where((u) => (u['tracks'] as List).contains(track)).toList();
  final byId = <String, (Map<String, dynamic>, Map<String, dynamic>)>{};
  for (final unit in units) {
    for (final lesson in (unit['lessons'] as List).cast<Map<String, dynamic>>()) {
      byId[lesson['lesson_id'] as String] = (unit, lesson);
    }
  }
  final order = {for (final entry in byId.keys.toList().asMap().entries) entry.value: entry.key};
  String text(Map value) => (value[language] ?? value['en']) as String;
  List<String> prerequisites(String id) => (byId[id]!.$2['prerequisite_lesson_ids'] as List).cast<String>();
  bool openable(String id) => prerequisites(id).every(completed.contains);
  Map<String, dynamic> ref(String id) => {'lesson_id': id, 'unit_id': byId[id]!.$1['unit_id'], 'title': text(byId[id]!.$2['title'] as Map)};
  String startWith(String id) {
    final seen = <String>{}, path = <String>[], stack = [...prerequisites(id)];
    while (stack.isNotEmpty) {
      final parent = stack.removeLast();
      if (completed.contains(parent) || !seen.add(parent)) continue;
      path.add(parent);
      stack.addAll(prerequisites(parent));
    }
    final available = path.where(openable).toList()..sort((a, b) => order[a]!.compareTo(order[b]!));
    return available.first;
  }

  Map<String, dynamic>? current;
  final out = <Map<String, dynamic>>[];
  for (final unit in units) {
    final lessons = <Map<String, dynamic>>[];
    for (final lesson in (unit['lessons'] as List).cast<Map<String, dynamic>>()) {
      final id = lesson['lesson_id'] as String;
      final state = completed.contains(id)
          ? 'completed'
          : inProgress.contains(id)
          ? 'in_progress'
          : openable(id)
          ? 'available'
          : 'locked';
      final unmet = prerequisites(id).where((p) => !completed.contains(p)).toList()..sort((a, b) => order[a]!.compareTo(order[b]!));
      lessons.add({
        for (final key in ['lesson_id', 'index', 'lesson_type', 'estimated_minutes', 'xp', 'standalone_eligible']) key: lesson[key],
        'title': text(lesson['title'] as Map),
        'state': state,
        'soft_lock': state != 'locked' ? null : {'prerequisites': unmet.map(ref).toList(), 'start_with': ref(startWith(id))},
      });
      if (current == null && ['available', 'in_progress'].contains(state)) current = {'unit_id': unit['unit_id'], 'lesson_id': id};
    }
    final states = lessons.map((l) => l['state']).toList();
    final state = unit['coming_soon'] == true || lessons.isEmpty
        ? 'locked'
        : states.every((s) => s == 'completed')
        ? 'completed'
        : states.any((s) => ['in_progress', 'completed'].contains(s))
        ? 'in_progress'
        : states.any((s) => s != 'locked')
        ? 'available'
        : 'locked';
    final subtitle = unit['subtitle'] as Map;
    out.add({
      for (final key in ['unit_id', 'index', 'art_key', 'has_guide', 'coming_soon']) key: unit[key],
      'title': text(unit['title'] as Map),
      'subtitle': text(subtitle.containsKey('explorer') ? subtitle[track] as Map : subtitle),
      'state': state,
      'pretest': {'state': 'not_taken'},
      'unit_test': {'state': 'not_passed', 'best_percent': null, 'pass_percent': 80, 'can_skip': false},
      'lessons': lessons,
    });
  }
  // TODO(contract): A-35 — the reference returns null at completion; the wire
  // contract requires JourneyCurrent with nullable IDs, so normalize only that.
  return {
    'track': track,
    'current': current ?? {'unit_id': null, 'lesson_id': null},
    'units': out,
  };
}

void registerJourney(MockRouter router, MockDb db, Fixtures fixtures) {
  Future<Map<String, dynamic>> journey(BackendRequest request) async => db.contractCurriculum
      ? mockContractJourney(fixtures, db, request.header('Accept-Language') ?? db.user!['language'] as String, db.user!['track'] as String)
      : computeJourney(
          await fixtures.object('demo_curriculum/curriculum.json'),
          request.header('Accept-Language') ?? db.user!['language'] as String,
          db.user!['track'] as String,
          completed: db.completedLessons,
          inProgress: db.inProgressLessons,
        );
  router.routes.addAll([
    MockRoute('GET', '/units/{id}/guide', (request, p) async {
      final guide = await fixtures.example('Guide');
      return guide['unit_id'] == p['id'] ? BackendResponse(200, guide) : BackendResponse.error(404, 'not_found', 'Guide unavailable');
    }),
    MockRoute('GET', '/journey', (request, _) async => BackendResponse(200, await journey(request))),
    MockRoute('GET', '/journey/next', (request, _) async {
      final data = await journey(request);
      return BackendResponse(
        200,
        db.contractCurriculum ? computeContractNextStep(data, db.dueReviews) : computeNextStep(data, db.dueReviews),
      );
    }),
  ]);
}

Map<String, dynamic> computeNextStep(Map<String, dynamic> journey, int dueReviews) {
  final current = journey['current'] as Map, id = current['lesson_id'];
  final lessons = (journey['units'] as List).cast<Map>().expand((u) => (u['lessons'] as List).cast<Map>());
  final title = lessons.where((l) => l['lesson_id'] == id).firstOrNull?['title'];
  return {
    'type': dueReviews > 0
        ? 'review'
        : id == null
        ? 'journey_complete'
        : 'lesson',
    'reason': dueReviews > 0
        ? 'due_reviews'
        : id == null
        ? 'all_done'
        : 'next_lesson',
    'unit_id': dueReviews > 0 ? null : current['unit_id'],
    'lesson_id': dueReviews > 0 ? null : id,
    'title': dueReviews > 0 ? null : title,
    'due_reviews_count': dueReviews,
  };
}

Map<String, dynamic> computeContractNextStep(Map<String, dynamic> journey, int dueReviews) {
  if (dueReviews > 0) return computeNextStep(journey, dueReviews);
  final units = (journey['units'] as List).cast<Map>();
  final readyTest = units.where((u) => u['state'] == 'completed' && (u['unit_test'] as Map)['state'] != 'passed').firstOrNull;
  final current = journey['current'] as Map;
  final newUnit = units.where((u) => u['unit_id'] == current['unit_id'] && (u['pretest'] as Map)['state'] == 'not_taken').firstOrNull;
  final unit = readyTest ?? newUnit;
  if (unit == null) return computeNextStep(journey, dueReviews);
  return {
    'type': readyTest != null ? 'unit_test' : 'pretest',
    'reason': readyTest != null ? 'unit_ready_for_test' : 'new_unit_pretest',
    'unit_id': unit['unit_id'],
    'lesson_id': null,
    'title': unit['title'],
    'due_reviews_count': 0,
  };
}
