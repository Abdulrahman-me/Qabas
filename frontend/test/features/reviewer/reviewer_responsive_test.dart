import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_auth_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_blind_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_dashboard_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_metrics_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_shell.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/lesson/presentation/lesson_preview.dart';
import 'package:qabas/shared/lesson/presentation/steps/content_step_bloc.dart';
import '../journey/journey_responsive_test.dart' show mountJourney, pumpJourney, journeyUntil, journeySizes, press;

void noRewards(WidgetTester t) {
  final scope = find.byType(ReviewerShell);
  expect(find.descendant(skipOffstage: false, of: scope, matching: find.byType(CharacterView)), findsNothing);
  for (final name in ['FlameMark', 'EmberIcon', 'StreakFlame', 'EmberBurst', 'TravelerAvatar', 'FeedbackPanel', 'ProgressTrack']) {
    expect(
      find.descendant(skipOffstage: false, of: scope, matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == name)),
      findsNothing,
      reason: name,
    );
  }
}

void main() {
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Reviewer complete mounted resize and no reward chrome $language/$reduced', (t) async {
        const timezoneChannel = MethodChannel('flutter_timezone');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(timezoneChannel, (_) async => 'UTC');
        addTearDown(
          () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(timezoneChannel, null),
        );
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(402, 874);
        t.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mountJourney(t, locale: language, reduced: reduced);
        debugPrint('REVIEWER:MOUNTED');
        final mock = d.services<MockBackend>();
        await t.runAsync(() async {
          for (final path in [
            'reviewer/u0l1.factory_run.json',
            'reviewer/u1l1.factory_run.json',
            'examples/AuthResp__post_auth_reviewer__1.json',
          ]) {
            await mock.fixtures.object(path);
          }
          for (final model in ['FactoryRun', 'DraftFragment', 'BlindPair', 'Metrics']) {
            await mock.fixtures.example(model);
          }
        });
        final router = GoRouter.of(t.element(find.byKey(const ValueKey('nav-0'))));
        router.go('/reviewer/runs');
        await pumpJourney(t);
        expect(find.byType(ReviewerShell), findsNothing);
        debugPrint('REVIEWER:LOGIN');
        router.go('/reviewer/login');
        await pumpJourney(t);
        await t.enterText(find.byKey(const ValueKey('reviewer-email')), 'reviewer@qabas.app');
        await t.enterText(find.byKey(const ValueKey('reviewer-password')), 'qabas-review');
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull, reason: 'login $size');
          expect(find.text('reviewer@qabas.app'), findsOneWidget);
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await pumpJourney(t);
        await t.ensureVisible(find.byKey(const ValueKey('reviewer-sign-in')));
        await pumpJourney(t);
        await press(t, find.byKey(const ValueKey('reviewer-sign-in')));
        await journeyUntil(t, () => find.byType(ReviewerRunsPage).evaluate().isNotEmpty);
        debugPrint('REVIEWER:LOCALE');
        await d.locale.languageChanged(language);
        await pumpJourney(t);
        final runs = t.element(find.byType(ReviewerRunsPage)).read<ReviewerRunsBloc>();
        await journeyUntil(t, () => runs.state.status == ReviewerStatus.ready);
        expect(runs.state.items.length, 3);
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull, reason: 'runs $size');
          noRewards(t);
        }
        router.go('/reviewer/runs/run_test_u0l1');
        await pumpJourney(t);
        final detail = t.element(find.byType(ReviewerDetailPage)).read<ReviewerDetailBloc>();
        await journeyUntil(t, () => detail.state.status == ReviewerStatus.ready);
        expect(detail.state.hasBlockers, true);
        expect(find.byType(CharacterView), findsNothing);
        final previewFinder = find.byType(BlocBuilder<LessonPreviewBloc, PreviewState>);
        final previews = [for (final e in previewFinder.evaluate()) e.read<LessonPreviewBloc>()];
        expect(previews.length, 2);
        for (final preview in previews) {
          preview.add(const PreviewItemChanged(1));
        }
        await t.pump();
        detail.add(const ReviewReasonEdited('Needs an audited visual'));
        detail.add(const SentencePairEdited('sen_u0l1_01', 'تعديل', ''));
        await t.pump();
        expect(detail.state.issue, ReviewActionIssue.pairedEnglish);
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull, reason: 'draft $size');
          expect(t.element(find.byType(ReviewerDetailPage)).read<ReviewerDetailBloc>(), same(detail));
          expect(detail.state.reason, 'Needs an audited visual');
          final resized = [for (final e in previewFinder.evaluate()) e.read<LessonPreviewBloc>()];
          if (resized.isNotEmpty) expect(resized, previews);
          expect(previews.every((p) => !p.isClosed && p.state.cursor == 1), true);
          noRewards(t);
        }
        // Inspect every shared content/exercise renderer, including revealed teach bullets and scenario chrome.
        for (var block = 1; block < previews.first.items.length; block++) {
          for (final preview in previews) {
            if (preview.state.cursor != block) preview.add(PreviewItemChanged(block - preview.state.cursor));
          }
          await t.pump();
          for (var reveal = 0; reveal < 6; reveal++) {
            for (final element in find.byType(BlocBuilder<ContentStepBloc, ContentStepState>, skipOffstage: false).evaluate()) {
              element.read<ContentStepBloc>().add(const CtaPressed());
            }
            await t.pump();
          }
          expect(t.takeException(), isNull, reason: 'preview block $block');
          noRewards(t);
        }
        final context = t.element(find.byType(ReviewerDetailPage));
        // Mount each review panel, then inspect the whole subtree for forbidden widgets.
        for (final label in [
          context.l10n.reviewerEvidence,
          context.l10n.reviewerArcMap,
          context.l10n.reviewerExercises,
          context.l10n.reviewerQA,
          context.l10n.reviewerVisuals,
        ]) {
          debugPrint('REVIEWER:PANEL $label');
          final finder = find.descendant(of: find.widgetWithText(ExpansionTile, label), matching: find.text(label));
          final scrollable = find.descendant(of: find.byType(ReviewerDetailPage), matching: find.byType(Scrollable)).first;
          t.state<ScrollableState>(scrollable).position.jumpTo(0);
          await t.pump();
          await t.scrollUntilVisible(finder, 300, scrollable: scrollable, maxScrolls: 150);
          await pumpJourney(t);
          await t.tap(finder);
          await pumpJourney(t);
          expect(t.takeException(), isNull, reason: label);
          noRewards(t);
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump();
            expect(t.takeException(), isNull, reason: '$label $size');
          }

          t.state<ScrollableState>(scrollable).position.jumpTo(0);
          await t.pump();
          await t.scrollUntilVisible(finder, 300, scrollable: scrollable, maxScrolls: 150);
          await pumpJourney(t);
          await t.tap(finder);
          await pumpJourney(t);
        }
        debugPrint('REVIEWER:STALE');
        mock.controls.reviewStale = true;
        detail.add(const GateDecisionSubmitted('request_changes'));
        await journeyUntil(t, () => detail.state.stale);
        expect(detail.state.canApprove, false);
        noRewards(t);
        router.go('/reviewer/runs/run_42');
        await pumpJourney(t);
        final plan = t.element(find.byType(ReviewerDetailPage)).read<ReviewerDetailBloc>();
        await journeyUntil(t, () => plan.state.status == ReviewerStatus.ready);
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull, reason: 'plan $size');
          noRewards(t);
        }
        debugPrint('REVIEWER:BLIND');
        router.go('/reviewer/blind');
        await pumpJourney(t);
        final blind = t.element(find.byType(ReviewerBlindPage)).read<ReviewerBlindBloc>();
        await journeyUntil(t, () => blind.state.status == ReviewerStatus.ready);
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull, reason: 'blind $size');
          noRewards(t);
        }
        for (var i = 0; i < 3; i++) {
          blind.add(BlindChoicePicked(i, i == 2 ? 'unsure' : 'same'));
        }
        blind.add(const BlindAnswerSubmitted());
        await journeyUntil(t, () => blind.state.pair == null && blind.state.status == ReviewerStatus.ready);
        expect(find.byType(QEmptyView), findsOneWidget);
        noRewards(t);
        debugPrint('REVIEWER:METRICS');
        router.go('/reviewer/metrics');
        await pumpJourney(t);
        final metrics = t.element(find.byType(ReviewerMetricsPage)).read<ReviewerMetricsBloc>();
        await journeyUntil(t, () => metrics.state.status == ReviewerStatus.ready);
        final snapshot = metrics.state.metrics;
        final mc = t.element(find.byType(ReviewerMetricsPage));
        final activated = find.ancestor(of: find.text(mc.l10n.reviewerActivated), matching: find.byType(QCard)).first;
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(metrics.state.metrics, same(snapshot));
          final rect = t.getRect(activated);
          expect(rect.width, greaterThanOrEqualTo(size.width == 320 ? size.width - QSpace.page * 2 : QReviewer.metricMinWidth));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(find.text(mc.l10n.reviewerPercentageNumber(mc.n(74))), findsOneWidget);
          expect(find.byType(AppBar), findsOneWidget, reason: 'one reviewer toolbar');
          expect(t.takeException(), isNull, reason: 'metrics $size');
          noRewards(t);
        }
        mock.controls.offline = true;
        metrics.add(const MetricsOpened());
        await journeyUntil(t, () => metrics.state.status == ReviewerStatus.failure);
        noRewards(t);
        mock.controls.offline = false;
        metrics.add(const MetricsOpened());
        await journeyUntil(t, () => metrics.state.status == ReviewerStatus.ready);
        debugPrint('REVIEWER:SIGNOUT');
        // The shell sign-out is an actual secure-store operation and guest bootstrap.
        // Platform audio is outside this widget harness; avoid native warm-up after guest bootstrap.
        await t.runAsync(d.sensory.dispose);
        debugPrint('REVIEWER:AUDIO DISPOSED');
        t.element(find.byType(ReviewerShell)).read<ReviewerAuthBloc>().add(const ReviewerSignedOut());
        await pumpJourney(t);
        expect(find.byType(ReviewerShell), findsNothing);
        debugPrint('REVIEWER:SIGNED OUT');
        await journeyUntil(t, () => d.session.state.status == SessionStatus.needsOnboarding);
        debugPrint('REVIEWER:GUEST READY');
        await t.pump(const Duration(seconds: 5));
        await pumpJourney(t);
        await t.pumpWidget(const SizedBox());
        await pumpJourney(t);
        debugPrint('REVIEWER:DISPOSING');
        await t.runAsync(d.dispose);
        debugPrint('REVIEWER:DISPOSED');
      });
    }
  }
}
