// Port of the read-only prototype tour. Names 01–39, 43–46, 53, 55 and 56
// retain the prototype index; 58+ cover contract additions. Tier B stays deferred.
// Run with config/demo.json. TOUR=all|spine|failures|reference|onboarding|controls|requests;
// Groups can be comma-separated. TOUR_CASE restricts the capture groups.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/core/design_system/components/journey_node.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/q_numbers.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/auth/presentation/pages/session_ended_page.dart';
import 'package:qabas/features/dev_tools/domain/repositories/dev_tools_repository.dart';
import 'package:qabas/features/dev_tools/domain/usecases/dev_tools_actions.dart';
import 'package:qabas/features/dev_tools/presentation/pages/dev_tools_page.dart';
import 'package:qabas/features/discover/presentation/bloc/discover_bloc.dart';
import 'package:qabas/features/discover/presentation/pages/discover_page.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:qabas/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:qabas/features/profile/presentation/bloc/settings_bloc.dart';
import 'package:qabas/features/profile/presentation/pages/about_page.dart';
import 'package:qabas/features/profile/presentation/pages/profile_page.dart';
import 'package:qabas/features/profile/presentation/pages/settings_page.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'package:qabas/features/raqeeb/presentation/pages/raqeeb_page.dart';
import 'package:qabas/features/raqeeb/presentation/widgets/answer_bubble.dart';
import 'package:qabas/features/raqeeb/presentation/widgets/chat_widgets.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_result_bloc.dart';
import 'package:qabas/features/session/presentation/exercises/exercise_views.dart';
import 'package:qabas/features/session/presentation/pages/lesson_intro_page.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/features/session/presentation/pages/session_result_page.dart';
import 'package:qabas/features/session/presentation/steps/content_step_bloc.dart';
import 'package:qabas/features/session/presentation/steps/exercise_step_bloc.dart';
import 'package:qabas/features/streak/presentation/pages/streak_page.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/presentation/visuals/builtin/scenes.dart';
import 'support/tour_harness.dart';

Future<void> journeyReady(TourHarness h) => h.until(
  () => find.byType(JourneyPage).evaluate().isNotEmpty && h.t.element(find.byType(JourneyPage)).read<JourneyBloc>().state.journey != null,
  reason: 'Journey ready',
);

Future<void> introReady(TourHarness h) => h.until(
  () =>
      find.byType(LessonIntroPage).evaluate().isNotEmpty &&
      h.t.element(find.byType(LessonIntroPage)).read<LessonIntroBloc>().state.status == LessonIntroStatus.ready,
  reason: 'Lesson intro ready',
);

Future<void> begin(TourHarness h) async {
  await introReady(h);
  await h.tap('lesson-start');
  await h.until(() => find.byType(SessionPlayerPage).evaluate().isNotEmpty && h.player.state.status == PlayerStatus.playing);
}

Future<void> onboarding(TourHarness h, String language) async {
  await h.until(() => find.byType(OnboardingPageView).evaluate().isNotEmpty);
  OnboardingBloc bloc() => h.t.element(find.byType(OnboardingPageView)).read<OnboardingBloc>();
  Future<void> next() => h.tapFinder(find.descendant(of: find.byKey(ValueKey(bloc().state.page)), matching: h.key('onboarding-continue')));
  await h.shot('01_onboarding_language');
  await h.tapFinder(find.text(language == 'en' ? 'English' : 'العربية'));
  await h.shot('02_onboarding_welcome');
  await h.tap('onboarding-get-started');
  await h.shot('03_onboarding_who');
  var c = h.t.element(find.byType(OnboardingPageView));
  await h.tapFinder(find.text(c.l10n.onboardingExplorerTitle));
  await h.shot('04_onboarding_who_selected');
  await next();
  c = h.t.element(find.byType(OnboardingPageView));
  await h.tapFinder(find.text(c.l10n.onboardingFamiliarSome));
  await h.shot('05_onboarding_familiar');
  await next();
  expect(bloc().state.dailyGoal, 10);
  await h.shot('06_onboarding_goal');
  await next();
  c = h.t.element(find.byType(OnboardingPageView));
  for (final hour in [8, 13, 19, 21]) {
    final label = QNumbers.localizeDigits(MaterialLocalizations.of(c).formatTimeOfDay(TimeOfDay(hour: hour, minute: 0)), language);
    expect(find.text(label), findsOneWidget);
  }
  await h.shot('07_onboarding_privacy');
  await next();
  expect(bloc().state.pages.length, 7);
  await h.shot('08_onboarding_ready');
  await h.tap('onboarding-submit');
  await journeyReady(h);
  expect(h.d.session.state.user!.goalAnchor, isNull);
  expect(h.mock.db.user!['track'], 'explorer');
}

