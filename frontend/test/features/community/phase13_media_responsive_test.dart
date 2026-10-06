import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'package:qabas/features/raqeeb/presentation/pages/raqeeb_page.dart';
import 'package:qabas/features/session/domain/entities/recitation.dart';
import 'package:qabas/features/session/presentation/exercises/exercise_views.dart';
import 'package:qabas/features/session/presentation/steps/exercise_step_bloc.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/domain/entities/media_file.dart';
import 'package:qabas/shared/domain/repositories/media_capture.dart';
import '../../support/memory_media_capture.dart';
import '../journey/journey_responsive_test.dart' show mountJourney, pumpJourney, journeyUntil, journeySizes;
import '../session/exercise_responsive_test.dart' show playerBloc;

void main() {
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Media drafts, failed upload retry and recitation feedback survive resize $language/$reduced', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(402, 874);
        t.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mountJourney(t, locale: language, reduced: reduced);
        addTearDown(() => t.runAsync(d.dispose));
        try {
          final mock = d.services<MockBackend>();
          await t.runAsync(() async {
            await mock.fixtures.object('examples/RaqeebCompleted__get_raqeeb_messages_message_id__3.json');
          });
          await d.services.unregister<MediaCapture>();
          d.services.registerFactory<MediaCapture>(MemoryCapture.new);
          final router = GoRouter.of(t.element(find.byKey(const ValueKey('nav-0'))));
          router.go('/raqeeb');
          await pumpJourney(t);
          final chat = t.element(find.byType(RaqeebPage)).read<RaqeebChatBloc>();
          for (var i = 0; i < 3; i++) {
            chat.add(const AttachmentPicked(MediaKind.image));
            await journeyUntil(t, () => chat.state.attachments.length == i + 1);
          }
          chat.add(const AttachmentPicked(MediaKind.image));
          await pumpJourney(t);
          expect(chat.state.failure, isA<MediaLimitFailure>());
          chat.add(const AttachmentPicked(MediaKind.document));
          await journeyUntil(t, () => chat.state.attachments.length == 4);
          chat.add(const VoiceRecordingStarted());
          await journeyUntil(t, () => chat.state.mediaStatus == MediaComposerStatus.recording);
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump();
            expect(t.takeException(), isNull, reason: 'recording $size');
          }
          chat.add(const VoiceRecordingStopped());
          await journeyUntil(t, () => chat.state.attachments.length == 5);
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump();
            expect(t.takeException(), isNull, reason: 'media composer $size');
          }
          // Offline prevents creation before acceptance. The retry keeps the original upload identity and media bytes.
          mock.controls.offline = true;
          chat.add(const MessageSent(''));
          await journeyUntil(t, () => chat.state.status == ChatStatus.failure);
          final turn = chat.state.turns.single;
          expect(turn.files.length, 5);
          mock.controls.offline = false;
          chat.add(RetryRequested(turn.key));
          await journeyUntil(
            t,
            () => chat.state.turns.single.user != null,
            diagnostic: () => '${chat.state.status} ${chat.state.failure} ${chat.state.turns.single.failure} ${mock.lastRequest?.path}',
          );
          expect(chat.state.turns.single.key, turn.key);
          expect(chat.state.turns.single.user!.attachments.length, 5);
          for (var wait = 0; wait < 240 && chat.state.busy; wait++) {
            await t.pump(const Duration(milliseconds: 100));
            await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
          }
          expect(
            chat.state.busy,
            false,
            reason: '${chat.state.status} ${chat.state.mediaStatus} ${mock.db.raqeebWork.values.map((w) => w["polls"])}',
          );
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump();
            expect(t.takeException(), isNull, reason: 'media bubbles $size');
          }
          Map<String, dynamic>? session, exercise;
          await t.runAsync(() async {
            session = await mock.fixtures.example('Session');
            exercise = await mock.fixtures.object('contract/exercises/recite_verse/exercise.json');
            for (final outcome in ['errors', 'passed', 'unclear']) {
              await mock.fixtures.object('contract/recitation/check_$outcome.json');
            }
          });
          final id = 'ses_media_${language}_$reduced';
          session!.addAll({
            'session_id': id,
            'status': 'active',
            'items': [
              {'type': 'exercise', 'block_id': 'recite', 'exercise': exercise},
            ],
            'answers': <Object>[],
            'total_exercises': 1,
            'answered_exercises': 0,
            'counts': {'interactions': 1, 'exercises': 1, 'scored': 0},
          });
          mock.db.sessions[id] = session!;
          mock.db.sessionKeys[id] = {
            exercise!['exercise_id'] as String: {
              'answer_key': {'skipped': true},
              'explanation': exercise!['prompt'],
              'source_ids': <Object>[],
            },
          };
          router.go('/session/$id');
          await journeyUntil(t, () => find.byType(ExerciseBody).evaluate().isNotEmpty && playerBloc(t).state.session?.sessionId == id);
          final b = t.element(find.byType(ExerciseBody)).read<ExerciseStepBloc>();
          for (final outcome in ['unclear', 'busy', 'errors', 'missing_extra', 'passed']) {
            mock.controls.recitationOutcome = outcome;
            b.add(const RecitationRecordPressed());
            await journeyUntil(t, () => b.state.recitationStatus == RecitationStatus.recording);
            for (final size in journeySizes) {
              t.view.physicalSize = size;
              await t.pump();
              expect(t.takeException(), isNull, reason: 'recitation recording $size');
            }
            b.add(const RecitationRecordingStopped());
            await journeyUntil(
              t,
              () => [RecitationStatus.unclear, RecitationStatus.failure, RecitationStatus.evaluated].contains(b.state.recitationStatus),
            );
            for (final size in journeySizes) {
              t.view.physicalSize = size;
              await t.pump();
              expect(t.takeException(), isNull, reason: 'recitation $outcome $size');
            }
            if (outcome == 'passed') expect(b.state.draft.isComplete, true);
          }
          await t.pumpWidget(const SizedBox.shrink());

          await pumpJourney(t);
        } catch (error, stack) {
          // ignore: avoid_print
          print('PHASE13_MEDIA_FAILURE: $error\n$stack');
          rethrow;
        }
      });
    }
  }
}
