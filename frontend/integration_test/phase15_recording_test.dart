import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/features/challenges/domain/challenge.dart';
import 'package:qabas/features/challenges/presentation/challenge_bloc.dart';
import 'package:qabas/features/challenges/presentation/challenge_page.dart';
import 'package:qabas/features/community/presentation/community_bloc.dart';
import 'package:qabas/features/community/presentation/community_page.dart';
import 'package:qabas/features/dev_tools/presentation/pages/dev_tools_page.dart';
import 'package:qabas/features/discover/presentation/pages/discover_page.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'package:qabas/features/raqeeb/presentation/pages/raqeeb_page.dart';
import 'package:qabas/features/raqeeb/presentation/widgets/chat_widgets.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_auth_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_blind_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_dashboard_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_metrics_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_shell.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/shared/lesson/presentation/lesson_preview.dart';
import 'support/tour_harness.dart';
import 'tour_test.dart' as spine;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['en', 'ar']) {
    testWidgets('full recording rehearsal $language', (t) async {
      final base = await TourHarness.fresh(t, binding, language, language == 'ar', phase: 'phase15', group: 'recording');
      final h = RecordingHarness(base);
      expect(h.d.config.recordingDemo, true);
      await spine.onboarding(h, language);
      final router = GoRouter.of(t.element(find.byType(JourneyPage)));
      unawaited(router.push<void>('/lesson/les_u0_l1/intro'));
      await spine.begin(h);
      await h.shot('lesson_scene');
      await spine.play(h, reference: false);
      await spine.leaveResult(h, streak: true);
      router.go('/discover');
      await h.until(() => find.byType(DiscoverPage).evaluate().isNotEmpty);
      await h.tap('discover-les_u1_l1');
      await spine.begin(h);
      await h.shot('discover_illustration');
      await h.tap('player-close');
      await h.tap('leave-lesson');
      await spine.journeyReady(h);
      unawaited(router.push<void>('/review/session'));
      await h.until(() => find.byType(SessionPlayerPage).evaluate().isNotEmpty && h.player.state.status == PlayerStatus.playing);
      await h.shot('review_card_front');
      await h.tap('card-front');
      await h.shot('review_card_back');
      await h.tap('player-close');
      await h.tap('leave-lesson');
      await spine.journeyReady(h);
      router.go('/raqeeb');
      await h.until(() => find.byType(RaqeebPage).evaluate().isNotEmpty);
      for (var suggestion = 0; suggestion < 4; suggestion++) {
        if (suggestion > 0) await h.tap('raqeeb-new');
        final c = t.element(find.byType(RaqeebPage));
        final chat = c.read<RaqeebChatBloc>();
        await h.tapFinder(find.text(raqeebSuggestions(c)[suggestion]));
        await h.until(() => chat.state.turns.isNotEmpty && chat.state.turns.last.assistant is CompletedMessage);
        final list = t.widget<ListView>(find.byType(ListView));
        list.controller?.jumpTo(0);
        await h.shot('raqeeb_suggestion_$suggestion');
      }
      router.go('/community');
      await h.until(
        () =>
            find.byType(CommunityPage).evaluate().isNotEmpty &&
            t.element(find.byType(CommunityPage)).read<CommunityBloc>().state.league != null,
      );
      await h.shot('community');
      final script = (await h.mock.fixtures.load('recording/challenges_$language.json') as List).cast<Map<String, dynamic>>();
      final answers = [
        for (final e in script)
          if (e['type'] == 'question_result') (e['data'] as Map)['correct_answer'] as Map,
      ];
      for (final preset in ['duel', 'group']) {
        unawaited(router.push<void>(preset == 'duel' ? '/challenge/play?new=duel' : '/challenge/play?new=group&friends=usr_f1&fill=true'));
        await h.until(() => find.byType(ChallengePage).evaluate().isNotEmpty);
        final b = t.element(find.byType(ChallengePage)).read<ChallengeBloc>();
        var question = 0;
        while (b.state.phase != ChallengePhase.results && question < 8) {
          await h.until(() => b.state.phase == ChallengePhase.question || b.state.phase == ChallengePhase.results);
          if (b.state.phase == ChallengePhase.results) break;
          if (question == 0) await h.shot('${preset}_question', settleMs: 0);
          b.add(ChallengeAnswerSelected(ChallengeChoice(optionId: answers[question]['option_id'] as String)));
          await h.until(() => b.state.phase == ChallengePhase.reveal);
          if (question == 0) await h.shot('${preset}_explanation', settleMs: 0);
          question++;
          await h.until(() => b.state.phase == ChallengePhase.question || b.state.phase == ChallengePhase.results);
        }
        expect(b.state.phase, ChallengePhase.results);
        await h.shot('${preset}_results');
        router.pop();
        await h.wait();
      }
      router.go('/profile');
      await h.until(() => find.byKey(const ValueKey('profile-avatar')).evaluate().isNotEmpty);
      await h.shot('profile');
      final learnerId = h.mock.db.user!['user_id'];
      final progress = Set<String>.from(h.mock.db.completedLessons);
      await t.longPress(find.byKey(const ValueKey('profile-avatar')));
      await h.until(() => find.byType(DevToolsPage).evaluate().isNotEmpty);
      await h.tap('dev-reviewer');
      await t.enterText(find.byKey(const ValueKey('reviewer-email')), 'reviewer@qabas.app');
      await t.enterText(find.byKey(const ValueKey('reviewer-password')), 'qabas-review');
      FocusManager.instance.primaryFocus?.unfocus();
      await h.tap('reviewer-sign-in');
      await h.until(
        () =>
            find.byType(ReviewerRunsPage).evaluate().isNotEmpty &&
            t.element(find.byType(ReviewerRunsPage)).read<ReviewerRunsBloc>().state.status == ReviewerStatus.ready,
      );
      await h.shot('reviewer_runs');
      router.go('/reviewer/runs/run_recording');
      await h.until(
        () =>
            find.byType(ReviewerDetailPage).evaluate().isNotEmpty &&
            t.element(find.byType(ReviewerDetailPage)).read<ReviewerDetailBloc>().state.status == ReviewerStatus.ready,
      );
      await h.shot('reviewer_draft');
      final previews = [for (final e in find.byType(BlocBuilder<LessonPreviewBloc, PreviewState>).evaluate()) e.read<LessonPreviewBloc>()];
      for (final p in previews) {
        p.add(const PreviewItemChanged(2));
      }
      await h.shot('reviewer_preview');
      router.go('/reviewer/blind');
      await h.until(() => find.byType(ReviewerBlindPage).evaluate().isNotEmpty);
      final blind = t.element(find.byType(ReviewerBlindPage)).read<ReviewerBlindBloc>();
      await h.until(() => blind.state.pair != null);
      await h.shot('blind_populated');
      for (var pair = 0; pair < 3; pair++) {
        for (var i = 0; i < 3; i++) {
          blind.add(BlindChoicePicked(i, i == 2 ? 'unsure' : 'a'));
        }
        await h.wait();
        blind.add(const BlindAnswerSubmitted());
        await h.until(
          () =>
              blind.state.status == ReviewerStatus.ready &&
              (pair == 2 ? blind.state.pair == null : blind.state.pair?.pairId == 'pair_recording_${pair + 2}'),
        );
      }
      await h.shot('blind_exhausted');
      await t.longPress(find.byKey(const ValueKey('reviewer-language-gesture')));
      await h.until(() => find.byKey(const ValueKey('recording-reviewer-reset')).evaluate().isNotEmpty);
      await h.tap('recording-reviewer-reset');
      router.go('/reviewer/blind');
      await h.until(
        () =>
            find.byType(ReviewerBlindPage).evaluate().isNotEmpty &&
            t.element(find.byType(ReviewerBlindPage)).read<ReviewerBlindBloc>().state.pair != null,
      );
      await h.shot('blind_reset');
      router.go('/reviewer/metrics');
      await h.until(
        () =>
            find.byType(ReviewerMetricsPage).evaluate().isNotEmpty &&
            t.element(find.byType(ReviewerMetricsPage)).read<ReviewerMetricsBloc>().state.status == ReviewerStatus.ready,
      );
      await h.shot('metrics');
      t.element(find.byType(ReviewerShell)).read<ReviewerAuthBloc>().add(const ReviewerSignedOut());
      await spine.journeyReady(h);
      expect(h.mock.db.user!['user_id'], learnerId);
      expect(h.mock.db.completedLessons, progress);
      await h.shot('learner_restored');
    });
  }
}

// Larger pump steps keep the same elapsed animation time without capturing every native frame.
final class RecordingHarness extends TourHarness {
  RecordingHarness(TourHarness base) : super(base.t, base.binding, base.d, base.prefix, phase: base.phase);
  @override
  Future<void> wait([int ms = 600]) async {
    for (var elapsed = 0; elapsed < ms; elapsed += 100) {
      await t.pump(Duration(milliseconds: (ms - elapsed).clamp(1, 100)));
    }
    expect(t.takeException(), isNull);
  }
}