Future<void> fill(TourHarness h, Exercise ex, AnswerPayload answer, {bool reference = false}) async {
  switch (answer) {
    case RecitationAnswer() || FillsAnswer() || RatingAnswer() || TimeoutAnswer():
      throw StateError('This earlier-phase harness does not use Phase 12 answers');
    case OptionAnswer():
      await h.tap('option-${answer.optionId}');
    case SegmentAnswer():
      await h.tap('segment-${answer.segmentId}');
    case PinAnswer():
      await h.tap('pin-${answer.pinId}');
    case ReasonAnswer():
      await h.tap('truth-${answer.value}');
      await h.tap('reason-${answer.reasonOptionId}');
    case PairsAnswer():
      for (final e in answer.pairs.entries) {
        await h.tap('left-${e.key}');
        await h.tap('right-${e.value}');
      }
    case AssignmentsAnswer():
      final day = (ex.payload as CategorizePayload).presentation == 'day_arc';
      for (final (i, e) in answer.assignments.entries.indexed) {
        await h.tap('token-${e.key}');
        if (reference && !day && i == 2) await h.shot('23_lesson_sort_selected');
        await h.tap('${day ? 'slot' : 'category'}-${e.value}');
      }
      if (reference && day) {
        await Scrollable.ensureVisible(h.t.element(find.byType(DayArcScene)), alignment: 0);
        await h.wait();
      }
    case OrderAnswer():
      for (final id in answer.order) {
        await h.tap('token-$id');
      }
    case SkippedAnswer():
      await h.tap('recite-meaning');
      if (reference) await h.shot('31_lesson_recite_playing');
      await h.tap('recite-skip');
      if (reference) await h.shot('32_lesson_recite_done');
    case UnavailableAnswer():
      throw StateError('Unexpected unavailable answer in tour');
  }
  expect(h.t.element(find.byType(ExerciseBody)).read<ExerciseStepBloc>().state.draft.isComplete, true);
}

