import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/mock_backend/data/mock_state_store.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/handlers/mock_activity.dart';
import 'package:qabas/mock_backend/mock_db.dart';
import 'package:qabas/mock_backend/mock_router.dart';
import 'package:uuid/uuid.dart';

void registerAuthProfile(MockRouter router, MockDb db, Fixtures fixtures) {
  BackendResponse invalid(String field) => BackendResponse.error(400, 'validation_error', '$field is invalid', {'field': field});
  router.routes.addAll([
    MockRoute('POST', '/auth/guest', (request, _) async {
      final body = request.body;
      if (body is! Map<String, dynamic> ||
          body.keys.any((key) => key != 'timezone') ||
          body['timezone'] is! String ||
          (body['timezone'] as String).isEmpty) {
        return invalid('timezone');
      }
      if (fixtures.recording && db.suspendedLearner != null) {
        final learner = db.suspendedLearner!;
        db.reset();
        MockStateStore.restoreSnapshot(db, learner);
        db.suspendedLearner = null;
        db.tokens.clear();
        db.tokenDigests.clear();
        final token = 'mock_${const Uuid().v4()}';
        db.tokens.add(token);
        return BackendResponse(201, {'access_token': token, 'user': db.user});
      }
      final user = await fixtures.example('User');
      user.addAll({
        'user_id': 'usr_${const Uuid().v4()}',
        'timezone': body['timezone'],
        'language': request.header('Accept-Language') ?? 'en',
        'onboarding_completed': false,
        'familiarity': null,
        'track': 'explorer',
        'private_profile': true,
        'goal_anchor': null,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      db.reset();
      db.user = user;
      if (fixtures.recording) db.dueReviews = 12;
      final token = 'mock_${const Uuid().v4()}';
      db.tokens.add(token);
      return BackendResponse(201, {'access_token': token, 'user': user});
    }),
    MockRoute('POST', '/onboarding', (request, _) async {
      final body = request.body;
      const keys = {'track_choice', 'language', 'familiarity', 'daily_goal_minutes', 'private_profile', 'goal_anchor'};
      if (body is! Map<String, dynamic> || body.length != keys.length || body.keys.any((key) => !keys.contains(key))) {
        return invalid('body');
      }
      if (!['explorer', 'new_muslim', 'undisclosed'].contains(body['track_choice'])) return invalid('track_choice');
      if (!['en', 'ar'].contains(body['language'])) return invalid('language');
      if (![null, 'none', 'some', 'good'].contains(body['familiarity'])) return invalid('familiarity');
      if (![5, 10, 15, 20].contains(body['daily_goal_minutes'])) return invalid('daily_goal_minutes');
      if (body['private_profile'] is! bool) return invalid('private_profile');
      if (![
        null,
        'does_god_exist',
        'who_is_god',
        'quran_special',
        'who_was_muhammad',
        'muslim_beliefs',
        'why_pray',
      ].contains(body['goal_anchor'])) {
        return invalid('goal_anchor');
      }
      final track = body['track_choice'] == 'new_muslim' ? 'new_muslim' : 'explorer';
      db.user!.addAll({
        for (final key in ['language', 'familiarity', 'daily_goal_minutes', 'private_profile', 'goal_anchor']) key: body[key],
        'track': track,
        'onboarding_completed': true,
      });
      final journey = await fixtures.object('demo_curriculum/journey_initial_${body['language']}_$track.json');
      final current = journey['current'] as Map<String, dynamic>;
      final firstUnit = (journey['units'] as List<dynamic>).cast<Map<String, dynamic>>().first;
      final firstLesson = (firstUnit['lessons'] as List<dynamic>).cast<Map<String, dynamic>>().first;
      return BackendResponse(200, {
        'user': db.user,
        'start_unit_id': track == 'new_muslim' ? 'unit_1' : 'unit_0',
        'next_step': {
          'type': 'lesson',
          'reason': 'next_lesson',
          'unit_id': current['unit_id'],
          'lesson_id': current['lesson_id'],
          'title': firstLesson['title'],
          'due_reviews_count': 0,
        },
      });
    }),
    MockRoute(
      'GET',
      '/me',
      (_, _) async => db.user == null ? BackendResponse.error(401, 'unauthorized', 'Session ended') : BackendResponse(200, db.user),
    ),
    MockRoute('PATCH', '/me', (request, _) async {
      final body = request.body;
      const allowed = {
        'display_name',
        'language',
        'track',
        'daily_goal_minutes',
        'timezone',
        'avatar_key',
        'private_profile',
        'goal_anchor',
      };
      if (body is! Map<String, dynamic> || body.isEmpty) return invalid('body');
      for (final entry in body.entries) {
        if (!allowed.contains(entry.key) || entry.value == null) return invalid(entry.key);
        final value = entry.value;
        final valid = switch (entry.key) {
          'language' => ['en', 'ar'].contains(value),
          'track' => ['explorer', 'new_muslim'].contains(value),
          'daily_goal_minutes' => [5, 10, 15, 20].contains(value),
          'private_profile' => value is bool,
          'display_name' => value is String && value.runes.length >= 2 && value.runes.length <= 24,
          'goal_anchor' => [
            'does_god_exist',
            'who_is_god',
            'quran_special',
            'who_was_muhammad',
            'muslim_beliefs',
            'why_pray',
          ].contains(value),
          _ => value is String && value.isNotEmpty,
        };
        if (!valid) return invalid(entry.key);
      }
      db.user!.addAll(body);
      return BackendResponse(200, db.user);
    }),
    MockRoute('DELETE', '/me', (_, _) async {
      db.reset();
      return const BackendResponse(204, null);
    }),
    MockRoute('GET', '/me/stats', (_, _) async {
      await seedMockActivity(db, fixtures);
      return BackendResponse(200, mockStats(db));
    }),
    MockRoute('GET', '/me/activity', (request, _) async {
      await seedMockActivity(db, fixtures);
      final from = request.query['from'], to = request.query['to'];
      DateTime? start, end;
      try {
        start = from == null ? null : DateTime.parse(from.toString());
        end = to == null ? null : DateTime.parse(to.toString());
      } catch (_) {
        return invalid('range');
      }
      final last = end ?? mockDay(db), first = start ?? last.subtract(const Duration(days: 34));
      if (first.isAfter(last) || last.difference(first).inDays >= 62) return invalid('range');
      return BackendResponse(200, mockActivity(db, from: first, to: last));
    }),
    MockRoute('GET', '/glossary', (request, _) async {
      // TODO(contract): A-44 — seed the supplied page, then overlay encountered session terms and authoritative states.
      final page = await fixtures.example('Page[TermCard]');
      final terms = <String, Map<String, dynamic>>{
        for (final item in (page['items'] as List).cast<Map<String, dynamic>>()) item['term_id'] as String: item,
      };
      for (final session in db.sessions.values) {
        for (final item in (session['terms'] as Map).values.cast<Map<String, dynamic>>()) {
          terms[item['term_id'] as String] = Map<String, dynamic>.from(item);
        }
      }
      for (final item in terms.values) {
        item['state'] = db.termStates[item['term_id']] ?? item['state'];
      }
      final state = request.query['state'] ?? 'all';
      if (!['all', 'new', 'learning', 'mastered'].contains(state)) return invalid('state');
      final rows = terms.values.where((t) => state == 'all' || t['state'] == state).toList();
      final limit = int.tryParse('${request.query['limit'] ?? 20}');
      if (limit == null || limit < 1 || limit > 100) return invalid('limit');
      final cursor = request.query['cursor'];
      final offset = cursor == null ? 0 : int.tryParse(cursor.toString().replaceFirst('preview_', ''));
      if (offset == null || offset < 0 || offset > rows.length) return invalid('cursor');
      final end = (offset + limit).clamp(0, rows.length);
      return BackendResponse(200, {'items': rows.sublist(offset, end), 'next_cursor': end < rows.length ? 'preview_$end' : null});
    }),
    for (final route in {'/me/achievements': 'Achievements', '/me/concepts': 'Page[ConceptRow]'}.entries)
      MockRoute('GET', route.key, (_, _) async => BackendResponse(200, await fixtures.example(route.value))),
  ]);
}
