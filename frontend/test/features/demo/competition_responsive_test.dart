import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/characters/character_view.dart';
import 'package:qabas/features/dev_tools/presentation/bloc/dev_tools_bloc.dart';
import 'package:qabas/features/dev_tools/presentation/pages/dev_tools_page.dart';
import 'package:qabas/features/profile/presentation/pages/profile_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_blind_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_dashboard_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/lesson/presentation/lesson_preview.dart';
import '../journey/journey_responsive_test.dart' show mountJourney, pumpJourney, journeyUntil, press, journeySizes;

void main() {
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('competition public entry, populated pairs, resize and retakes $language/$reduced', (t) async {
        const timezone = MethodChannel('flutter_timezone');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(timezone, (_) async => 'UTC');
        addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(timezone, null));
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(402, 874);
        t.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mountJourney(
          t,
          locale: language,
          reduced: reduced,
          config: AppConfig(
            flavor: AppFlavor.demo,
            demoDeveloper: true,
            recordingDemo: true,
            judgesDemo: true,
            hideDraftNotices: true,
            curiosityOnboarding: false,
          ),
        );
        addTearDown(() async {
          await t.runAsync(d.sensory.dispose);
          await t.pumpWidget(const SizedBox());
          await pumpJourney(t);
          await t.runAsync(d.dispose);
        });
        final mock = d.services<MockBackend>();
        await t.runAsync(() async {
          for (final path in [
            'recording/factory_run.json',
            'recording/factory_plan.json',
            'recording/blind_en.json',
            'recording/blind_ar.json',
            'reviewer/u0l1.factory_run.json',
            'reviewer/u1l1.factory_run.json',
            'examples/AuthResp__post_auth_reviewer__1.json',
          ]) {
            await mock.fixtures.load(path);
          }
          await mock.fixtures.example('FactoryRun');
          await mock.fixtures.example('Achievements');
          await mock.fixtures.example('Page[TermCard]');
          await mock.fixtures.object('contract/sessions/session_practice_all_types.json');
        });
        final router = GoRouter.of(t.element(find.byKey(const ValueKey('nav-0'))));
        router.go('/profile');
        await journeyUntil(t, () => find.byType(ProfilePage).evaluate().isNotEmpty);
        final profile = t.widget<ProfilePage>(find.byType(ProfilePage));
        expect(profile.developerEnabled, true);
        await journeyUntil(t, () => find.byKey(const ValueKey('profile-reviewer-sample')).evaluate().isNotEmpty);
        await t.ensureVisible(find.byKey(const ValueKey('profile-reviewer-sample')));
        await press(t, find.byKey(const ValueKey('profile-reviewer-sample')));
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await pumpJourney(t);
          await t.ensureVisible(find.byKey(const ValueKey('reviewer-sample-open')));
          expect(t.takeException(), isNull);
        }
        await press(t, find.byKey(const ValueKey('reviewer-sample-open')));
        await journeyUntil(t, () => find.byType(ReviewerRunsPage).evaluate().isNotEmpty);
        final runs = t.element(find.byType(ReviewerRunsPage)).read<ReviewerRunsBloc>();
        await journeyUntil(t, () => runs.state.status == ReviewerStatus.ready);
        expect(runs.state.items.length, 5);
        router.go('/reviewer/runs/run_recording');
        await pumpJourney(t);
        final detail = t.element(find.byType(ReviewerDetailPage)).read<ReviewerDetailBloc>();
        await journeyUntil(t, () => detail.state.status == ReviewerStatus.ready);
        expect(detail.state.hasBlockers, true);
        expect(find.byType(CharacterView), findsNothing);
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull, reason: 'recording preview $size');
        }
        router.go('/reviewer/blind');
        await pumpJourney(t);
        final blind = t.element(find.byType(ReviewerBlindPage)).read<ReviewerBlindBloc>();
        await journeyUntil(t, () => blind.state.pair != null);
        expect(blind.state.pair!.lessonA.items.length, greaterThan(5));
        expect(blind.state.pair!.lessonB.items.length, greaterThan(5));
        final previews = [
          for (final e in find.byType(BlocBuilder<LessonPreviewBloc, PreviewState>).evaluate()) e.read<LessonPreviewBloc>(),
        ];
        expect(previews.length, 2);
        for (final p in previews) {
          p.add(const PreviewItemChanged(1));
        }
        await t.pump();
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull, reason: 'blind $size');
          expect(previews.every((p) => !p.isClosed && p.state.cursor == 1), true);
        }
        for (var pair = 0; pair < 3; pair++) {
          for (var i = 0; i < 3; i++) {
            blind.add(BlindChoicePicked(i, i == 2 ? 'unsure' : 'a'));
          }
          await pumpJourney(t);
          blind.add(const BlindAnswerSubmitted());
          await pumpJourney(t);
          if (pair < 2) {
            await journeyUntil(t, () => blind.state.pair?.pairId == 'pair_recording_${pair + 2}');
            final current = [
              for (final e in find.byType(BlocBuilder<LessonPreviewBloc, PreviewState>).evaluate()) e.read<LessonPreviewBloc>(),
            ];
            expect(current.every((p) => p.state.cursor == 0), true);
          }
        }
        await journeyUntil(t, () => blind.state.status == ReviewerStatus.ready && blind.state.pair == null);
        // Hidden reviewer gesture reaches the reset controls without a visible demo button.
        final langGesture = find.byKey(const ValueKey('reviewer-language-gesture'));
        await t.longPress(langGesture);
        await pumpJourney(t);
        expect(find.byType(DevToolsPage), findsOneWidget);
        await journeyUntil(
          t,
          () => find.byKey(const ValueKey('recording-reviewer-reset')).evaluate().isNotEmpty,
          diagnostic: () {
            final s = t.element(find.byType(DevToolsPage)).read<DevToolsBloc>().state;
            return '${s.status} ${s.failure} ${s.snapshot?.values}';
          },
        );
        await press(t, find.byKey(const ValueKey('recording-reviewer-reset')));
        router.go('/reviewer/blind');
        await pumpJourney(t);
        final reset = t.element(find.byType(ReviewerBlindPage)).read<ReviewerBlindBloc>();
        await journeyUntil(t, () => reset.state.pair?.pairId == 'pair_recording_1');
        expect(t.takeException(), isNull);
      });
    }
  }
}