/// Interacts with every content CTA and answer tile, with one deliberate miss.
Future<void> play(TourHarness h, {required bool reference, bool failures = false}) async {
  final p = h.player;
  var missed = false, submitFailed = false, finishFailed = false;
  final seen = <String>{};
  for (var guard = 0; guard < 200 && p.state.status != PlayerStatus.finished; guard++) {
    if (p.state.status == PlayerStatus.failure && failures && finishFailed) {
      await h.shot('offline_finish');
      await h.d.services<DevToolsActions>().change(DevOption.offline, false);
      await h.tapFinder(find.descendant(of: find.byType(QErrorView), matching: find.byType(QButton)));
      continue;
    }
    if (p.state.status == PlayerStatus.finishing) {
      await h.until(() => p.state.status == PlayerStatus.finished || p.state.status == PlayerStatus.failure);
      if (p.state.status == PlayerStatus.failure) continue;
      break;
    }
    if (p.state.status == PlayerStatus.retryRound) {
      await h.shot(reference ? 'salah_retry_round' : 'unit0_retry_round');
      await h.tapFinder(find.byType(QButton).last);
      continue;
    }
    final state = p.state, item = state.item!;
    if (item is ExerciseItem) {
      final ex = item.exercise!, wire = h.mock.db.sessionKeys[state.session!.sessionId]![ex.id] as Map;
      var answer = ex.type == ExerciseType.reciteVerse
          ? const SkippedAnswer()
          : correctAnswer(ex.type, Map<String, dynamic>.from(wire['answer_key'] as Map))!;
      final miss = !missed && !state.inRetry && ex.payload is ChoicePayload && (reference ? ex.framing != null : state.cursor >= 9);
      if (miss) {
        answer = OptionAnswer((ex.payload as ChoicePayload).options.firstWhere((o) => o.id != (answer as OptionAnswer).optionId).id);
        missed = true;
      }
      final name = reference
          ? switch (state.cursor) {
              7 => '22_lesson_sort_empty',
              9 => null,
              10 => '29_lesson_scenario',
              11 => '30_lesson_recite',
              _ => null,
            }
          : 'unit0_${state.cursor}_${ex.type.name}';
      if (name != null && !state.inRetry && !failures) await h.shot(name);
      await fill(h, ex, answer, reference: reference && !state.inRetry);
      if (reference && !state.inRetry) {
        final selected = switch (state.cursor) {
          7 => '24_lesson_sort_filled',
          9 => '27_lesson_timeline_filled',
          13 => '34_lesson_order_filled',
          _ => null,
        };
        if (selected != null) await h.shot(selected);
      }
      if (failures && !submitFailed) await h.d.services<DevToolsActions>().change(DevOption.offline, true);
      await h.tap('exercise-cta');
      if (failures && !submitFailed) {
        await h.until(() => p.state.failure != null);
        expect(h.t.element(find.byType(ExerciseBody)).read<ExerciseStepBloc>().state.draft.toPayload(), answer);
        await h.shot('offline_answer_retained');
        await h.d.services<DevToolsActions>().change(DevOption.offline, false);
        await h.tap('exercise-cta');
        submitFailed = true;
      }
      await h.until(
        () => p.state.status == PlayerStatus.feedback || p.state.item?.blockId != item.blockId || p.state.status == PlayerStatus.finished,
      );
      if (p.state.status == PlayerStatus.feedback) {
        expect(p.state.evaluation!.correct, !miss);
        if (reference && !state.inRetry) {
          final feedback = switch (state.cursor) {
            3 => '18_lesson_discover_feedback',
            5 => '20_lesson_misconception_retry',
            7 => '25_lesson_sort_feedback',
            9 => '28_lesson_timeline_feedback',
            13 => '35_lesson_order_feedback',
            _ => null,
          };
          if (feedback != null) await h.shot(feedback);
        } else if (miss) {
          await h.shot('unit0_warm_retry_feedback');
        }
        if (failures && !finishFailed && state.inRetry && state.retryCursor == state.retryQueue.length - 1) {
          await h.d.services<DevToolsActions>().change(DevOption.offline, true);
          finishFailed = true;
        }
        await h.tap('feedback-continue');
      }
    } else {
      final content = h.t.element(h.key(state.status == PlayerStatus.feedback ? 'predict-continue' : 'step-cta')).read<ContentStepBloc>();
      final pose = '${item.blockId}/${content.state.beat}/${content.state.shown}/${content.state.status}';
      if (seen.add(pose)) {
        final name = reference
            ? switch (state.cursor) {
                0 => '12_lesson_hook',
                2 => switch (content.state.beat) {
                  0 => '15_lesson_story_1',
                  1 => '16_lesson_story_2',
                  3 => '17_lesson_story_4',
                  _ => null,
                },
                4 => content.state.shown == (item as TeachItem).points.length ? '19_lesson_teach_river' : null,
                6 => content.state.shown == 1 ? '21_lesson_teach_pillars' : null,
                8 => content.state.shown == (item as TeachItem).points.length ? '26_lesson_teach_dayarc' : null,
                12 => '33_lesson_summary',
                _ => null,
              }
            : 'unit0_${state.cursor}_${content.state.beat}_${content.state.shown}_${content.state.status.name}';
        if (name != null && !failures) await h.shot(name);
      }
      if (item is PredictItem && state.status != PlayerStatus.feedback) {
        await h.tap(reference ? 'predict-option-1' : 'predict-option-0');
        if (reference) await h.shot('13_lesson_predict_selected');
      }
      if (failures &&
          !finishFailed &&
          state.retryQueue.isEmpty &&
          state.cursor == state.session!.items.length - 1 &&
          content.state.shown >= (item is TeachItem ? item.points.length : 0)) {
        await h.d.services<DevToolsActions>().change(DevOption.offline, true);
        finishFailed = true;
      }
      await h.tap(state.status == PlayerStatus.feedback ? 'predict-continue' : 'step-cta');
      if (item is PredictItem && p.state.status == PlayerStatus.feedback && reference) await h.shot('14_lesson_predict_feedback');
    }
  }
  expect(missed, true);
  if (failures) {
    expect(submitFailed, true);
    expect(finishFailed, true);
  }
  await h.until(
    () =>
        find.byType(SessionResultPage).evaluate().isNotEmpty &&
        h.t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state.status == SessionResultStatus.ready,
  );
  await h.shot(reference ? '36_lesson_complete' : 'unit0_complete');
}

