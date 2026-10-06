import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_blind_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_dashboard_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_metrics_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_page.dart';

import 'support/tour_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Phase 14 reviewer native $language/$reduced', (t) async {
        final h = await TourHarness.fresh(t, binding, language, reduced, onboarded: true, group: 'reviewer', phase: 'phase14');
        Future<void> shot(String name) async {
          await h.wait();
          // Reviewer fixtures intentionally show their verbatim QA/placeholder text.
          await binding.takeScreenshot('phase14/${h.prefix}/$name');
        }

        await h.until(() => find.byType(JourneyPage).evaluate().isNotEmpty);
        final router = GoRouter.of(t.element(find.byType(JourneyPage)));
        router.go('/reviewer/login');
        await h.wait();
        await t.enterText(find.byKey(const ValueKey('reviewer-email')), 'reviewer@qabas.app');
        await t.enterText(find.byKey(const ValueKey('reviewer-password')), 'qabas-review');
        FocusManager.instance.primaryFocus?.unfocus();
        await h.wait();
        await shot('R1_sign_in');
        await t.ensureVisible(find.byKey(const ValueKey('reviewer-sign-in')));
        await h.tapFinder(find.byKey(const ValueKey('reviewer-sign-in')));
        await h.until(() => find.byType(ReviewerRunsPage).evaluate().isNotEmpty);
        await h.d.locale.languageChanged(language);
        await h.wait();
        final runs = t.element(find.byType(ReviewerRunsPage)).read<ReviewerRunsBloc>();
        await h.until(() => runs.state.status == ReviewerStatus.ready);
        await shot('R2_runs');
        router.go('/reviewer/runs/${runs.state.items.firstWhere((r) => r.status == 'awaiting_gate2').runId}');
        await h.until(() => find.byType(ReviewerDetailPage).evaluate().isNotEmpty);
        final detail = t.element(find.byType(ReviewerDetailPage)).read<ReviewerDetailBloc>();
        await h.until(() => detail.state.status == ReviewerStatus.ready);
        expect(detail.state.canApprove, false);
        await shot('R4_draft');
        final c = t.element(find.byType(ReviewerDetailPage));
        for (final label in [
          c.l10n.reviewerEvidence,
          c.l10n.reviewerArcMap,
          c.l10n.reviewerExercises,
          c.l10n.reviewerQA,
          c.l10n.reviewerVisuals,
        ]) {
          final scrollable = find.descendant(of: find.byType(ReviewerDetailPage), matching: find.byType(Scrollable)).first;
          t.state<ScrollableState>(scrollable).position.jumpTo(0);
          await h.wait();
          debugPrint('REVIEWER_NATIVE:PANEL $label');
          final title = find.descendant(of: find.widgetWithText(ExpansionTile, label), matching: find.text(label));
          for (var i = 0; i < 150 && title.evaluate().isEmpty; i++) {
            final position = t.state<ScrollableState>(scrollable).position;
            position.jumpTo((position.pixels + 300).clamp(0, position.maxScrollExtent));
            await h.wait(100);
          }
          expect(title, findsOneWidget, reason: label);
          await t.ensureVisible(title);
          await h.wait();
          await h.tapFinder(title);
          await shot(
            'R4_panel_${[c.l10n.reviewerEvidence, c.l10n.reviewerArcMap, c.l10n.reviewerExercises, c.l10n.reviewerQA, c.l10n.reviewerVisuals].indexOf(label)}',
          );
          await t.ensureVisible(title);
          await h.tapFinder(title);
        }
        detail.add(const SentencePairEdited('sen_u0l1_01', 'تعديل', ''));
        await h.wait();
        expect(detail.state.issue, ReviewActionIssue.pairedEnglish);
        h.mock.controls.reviewStale = true;
        detail.add(const ReviewReasonEdited('Review the visual blockers'));
        detail.add(const GateDecisionSubmitted('request_changes'));
        await h.until(() => detail.state.stale);
        detail.add(const ReviewReconfirmed());
        detail.add(const GateDecisionSubmitted('reject'));
        await h.until(() => detail.state.run?.status == 'rejected');
        router.go('/reviewer/runs/run_42');
        await h.wait();
        final gate = t.element(find.byType(ReviewerDetailPage)).read<ReviewerDetailBloc>();
        await h.until(() => gate.state.status == ReviewerStatus.ready);
        gate.add(PlanEdited(gate.state.plan!.copyWith(estimatedMinutes: 9)));
        await h.wait();
        await shot('R3_plan');
        gate.add(const GateDecisionSubmitted('approve'));
        await h.until(() => gate.state.run?.status == 'awaiting_gate2');
        router.go('/reviewer/blind');
        await h.until(() => find.byType(ReviewerBlindPage).evaluate().isNotEmpty);
        final blind = t.element(find.byType(ReviewerBlindPage)).read<ReviewerBlindBloc>();
        await h.until(() => blind.state.status == ReviewerStatus.ready);
        await shot('R5_blind');
        for (var i = 0; i < 3; i++) {
          blind.add(BlindChoicePicked(i, i == 2 ? 'unsure' : 'same'));
        }
        blind.add(const BlindAnswerSubmitted());
        await h.until(() => blind.state.pair == null && blind.state.status == ReviewerStatus.ready);
        await shot('R5_empty');
        router.go('/reviewer/metrics');
        await h.until(() => find.byType(ReviewerMetricsPage).evaluate().isNotEmpty);
        final metrics = t.element(find.byType(ReviewerMetricsPage)).read<ReviewerMetricsBloc>();
        await h.until(() => metrics.state.status == ReviewerStatus.ready);
        await shot('R6_metrics');
      });
    }
  }
}
