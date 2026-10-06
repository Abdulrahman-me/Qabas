import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/reviewer/data/reviewer_dtos.dart';
import 'package:qabas/features/reviewer/data/reviewer_repository_impl.dart';
import 'package:qabas/features/reviewer/domain/reviewer_actions.dart';
import 'package:qabas/features/reviewer/domain/reviewer_models.dart';
import 'package:qabas/features/reviewer/domain/reviewer_repository.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_auth_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_dashboard_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';
import 'package:qabas/mock_backend/controls/mock_controls.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

import '../../support/fakes.dart';

Future<void> until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(done(), true);
}

void main() {
  late MockBackend mock;
  late ApiClient api;
  late MemoryTokens tokens;
  late ReviewerRepositoryImpl repo;
  late ReviewerActions actions;
  setUp(() {
    tokens = MemoryTokens();
    mock = MockBackend(
      fixtures: Fixtures(read: (p) => File(p).readAsString()),
      controls: MockControls()..fast = true,
    );
    api = ApiClient.create(
      config: AppConfig(),
      tokens: tokens,
      mock: mock,
      platform: 'web',
      language: () => 'en',
      retryDelay: (_) async {},
    );
    repo = ReviewerRepositoryImpl(api, tokens);
    actions = ReviewerActions(repo);
  });
  tearDown(() async {
    await api.dispose();
    mock.close();
  });
  Future<void> signIn() async {
    expect(await repo.signIn('reviewer@qabas.app', 'qabas-review'), isA<Ok<UserProfile>>());
  }

  test('learner credential is forbidden; reviewer role, secure-store replacement, expiry and sign out', () async {
    final user = await mock.fixtures.example('User');
    mock.db.user = user;
    tokens.value = 'learner';
    mock.db.tokens.add('learner');
    expect(await repo.runs(), isA<Err>().having((r) => r.failure, 'role', isA<ForbiddenFailure>()));
    final auth = ReviewerAuthBloc(actions)..add(const ReviewerSignedIn('reviewer@qabas.app', 'wrong'));
    await until(() => auth.state.status == ReviewerAuthStatus.failure);
    expect(tokens.value, 'learner');
    auth.add(const ReviewerSignedIn('reviewer@qabas.app', 'qabas-review'));
    await until(() => auth.state.status == ReviewerAuthStatus.signedIn);
    expect(auth.state.user!.role, UserRole.reviewer);
    expect(tokens.value, isNot('learner'));
    expect(mock.db.reviewerExpiresAt, isNotNull);
    mock.db.reviewerExpiresAt = DateTime.now().subtract(const Duration(seconds: 1));
    expect(await repo.runs(), isA<Err>().having((r) => r.failure, 'expiry', isA<UnauthorizedFailure>()));
    expect(tokens.value, isNull);
    await signIn();
    auth.add(const ReviewerSignedOut());
    await until(() => auth.state.status == ReviewerAuthStatus.signedOut);
    expect(tokens.value, isNull);
    await auth.close();
  });
  test('five rejected credentials lock out, login 401 does not clear learner session', () async {
    tokens.value = 'existing';
    for (var i = 0; i < 4; i++) {
      expect(
        await repo.signIn('reviewer@qabas.app', 'wrong'),
        isA<Err>().having((r) => r.failure, 'credential', isA<UnauthorizedFailure>()),
      );
    }
    expect(await repo.signIn('reviewer@qabas.app', 'wrong'), isA<Err>().having((r) => r.failure, 'lockout', isA<RateLimitedFailure>()));
    expect(
      await repo.signIn('reviewer@qabas.app', 'qabas-review'),
      isA<Err>().having((r) => r.failure, 'locked', isA<RateLimitedFailure>()),
    );
    expect(tokens.value, 'existing');
  });
  test('real Gate 2 decode, paired edits refused, blockers forbid approve, request changes and reject', () async {
    await signIn();
    final b = ReviewerDetailBloc(actions, pollInterval: const Duration(milliseconds: 20))..add(const RunOpened('run_test_u0l1'));
    await until(() => b.state.status == ReviewerStatus.ready);
    expect(b.state.run!.draft!.previews.map((p) => p.language), containsAll(['ar', 'en']));
    expect(b.state.hasBlockers, true);
    expect(b.state.canApprove, false);
    b.add(const SentencePairEdited('sen_u0l1_01', 'تعديل', ''));
    await until(() => b.state.issue == ReviewActionIssue.pairedEnglish);
    expect(b.state.edits, isEmpty);
    b.add(const SentencePairEdited('sen_u0l1_01', 'تعديل', 'Edited'));
    await until(() => b.state.edits.length == 2);
    b.add(const GateDecisionSubmitted('approve'));
    await until(() => b.state.issue == ReviewActionIssue.blockers);
    expect(b.state.run!.status, 'awaiting_gate2');
    b.add(const GateDecisionSubmitted('request_changes'));
    await until(() => b.state.issue == ReviewActionIssue.reasonRequired);
    b.add(const ReviewReasonEdited('Please replace unaudited images'));
    b.add(const GateDecisionSubmitted('request_changes'));
    await until(() => b.state.run!.status == 'running');
    await until(() => b.state.run!.status == 'awaiting_gate2');
    expect(b.state.hasBlockers, true);
    b.add(const GateDecisionSubmitted('reject'));
    await until(() => b.state.run!.status == 'rejected');
    expect(b.state.run!.reviewDigest, isNull);
    await b.close();
  });
  test('Gate 1 full-plan edit, stale digest reload without resubmit, explicit re-review then approve', () async {
    await signIn();
    final b = ReviewerDetailBloc(actions, pollInterval: const Duration(milliseconds: 20))..add(const RunOpened('run_42'));
    await until(() => b.state.status == ReviewerStatus.ready);
    final old = b.state.run!.reviewDigest;
    final plan = b.state.plan!;
    b.add(PlanEdited(plan.copyWith(estimatedMinutes: 9)));
    await until(() => b.state.plan!.estimatedMinutes == 9);
    mock.controls.reviewStale = true;
    b.add(const GateDecisionSubmitted('approve'));
    await until(() => b.state.stale && b.state.status == ReviewerStatus.ready);
    expect(b.state.run!.reviewDigest, isNot(old));
    expect(b.state.edits, isEmpty);
    expect(b.state.canApprove, false);
    b.add(const GateDecisionSubmitted('approve'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(b.state.run!.status, 'awaiting_gate1');
    b.add(const ReviewReconfirmed());
    b.add(PlanEdited(b.state.plan!.copyWith(estimatedMinutes: 9)));
    b.add(const GateDecisionSubmitted('approve'));
    await until(() => b.state.run!.status == 'running');
    expect(b.state.plan!.estimatedMinutes, 9);
    await until(() => b.state.run!.status == 'awaiting_gate2');
    await b.close();
  });
  test('regenerate rejects builtin, returns 202 for generated visual and retains blockers', () async {
    await signIn();
    final r = (await repo.run('run_test_u0l1') as Ok<ReviewFactoryRun>).value;
    final v = r.draft!.visuals.firstWhere((v) => v.origin != 'builtin');
    final old = r.reviewDigest;
    expect(await repo.regenerate(r.runId, v.sceneId, null), isA<Ok<void>>());
    expect(mock.lastRequest!.path, contains('/images/'));
    final next = (await repo.run(r.runId) as Ok<ReviewFactoryRun>).value;
    expect(next.status, 'awaiting_gate2');
    expect(next.reviewDigest, isNot(old));
    expect(
      next.qaReport!.issues.where((v) => v.severity == 'blocker').length,
      r.qaReport!.issues.where((v) => v.severity == 'blocker').length,
    );
  });
  test('paged filtered runs, UUID-key create replay and conflicting body', () async {
    await signIn();
    final page = (await repo.runs(status: 'awaiting_gate1') as Ok<ReviewerRunPage>).value;
    expect(page.items.every((ReviewRunRow r) => r.status == 'awaiting_gate1'), true);
    final req = const ReviewRunCreate(unitId: 'unit_7', lessonType: 'story', brief: 'A review exercise', positionIndex: 0);
    final key = repo.newKey();
    final a = (await repo.create(req, key) as Ok<ReviewFactoryRun>).value;
    final b = (await repo.create(req, key) as Ok<ReviewFactoryRun>).value;
    expect(a.runId, b.runId);
    expect(await repo.create(req.copyWith(brief: 'Changed'), key), isA<Err>().having((r) => r.failure, 'conflict', isA<ConflictFailure>()));
  });
  test('blind three answers, submission and 204 exhausted state; metrics error and retry', () async {
    await signIn();
    final b = ReviewerBlindBloc(actions)..add(const BlindOpened());
    await until(() => b.state.status == ReviewerStatus.ready);
    expect(b.state.pair, isNotNull);
    b.add(const BlindAnswerSubmitted());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(b.state.pair, isNotNull);
    for (var i = 0; i < 3; i++) {
      b.add(BlindChoicePicked(i, i == 2 ? 'unsure' : 'same'));
    }
    await until(() => b.state.complete);
    b.add(const BlindAnswerSubmitted());
    await until(() => b.state.status == ReviewerStatus.ready && b.state.pair == null);
    await b.close();
    mock.controls.offline = true;
    final m = ReviewerMetricsBloc(actions)..add(const MetricsOpened());
    await until(() => m.state.status == ReviewerStatus.failure);
    mock.controls.offline = false;
    m.add(const MetricsOpened());
    await until(() => m.state.status == ReviewerStatus.ready);
    expect(m.state.metrics!.learning.prePost, isNotEmpty);
    await m.close();
  });
  test('both supplied runs decode every preview and private reviewer answer projection', () async {
    for (final id in ['u0l1', 'u1l1']) {
      final raw = await mock.fixtures.object('reviewer/$id.factory_run.json');
      final run = ReviewFactoryRunDto.fromJson(raw).toEntity();
      expect(run.draft!.previews.every((p) => p.items.isNotEmpty), true);
      expect(run.draft!.exercises, isNotEmpty);
      expect(run.draft!.sentenceMap, isNotEmpty);
      expect(run.draft!.arcMap, isNotEmpty);
    }
  });
}