Future<void> leaveResult(TourHarness h, {bool streak = false}) async {
  final extended = h.t.element(find.byType(SessionResultPage)).read<SessionResultBloc>().state.result!.streakExtended;
  await h.tap('result-continue');
  if (streak || extended) {
    await h.until(() => find.byType(StreakPage).evaluate().isNotEmpty);
    await h.shot('37_streak_celebration');
    await h.tap('streak-continue');
  }
  await journeyReady(h);
}

Future<void> chat(TourHarness h, String outcome, String name) async {
  final c = h.t.element(find.byType(RaqeebPage)), bloc = c.read<RaqeebChatBloc>();
  if (bloc.state.turns.isNotEmpty) await h.tap('raqeeb-new');
  await h.d.services<DevToolsActions>().change(DevOption.raqeebOutcome, outcome);
  final question =
      raqeebSuggestions(c)[outcome == 'A'
          ? 0
          : outcome == 'B'
          ? 1
          : 3];
  await h.t.tap(find.byType(TextField));
  await h.wait(300);
  await h.t.enterText(find.byType(TextField), question);
  await h.wait(300);
  await h.tapFinder(find.byTooltip(c.l10n.commonSendTooltip));
  await h.until(() => bloc.state.status == ChatStatus.processing);
  if (outcome == 'A') await h.shot('raqeeb_processing');
  await h.until(() => !bloc.state.busy && bloc.state.turns.last.assistant is CompletedMessage);
  h.t.widget<ListView>(find.byType(ListView)).controller!.jumpTo(0);
  if (outcome != 'A') {
    final card = find.byType(outcome == 'B' ? VerificationCard : ReferralCard);
    await Scrollable.ensureVisible(h.t.element(card.first), alignment: .15);
    await h.wait();
  }
  await h.shot(name);
}

Future<void> spine(TourHarness h, String language) async {
  await onboarding(h, language);
  await h.shot('09_journey');
  final locked = find.byWidgetPredicate((w) => w is QJourneyNode && w.node.id == 'les_u0_l3');
  await h.tapFinder(locked);
  await h.until(() => h.key('soft-lock-start').evaluate().isNotEmpty);
  await h.shot('59_soft_lock');
  Navigator.of(h.t.element(h.key('soft-lock-start'))).pop();
  await h.wait();
  final current = find.byWidgetPredicate((w) => w is QJourneyNode && w.node.id == 'les_u0_l1');
  await h.tapFinder(current);
  await Scrollable.ensureVisible(h.t.element(current), alignment: 0);
  await h.wait();
  await h.shot('10_journey_popover');
  await h.tap('node-start-les_u0_l1');
  await introReady(h);
  await h.shot('unit0_intro');
  await begin(h);
  await play(h, reference: false);
  await leaveResult(h, streak: true);
  final journey = h.t.element(find.byType(JourneyPage)).read<JourneyBloc>().state.journey!;
  expect(journey.lesson('les_u0_l1')!.state, LessonState.completed);
  expect(journey.lesson('les_u0_l2')!.state, LessonState.available);
  await h.shot('38_journey_after');
  await h.tap('nav-1');
  await h.until(() => find.byType(DiscoverPage).evaluate().isNotEmpty && h.key('discover-les_u1_l1').evaluate().isNotEmpty);
  await h.shot('58_discover');
  await h.tap('discover-les_u1_l1');
  await begin(h);
  await h.shot('60_discover_lesson_hook');
  await h.tap('step-cta');
  await h.shot('61_discover_lesson_step');
  await h.tap('player-close');
  await h.tap('leave-lesson');
  await journeyReady(h);
  await h.tap('nav-2');
  await h.until(() => find.byType(RaqeebPage).evaluate().isNotEmpty);
  await h.shot('43_raqeeb_welcome');
  await chat(h, 'A', '44_raqeeb_answer');
  await chat(h, 'B', '45_raqeeb_verification');
  await chat(h, 'C', '46_raqeeb_specialist');
  await referencePages(h, language);
}

