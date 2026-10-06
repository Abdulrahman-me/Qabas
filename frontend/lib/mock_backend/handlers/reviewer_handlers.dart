import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/features/reviewer/data/reviewer_dtos.dart';
import 'package:qabas/features/reviewer/domain/reviewer_validation.dart';
import 'package:qabas/mock_backend/controls/mock_controls.dart';
import 'package:qabas/mock_backend/data/mock_state_store.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_db.dart';
import 'package:qabas/mock_backend/mock_router.dart';
import 'package:uuid/uuid.dart';

/// Fixture-only coordinator. Keeps authored blockers and media placeholders intact.
void registerReviewer(MockRouter router, MockDb db, Fixtures fixtures, MockControls controls) {
  final runs = <String, Map<String, dynamic>>{};
  final pending = <String>{}, pendingPlan = <String>{};
  final answered = <String>{};
  final attempts = <String, int>{};
  final lockedUntil = <String, DateTime>{};
  var resetEpoch = controls.reviewerReset;
  void syncReset() {
    if (resetEpoch == controls.reviewerReset) return;
    resetEpoch = controls.reviewerReset;
    runs.clear();
    pending.clear();
    pendingPlan.clear();
    answered.clear();
    attempts.clear();
    lockedUntil.clear();
  }

  Object? canonical(Object? v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: canonical(v[k])};
    }
    if (v is List) return v.map(canonical).toList();
    return v;
  }

  void digest(Map<String, dynamic> r) {
    final g = r['status'];
    r['review_digest'] = ['awaiting_gate1', 'awaiting_gate2'].contains(g)
        ? sha256
              .convert(
                utf8.encode(
                  jsonEncode(
                    canonical(
                      g == 'awaiting_gate1'
                          ? {'gate': 'gate1', 'run_id': r['run_id'], 'plan': r['plan']}
                          : {'gate': 'gate2', 'run_id': r['run_id'], 'draft': r['draft'], 'qa_report': r['qa_report']},
                    ),
                  ),
                ),
              )
              .toString()
        : null;
  }

  Future<void> seed() async {
    syncReset();
    if (runs.isNotEmpty) return;
    for (final path in ['reviewer/u0l1.factory_run.json', 'reviewer/u1l1.factory_run.json']) {
      final r = await fixtures.object(path);
      runs[r['run_id'] as String] = r;
    }
    final example = await fixtures.example('FactoryRun');
    runs[example['run_id'] as String] = example;
    if (fixtures.recording) {
      for (final path in ['recording/factory_run.json', 'recording/factory_plan.json']) {
        final sample = await fixtures.object(path);
        digest(sample);
        runs[sample['run_id'] as String] = sample;
      }
    }
  }

  BackendResponse invalid(String message, [Map<String, Object?> details = const {}]) =>
      BackendResponse.error(400, 'validation_error', message, details);
  Future<BackendResponse> withRun(Map<String, String> params, Future<BackendResponse> Function(Map<String, dynamic>) f) async {
    await seed();
    final r = runs[params['run_id']];
    return r == null ? BackendResponse.error(404, 'not_found', 'Run not found') : f(r);
  }

  router.routes.addAll([
    MockRoute('POST', '/auth/reviewer', (req, _) async {
      final b = req.body;
      if (b is! Map<String, dynamic> ||
          b.keys.any((k) => !['email', 'password'].contains(k)) ||
          b['email'] is! String ||
          b['password'] is! String) {
        return invalid('Email and password required');
      }
      final email = b['email'] as String, password = b['password'] as String;
      if (lockedUntil[email]?.isAfter(DateTime.now()) == true) {
        return BackendResponse.error(429, 'rate_limited', 'Sign-in temporarily locked', {
          'retry_after_ms': lockedUntil[email]!.difference(DateTime.now()).inMilliseconds,
        });
      }
      // TODO(contract): A-52 — dev/demo credential only; no password is shipped to production.
      if (email != 'reviewer@qabas.app' || password != 'qabas-review') {
        attempts[email] = (attempts[email] ?? 0) + 1;
        if (attempts[email]! >= 5) {
          lockedUntil[email] = DateTime.now().add(const Duration(minutes: 15));
          return BackendResponse.error(429, 'rate_limited', 'Sign-in temporarily locked', {'retry_after_ms': 900000});
        }
        return BackendResponse.error(401, 'unauthorized', 'Invalid credentials');
      }
      attempts.remove(email);
      lockedUntil.remove(email);
      final auth = await fixtures.object('examples/AuthResp__post_auth_reviewer__1.json');
      final token = 'mock_reviewer_${const Uuid().v4()}';
      auth['access_token'] = token;
      // Switching identity invalidates the old session while preserving reviewer coordinator state.
      // TODO(contract): A-54 — preserve a token-free learner snapshot only for recording retakes.
      final learner = fixtures.recording && db.user?['role'] == 'learner'
          ? jsonDecode(jsonEncode(MockStateStore.snapshotOf(db))) as Map<String, dynamic>
          : db.suspendedLearner;
      db.reset();
      if (fixtures.recording) db.suspendedLearner = learner;
      db.user = auth['user'] as Map<String, dynamic>;
      db.reviewerExpiresAt = db.now().add(const Duration(hours: 12));
      db.tokens.add(token);
      return BackendResponse(200, auth);
    }),
    MockRoute('GET', '/admin/factory/runs', (req, _) async {
      await seed();
      final status = req.query['status'];
      if (status != null && !['running', 'awaiting_gate1', 'awaiting_gate2', 'published', 'rejected', 'failed'].contains(status)) {
        return invalid('Invalid status');
      }
      final rows = runs.values.where((r) => status == null || r['status'] == status).toList();
      final cursor = req.query['cursor'];
      final offset = cursor == null ? 0 : int.tryParse(cursor.toString().replaceFirst('review_', ''));
      final limit = int.tryParse('${req.query['limit'] ?? 20}');
      if (offset == null || offset < 0 || offset > rows.length || limit == null || limit < 1 || limit > 100) {
        return invalid('Invalid pagination');
      }
      final end = (offset + limit).clamp(0, rows.length);
      return BackendResponse(200, {
        'items': rows
            .sublist(offset, end)
            .map(
              (r) => {
                'run_id': r['run_id'],
                'unit_id': r['unit_id'],
                'lesson_type': r['lesson_type'],
                'title': ((r['plan'] as Map?)?['title'] as Map?)?[req.header('Accept-Language') ?? 'en'],
                'status': r['status'],
                'stage': r['stage'],
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
            )
            .toList(),
        'next_cursor': end < rows.length ? 'review_$end' : null,
      });
    }),
    MockRoute('POST', '/admin/factory/runs', (req, _) async {
      await seed();
      final b = req.body;
      if (b is! Map<String, dynamic> ||
          b.keys.any((k) => !['unit_id', 'lesson_type', 'brief', 'position_index'].contains(k)) ||
          b['unit_id'] is! String ||
          !['concept', 'story', 'practice'].contains(b['lesson_type']) ||
          b['brief'] is! String ||
          (b['brief'] as String).trim().isEmpty ||
          b['position_index'] is! int ||
          (b['position_index'] as int) < 0) {
        return invalid('Invalid run request');
      }
      final r = await fixtures.object(
        fixtures.recording ? 'recording/factory_plan.json' : 'examples/FactoryRun__get_admin_factory_runs_run_id_factoryrun__0.json',
      );
      final id = 'run_${const Uuid().v4()}';
      r.addAll({'run_id': id, 'unit_id': b['unit_id'], 'lesson_type': b['lesson_type'], 'brief': b['brief']});
      (r['plan'] as Map)['lesson_type'] = b['lesson_type'];
      r['status'] = 'running';
      r['stage'] = 'plan';
      digest(r);
      pendingPlan.add(id);
      runs[id] = r;
      return BackendResponse(201, r);
    }),
    MockRoute(
      'GET',
      '/admin/factory/runs/{run_id}',
      (req, p) => withRun(p, (r) async {
        if (pendingPlan.remove(r['run_id'])) {
          r['status'] = 'awaiting_gate1';
          r['stage'] = 'plan';
          digest(r);
        }
        if (pending.remove(r['run_id'])) {
          r['status'] = 'awaiting_gate2';
          r['stage'] = 'qa';
          digest(r);
        }
        return BackendResponse(200, r);
      }),
    ),
    for (final gate in ['gate1', 'gate2'])
      MockRoute(
        'POST',
        '/admin/factory/runs/{run_id}/$gate',
        (req, p) => withRun(p, (r) async {
          final b = req.body;
          if (b is! Map<String, dynamic>) return invalid('Invalid gate request');
          if (r['status'] != 'awaiting_$gate') return BackendResponse.error(409, 'run_not_at_gate', 'Run is no longer at this gate');
          if (controls.reviewStale) {
            controls.reviewStale = false;
            if (gate == 'gate1') {
              (r['plan'] as Map)['content_budget'] = ((r['plan'] as Map)['content_budget'] as int) + 1;
            } else {
              ((r['qa_report'] as Map)['issues'] as List).add({
                'severity': 'info',
                'kind': 'validation',
                'location': {'sentence_id': null, 'exercise_id': null, 'scene_id': null},
                'message': 'A newer QA review is available.',
              });
            }
            digest(r);
          }
          if (b['review_digest'] != r['review_digest']) return BackendResponse.error(409, 'review_stale', 'Review has changed');
          final decision = b['decision'];
          if (!(gate == 'gate1' ? ['approve', 'reject'] : ['approve', 'request_changes', 'reject']).contains(decision)) {
            return invalid('Invalid decision');
          }
          if (gate == 'gate1' && decision == 'reject' && b['plan'] != null) return invalid('Edited plans are only accepted with approve');
          if (gate == 'gate1' && decision == 'approve' && b['plan'] != null) {
            try {
              if (!validReviewPlan(ReviewLessonPlanDto.fromJson(Map<String, dynamic>.from(b['plan'] as Map)).toEntity())) {
                return invalid('Invalid lesson plan');
              }
            } catch (_) {
              return invalid('Invalid lesson plan');
            }
          }
          if (gate == 'gate2') {
            final edits = b['sentence_edits'], removals = b['exercise_removals'];
            if (edits is! List || removals is! List) return invalid('Edits and removals required');
            if (decision != 'approve' && (edits.isNotEmpty || removals.isNotEmpty)) return invalid('Edits are only accepted with approve');
            if (decision == 'request_changes' && (b['reason'] is! String || (b['reason'] as String).trim().isEmpty)) {
              return invalid('Reason required');
            }
            for (final e in edits) {
              if (e is! Map || e['new_text'] is! String || (e['new_text'] as String).trim().isEmpty) return invalid('Invalid edit');
              if (e['language'] == 'ar' &&
                  !edits.any(
                    (v) => v is Map && v['sentence_id'] == e['sentence_id'] && v['variant'] == e['variant'] && v['language'] == 'en',
                  )) {
                return invalid('Arabic sentence edits require their English pair');
              }
            }
            if (decision == 'approve') {
              final issues = ((r['qa_report'] as Map)['issues'] as List).where((v) => (v as Map)['severity'] == 'blocker').toList();
              if (issues.isNotEmpty) return invalid('Blockers remain', {'issues': issues});
              final placeholderIssues = reviewerPlaceholderIssues(r['draft']);
              if (placeholderIssues.isNotEmpty) {
                return invalid('Publication requires audited, published media', {'issues': placeholderIssues});
              }
            }
          }
          if (decision == 'reject') {
            r['status'] = 'rejected';
          } else if (gate == 'gate2' && decision == 'approve') {
            r['status'] = 'published';
            r['published'] = {'lesson_id': 'les_${r['run_id']}', 'version': 1};
          } else {
            if (gate == 'gate1') {
              if (b['plan'] != null) r['plan'] = b['plan'];
              final fragment = fixtures.recording && (r['run_id'] != 'run_42')
                  ? await fixtures.object('recording/factory_run.json')
                  : await fixtures.example('DraftFragment');
              r['draft'] = fragment['draft'];
              r['qa_report'] = fragment['qa_report'];
            }
            r['status'] = 'running';
            r['stage'] = gate == 'gate1' ? 'decompose' : 'write';
            pending.add(r['run_id'] as String);
          }
          digest(r);
          return BackendResponse(200, r);
        }),
      ),
    MockRoute(
      'POST',
      '/admin/factory/runs/{run_id}/images/{scene_id}/regenerate',
      (req, p) => withRun(p, (r) async {
        if (r['status'] != 'awaiting_gate2') return BackendResponse.error(409, 'run_not_at_gate', 'Run is not at Gate 2');
        final visuals = ((r['draft'] as Map)['visuals'] as List).cast<Map>();
        final visual = visuals.where((v) => v['scene_id'] == p['scene_id']).firstOrNull;
        if (visual == null) return BackendResponse.error(404, 'not_found', 'Visual not found');
        if (visual['origin'] == 'builtin') return invalid('Built-in visuals cannot be regenerated');
        // TODO(contract): A-53 — accepted mock regeneration retains placeholders and all blockers.
        visual['attempts'] = (visual['attempts'] as int) + 1;
        r['status'] = 'running';
        r['stage'] = visual['origin'] == 'generated_scene' ? 'scene_author' : 'visuals';
        digest(r);
        pending.add(r['run_id'] as String);
        return const BackendResponse(202, null);
      }),
    ),
    MockRoute('GET', '/admin/blind-test/next', (req, _) async {
      syncReset();
      final pairs = fixtures.recording
          ? (await fixtures.load('recording/blind_${req.header('Accept-Language') ?? 'en'}.json') as List).cast<Map<String, dynamic>>()
          : [await fixtures.example('BlindPair')];
      final pair = pairs.where((p) => !answered.contains(p['pair_id'])).firstOrNull;
      return pair == null ? const BackendResponse(204, null) : BackendResponse(200, pair);
    }),
    MockRoute('POST', '/admin/blind-test/{pair_id}', (req, p) async {
      final b = req.body;
      if (b is! Map ||
          !['a', 'b', 'same'].contains(b['clearer']) ||
          !['a', 'b', 'same'].contains(b['more_accurate']) ||
          !['a', 'b', 'unsure'].contains(b['guessed_handwritten'])) {
        return invalid('All three answers are required');
      }
      syncReset();
      final pairs = fixtures.recording
          ? (await fixtures.load('recording/blind_en.json') as List).cast<Map<String, dynamic>>()
          : [await fixtures.example('BlindPair')];
      if (!pairs.any((pair) => p['pair_id'] == pair['pair_id'])) return BackendResponse.error(404, 'not_found', 'Pair not found');
      answered.add(p['pair_id']!);
      return const BackendResponse(204, null);
    }),
    MockRoute('GET', '/admin/metrics', (req, _) async => BackendResponse(200, await fixtures.example('Metrics'))),
  ]);
}

List<Map<String, Object?>> reviewerPlaceholderIssues(Object? payload) {
  final findings = <Map<String, Object?>>[];
  final reserved = RegExp(r'(^|\.)(example\.(com|net|org)|localhost)$|\.(example|test|invalid|localhost)$');
  void visit(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key as String;
        final child = entry.value;
        if (child is String && (key == 'url' || key.endsWith('_url'))) {
          final uri = Uri.tryParse(child);
          if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || reserved.hasMatch(uri.host)) {
            findings.add({
              'severity': 'blocker',
              'kind': 'validation',
              'location': {'sentence_id': null, 'exercise_id': null, 'scene_id': null},
              'message': 'The draft includes placeholder or unpublished media.',
            });
          }
        } else {
          visit(child);
        }
      }
    } else if (value is List) {
      for (final child in value) {
        visit(child);
      }
    }
  }

  visit(payload);
  return findings;
}
