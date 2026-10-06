import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/session/data/datasources/session_remote_data_source.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/logic/session_recovery.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/exercises/exercise_views.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';

import 'phase12_learning_test.dart' show play, selectAnswer, step;
import 'support/tour_harness.dart';

// The host terminates the process after PHASE12_KILL_READY, then drives the same
// installed binary again. The second run reads real preferences and secure storage.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real process termination restores the pinned feedback and spends one retry', (t) async {
    final store = await PreferencesStore.open();
    // Host control is separate from the persisted app state under test. Never
    // silently seed again if recovery lost its preferences.
    final seedRequest = File('${Directory.systemTemp.path}/phase12_resume_seed');
    if (await seedRequest.exists()) {
      await seedRequest.delete();
      final h = await TourHarness.fresh(t, binding, 'en', false, onboarded: true, group: 'resume', phase: 'phase12');
      await h.until(() => find.byType(JourneyPage).evaluate().isNotEmpty);
      final router = GoRouter.of(t.element(find.byType(JourneyPage)));
      router.go('/lesson/les_u0_l1/intro');
      await h.until(() => find.byKey(const ValueKey('lesson-start')).evaluate().isNotEmpty);
      await h.tap('lesson-start');
      await h.until(() => find.byType(SessionPlayerPage).evaluate().isNotEmpty && h.player.state.session != null);
      while (h.player.state.item is! ExerciseItem) {
        final state = h.player.state;
        if (state.item is PredictItem && state.status != PlayerStatus.feedback) await h.tap('predict-option-1');
        await h.tap(state.item is PredictItem && state.status == PlayerStatus.feedback ? 'predict-continue' : 'step-cta');
      }
      final item = h.player.state.item as ExerciseItem, session = h.player.state.session!;
      final key = h.mock.db.sessionKeys[session.sessionId]![item.exerciseId] as Map;
      final right = (key['answer_key'] as Map)['option_id'];
      final wrong = (item.exercise!.payload as ChoicePayload).options.firstWhere((o) => o.id != right).id;
      await selectAnswer(h, OptionAnswer(wrong));
      await h.until(() => h.player.state.status == PlayerStatus.feedback);
      await h.shot('before_kill');
      await h.d.services<SessionCheckpointStore>().read(session.sessionId, session.lessonVersion);
      await store.setString('phase12_resume_id', session.sessionId);
      await store.setString('phase12_resume_block', item.blockId);
      await store.setString('phase12_resume_wrong', wrong);
      await store.setString('phase12_resume_stage', 'ready');
      debugPrint('PHASE12_KILL_READY');
      // Individual frames keep the host responsive while awaiting its termination.
      for (var n = 0; n < 600; n++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      fail('The host did not terminate the app after the saved checkpoint.');
    } else {
      expect(store.string('phase12_resume_stage'), 'ready');
      final d = await AppDependencies.create(
        config: AppConfig.fromEnvironment(appVersion: '1.0.0'),
        store: store,
        initialSessionState: const AppSessionState(status: SessionStatus.ready, splashElapsed: true),
      );
      d.services<MockBackend>().controls.fast = true;
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        await d.dispose();
      });
      final h = TourHarness(t, binding, d, 'resume/en_motion', phase: 'phase12');
      await t.pumpWidget(QabasApp(dependencies: d));
      await h.until(() => find.byType(JourneyPage).evaluate().isNotEmpty);
      final router = GoRouter.of(t.element(find.byType(JourneyPage)));
      router.go('/lesson/les_u0_l1/intro');
      await h.until(() => find.byKey(const ValueKey('lesson-start')).evaluate().isNotEmpty);
      await h.tap('lesson-start');
      await h.until(() => find.byType(SessionPlayerPage).evaluate().isNotEmpty && h.player.state.status == PlayerStatus.feedback);
      expect(h.player.state.session!.sessionId, store.string('phase12_resume_id'));
      expect(h.player.state.item!.blockId, store.string('phase12_resume_block'));
      expect(h.player.state.answer, OptionAnswer(store.string('phase12_resume_wrong')!));
      expect(h.player.state.evaluation!.correct, false);
      expect(h.player.state.retryQueue, hasLength(1));
      expect(h.player.state.predictions, isNotEmpty);
      expect(h.mock.db.answers, hasLength(1));
      await h.shot('after_kill');
      await h.tap('feedback-continue');
      await play(h);
      final sessionId = store.string('phase12_resume_id')!;
      expect((h.mock.db.sessions[sessionId]!['answers'] as List).cast<Map>().where((a) => a['is_retry'] == true), hasLength(1));
      await h.shot('resumed_complete');
      // Check the final geographic hit handling in a real native image view.
      // Serve a valid one-exercise projection of the immutable practice snapshot.
      // Set up the projection before the production repository caches it.
      final practice = (await SessionRemoteDataSource(d.services<ApiClient>()).start('les_test_all')).session;
      final row = h.mock.db.sessions[practice.sessionId]!;
      row['items'] = (row['items'] as List)
          .cast<Map>()
          .where((item) => item['type'] == 'exercise' && ((item['exercise'] as Map)['payload'] as Map)['presentation'] == 'map_pins')
          .toList();
      row['counts'] = {'interactions': 1, 'exercises': 1, 'scored': 1};
      row['total_exercises'] = 1;
      expect(row['items'], hasLength(1));
      router.go('/session/${practice.sessionId}');
      await h.until(
        () =>
            find.byType(SessionPlayerPage).evaluate().isNotEmpty &&
            find.byType(ExerciseBody).evaluate().length == 1 &&
            h.player.state.session?.sessionId == practice.sessionId &&
            step(h).state.mapAvailable,
      );
      final map = (h.player.state.item as ExerciseItem).exercise!.payload as MapPayload;
      for (final pin in map.pins) {
        await t.tapAt(t.getCenter(h.key('pin-${pin.id}')));
        await h.wait();
        expect(step(h).state.draft.toPayload(), PinAnswer(pin.id));
      }
      await h.shot('map_centres');
      h.player.add(const QuitConfirmed());
      await h.until(() => find.byType(JourneyPage).evaluate().isNotEmpty);
      await store.setString('phase12_resume_stage', 'passed');
      debugPrint('PHASE12_COLD_RESUME_PASSED');
    }
  });
}