Future<void> profileTop(TourHarness h) async {
  final scroll = find.descendant(of: find.byType(ProfilePage), matching: find.byType(Scrollable)).first;
  h.t.state<ScrollableState>(scroll).position.jumpTo(0);
  await h.wait();
}

Future<void> referencePages(TourHarness h, String language) async {
  final current = find.byWidgetPredicate((w) => w is QJourneyNode && w.node.id == 'les_u0_l1');
  await h.tap('nav-4');
  await h.until(
    () =>
        find.byType(ProfilePage).evaluate().isNotEmpty && h.t.element(find.byType(ProfilePage)).read<ProfileBloc>().state.snapshot != null,
  );
  await h.shot('53_profile');
  final words = find.text(h.t.element(find.byType(ProfilePage)).l10n.reviewYourWords);
  await Scrollable.ensureVisible(h.t.element(words), alignment: .1);
  await h.shot('39_review');
  await profileTop(h);
  await h.tap('profile-settings');
  await h.until(
    () => find.byType(SettingsPage).evaluate().isNotEmpty && h.t.element(find.byType(SettingsPage)).read<SettingsBloc>().state.user != null,
  );
  await h.shot('55_settings');
  await h.tap('settings-about');
  await h.until(() => find.byType(AboutPage).evaluate().isNotEmpty);
  await h.shot('56_about');
  final router = GoRouter.of(h.t.element(find.byType(AboutPage)));
  router.pop();
  await h.wait();
  await h.tap('settings-language');
  final c = h.t.element(find.byType(SettingsPage));
  await h.tapFinder(find.text(language == 'en' ? c.l10n.settingsArabic : c.l10n.settingsEnglish).last);
  await h.until(
    () =>
        h.d.locale.state.language != language &&
        h.t.element(find.byType(SettingsPage)).read<SettingsBloc>().state.status == SettingsStatus.ready,
  );
  expect(Directionality.of(h.t.element(find.byType(SettingsPage))), language == 'en' ? TextDirection.rtl : TextDirection.ltr);
  router.pop();
  await h.wait();
  await h.tap('nav-0');
  await journeyReady(h);
  await h.shot('62_switched_journey');
  await h.tapFinder(current);
  await h.tap('node-start-les_u0_l1');
  await begin(h);
  await h.shot('63_switched_lesson');
  await h.tap('player-close');
  await h.tap('leave-lesson');
  await journeyReady(h);
  // Restore through the normal Settings save before the reference comparison.
  await h.tap('nav-4');
  await profileTop(h);
  await h.tap('profile-settings');
  await h.until(() => h.t.element(find.byType(SettingsPage)).read<SettingsBloc>().state.user != null);
  await h.tap('settings-language');
  final settings = h.t.element(find.byType(SettingsPage));
  await h.tapFinder(find.text(language == 'en' ? settings.l10n.settingsEnglish : settings.l10n.settingsArabic).last);
  await h.until(() => h.d.locale.state.language == language && settings.read<SettingsBloc>().state.status == SettingsStatus.ready);
  router.pop();
  await h.wait();
  await h.t.longPress(h.key('profile-avatar'));
  await h.until(() => find.byType(DevToolsPage).evaluate().isNotEmpty);
  await h.tap('dev-salah-$language-new_muslim');
  await introReady(h);
  await h.shot('11_lesson_intro');
  await begin(h);
  await play(h, reference: true);
  await leaveResult(h);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const part = String.fromEnvironment('TOUR', defaultValue: 'all');
  const selected = String.fromEnvironment('TOUR_CASE');
  final parts = part.split(',');
  bool run(String group) => parts.contains('all') || parts.contains(group);
  if (run('spine') || run('reference') || run('onboarding')) {
    for (final language in ['en', 'ar']) {
      for (final reduced in [false, true]) {
        final name = '${language}_${reduced ? 'reduced' : 'motion'}';
        if (selected.isNotEmpty && !selected.split(',').contains(name)) continue;
        testWidgets('Demo spine and prototype tour $name', (t) async {
          final h = await TourHarness.fresh(t, binding, language, reduced, onboarded: parts.contains('reference'));
          if (parts.contains('reference')) {
            await journeyReady(h);
            await referencePages(h, language);
          } else if (parts.contains('onboarding')) {
            await onboarding(h, language);
          } else {
            await spine(h, language);
          }
        }, timeout: const Timeout(Duration(minutes: 15)));
      }
    }
  }
  if (run('failures') || parts.contains('controls') || parts.contains('requests')) {
    registerFailures(
      binding,
      requests: run('failures') || parts.contains('requests'),
      controls: run('failures') || parts.contains('controls'),
    );
  }
}

// Kept in this entrypoint so one prebuilt app can run the whole acceptance tour.
void registerFailures(IntegrationTestWidgetsFlutterBinding binding, {bool requests = true, bool controls = true}) {
  for (final language in ['en', 'ar']) {
    if (requests) {
      testWidgets('Demo request failures, preserved drafts and retries $language', (t) async {
        final h = await TourHarness.fresh(t, binding, language, true, onboarded: true, group: 'requests');
        await journeyReady(h);
        final router = GoRouter.of(t.element(find.byType(JourneyPage)));
        final controls = h.d.services<DevToolsActions>();
        // Initial reads and POST /sessions keep their normal localized retry surface.
        for (final path in ['/settings', '/lesson/les_u0_l1/intro']) {
          await controls.change(DevOption.offline, true);
          router.go(path);
          await h.until(() => find.byType(QErrorView).evaluate().isNotEmpty);
          await h.shot(path == '/settings' ? 'offline_settings' : 'offline_intro');
          await controls.change(DevOption.offline, false);
          await h.tapFinder(find.descendant(of: find.byType(QErrorView), matching: find.byType(QButton)));
          await h.until(() => find.byType(QErrorView).evaluate().isEmpty);
          if (path == '/settings') {
            final settings = t.element(find.byType(SettingsPage)).read<SettingsBloc>();
            await h.until(() => settings.state.user != null);
            final previous = h.d.locale.state.language;
            await controls.change(DevOption.nextStatus, 503);
            await h.tap('settings-language');
            final c = t.element(find.byType(SettingsPage));
            await h.tapFinder(find.text(language == 'en' ? c.l10n.settingsArabic : c.l10n.settingsEnglish).last);
            await h.until(() => settings.state.notice > 0);
            expect(h.d.locale.state.language, previous);
            await h.shot('503_settings_rollback');
            ScaffoldMessenger.of(t.element(find.byType(SettingsPage))).removeCurrentSnackBar();
          }
        }
        await begin(h);
        await play(h, reference: false, failures: true);
        await leaveResult(h, streak: true);
        await h.tap('nav-2');
        await h.until(() => find.byType(RaqeebPage).evaluate().isNotEmpty);
        final c = t.element(find.byType(RaqeebPage)), bloc = c.read<RaqeebChatBloc>();
        final question = raqeebSuggestions(c).first;
        await t.tap(find.byType(TextField));
        await h.wait(300);
        await t.enterText(find.byType(TextField), question);
        await h.wait(300);
        await controls.change(DevOption.offline, true);
        await h.tapFinder(find.byTooltip(c.l10n.commonSendTooltip));
        await h.until(() => bloc.state.turns.isNotEmpty && !bloc.state.busy);
        final turn = bloc.state.turns.last;
        expect(turn.text, question);
        await h.shot('offline_raqeeb_retained');
        await controls.change(DevOption.offline, false);
        await h.tapFinder(find.text(c.l10n.commonRetry));
        await h.until(() => !bloc.state.busy && bloc.state.turns.last.assistant is CompletedMessage);
        await h.shot('offline_raqeeb_recovered');
        // Warm cached Profile and Journey survive a failed refresh.
        router.go('/profile');
        await h.until(
          () =>
              find.byType(ProfilePage).evaluate().isNotEmpty &&
              t.element(find.byType(ProfilePage)).read<ProfileBloc>().state.snapshot != null,
        );
        final profile = t.element(find.byType(ProfilePage)).read<ProfileBloc>();
        final snapshot = profile.state.snapshot;
        await controls.change(DevOption.offline, true);
        profile.add(const ProfileOpened());
        await h.until(() => profile.state.status == ProfileStatus.failure);
        expect(profile.state.snapshot, snapshot);
        final profileCopy = t.element(find.byType(ProfilePage)).l10n;
        expect(find.text(profileCopy.errorNetworkBody), findsOneWidget);
        expect(find.text(profileCopy.settingsSaveFailed), findsNothing);
        await h.shot('offline_profile_cached');
        await controls.change(DevOption.offline, false);
        await h.tapFinder(find.text(t.element(find.byType(ProfilePage)).l10n.commonRetry.toUpperCase()));
        await h.until(() => profile.state.status == ProfileStatus.ready);
        await h.shot('offline_profile_recovered');
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
    if (controls) {
      testWidgets('Demo developer failure toggles $language', (t) async {
        final h = await TourHarness.fresh(t, binding, language, true, onboarded: true, group: 'failures');
        await journeyReady(h);
        final router = GoRouter.of(t.element(find.byType(JourneyPage)));
        Future<void> dev() async {
          router.go('/profile');
          await h.until(() => h.key('profile-avatar').evaluate().isNotEmpty);
          await t.longPress(h.key('profile-avatar'));
          await h.until(() => find.byType(DevToolsPage).evaluate().isNotEmpty);
        }

        // Actual menu controls: transient GET recovery and retained cached journey.
        for (final status in [503, 429]) {
          await dev();
          await h.tapFinder(find.text('Next HTTP $status'));
          router.go('/journey');
          await journeyReady(h);
          final journey = t.element(find.byType(JourneyPage)).read<JourneyBloc>();
          journey.add(const JourneyRefreshed());
          await h.until(() => h.mock.controls.nextStatus == null && !journey.state.refreshing);
          expect(journey.state.failure, isNull);
          await h.shot('${status}_journey_recovered');
        }
        await dev();
        final offline = find.ancestor(of: find.text('Offline'), matching: find.byType(SwitchListTile));
        await h.tapFinder(offline);
        expect(h.mock.controls.offline, true);
        router.go('/discover');
        await h.until(
          () =>
              find.byType(DiscoverPage).evaluate().isNotEmpty &&
              t.element(find.byType(DiscoverPage)).read<DiscoverBloc>().state.journey != null,
        );
        final discover = t.element(find.byType(DiscoverPage)).read<DiscoverBloc>();
        final cached = discover.state.journey;
        discover.add(const DiscoverRefreshed());
        await h.until(() => discover.state.status == DiscoverStatus.failure);
        expect(discover.state.journey, same(cached));
        expect(find.byType(QInlineError), findsOneWidget);
        await h.shot('offline_discover');
        // Existing menu remains available even when a request is offline.
        unawaited(router.push<void>('/developer'));
        await h.until(() => find.byType(DevToolsPage).evaluate().isNotEmpty);
        await h.tapFinder(offline);
        expect(h.mock.controls.offline, false);
        router.pop();
        await h.wait();
        expect(t.element(find.byType(DiscoverPage)).read<DiscoverBloc>(), same(discover));
        await h.tapFinder(find.descendant(of: find.byType(QInlineError), matching: find.byType(TextButton)));
        await h.until(() => discover.state.status == DiscoverStatus.ready && discover.state.failure == null);
        await h.shot('offline_discover_recovered');
        await dev();
        final unknown = find.ancestor(of: find.text('Unknown visual fallback'), matching: find.byType(SwitchListTile));
        await h.tapFinder(unknown);
        router.go('/lesson/les_u0_l1/intro');
        await begin(h);
        await h.shot('unknown_visual_fallback');
        await h.tap('player-close');
        await h.tap('leave-lesson');
        await journeyReady(h);
        await dev();
        await h.tapFinder(unknown);
        await dev();
        await h.tapFinder(find.text('Revoke token'));
        await h.until(() => find.byType(SessionEndedPage).evaluate().isNotEmpty);
        expect(await h.d.services<TokenStore>().read() == null, true);
        await h.shot('401_session_ended');
        await h.tap('session-ended-continue');
        await h.until(() => find.byType(OnboardingPageView).evaluate().isNotEmpty);
        expect(await h.d.services<TokenStore>().read() != null, true);
        await onboarding(h, language);
        await dev();
        await h.tapFinder(find.text('Next HTTP 426'));
        await h.until(() => find.byType(QBlockingScreen).evaluate().isNotEmpty);
        expect(h.d.session.state.status, SessionStatus.outdated);
        await h.shot('426_update_required');
        // An outdated client must keep blocking until updated; retry cannot bypass it.
        h.d.session.add(const BootstrapRetried());
        await h.wait();
        expect(h.d.session.state.status, SessionStatus.outdated);
      }, timeout: const Timeout(Duration(minutes: 8)));
    }
  }
}
