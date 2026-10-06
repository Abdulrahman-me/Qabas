import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/features/session/presentation/pages/session_result_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';

/// Drives the actual player/answer/finish flow, retaining ordinary route listeners.
Future<void> playSession(
  WidgetTester tester,
  AppDependencies d,
  Future<void> Function(bool Function()) until, {
  bool wrongFirstUnderstanding = false,
}) async {
  final bloc = tester.element(find.byType(SessionPlayerPage)).read<SessionPlayerBloc>();
  final backend = d.services<MockBackend>();
  await until(() => bloc.state.status == PlayerStatus.playing);
  var missed = false;
  for (var i = 0; i < 150 && bloc.state.status != PlayerStatus.finished; i++) {
    final state = bloc.state;
    if (state.status == PlayerStatus.feedback) {
      if (state.item is ExerciseItem) {
        bloc.add(const FeedbackContinued());
      } else {
        bloc.add(StepCompleted(state.item!.blockId));
      }
      await until(() => bloc.state.status != PlayerStatus.feedback);
    } else if (state.status == PlayerStatus.finishing) {
      await until(() => bloc.state.status == PlayerStatus.finished);
    } else if (state.status == PlayerStatus.retryRound) {
      bloc.add(const RetryRoundStarted());
      await until(() => bloc.state.inRetry);
    } else if (state.item case final ExerciseItem item) {
      final key = backend.db.sessionKeys[state.session!.sessionId]![item.exerciseId] as Map;
      var answer = item.exerciseType == 'recite_verse'
          ? const SkippedAnswer()
          : correctAnswer(item.exercise!.type, Map<String, dynamic>.from(key['answer_key'] as Map))!;
      if (wrongFirstUnderstanding &&
          !missed &&
          !state.inRetry &&
          item.exercise!.scoring.layer == 'understand' &&
          item.exercise!.payload is ChoicePayload) {
        final options = (item.exercise!.payload as ChoicePayload).options;
        answer = OptionAnswer(options.firstWhere((o) => o.id != (answer as OptionAnswer).optionId).id);
        missed = true;
      }
      bloc.add(AnswerChecked(item.exerciseId, answer, Duration.zero));
      await until(() => bloc.state.status != PlayerStatus.playing || bloc.state.item?.blockId != item.blockId);
    } else if (state.item case final SessionItem item) {
      if (item is PredictItem) {
        bloc.add(PredictionChecked(item.blockId));
        await until(() => bloc.state.status == PlayerStatus.feedback);
      } else {
        bloc.add(StepCompleted(item.blockId));
        await until(() => bloc.state.item?.blockId != item.blockId);
      }
    } else {
      throw StateError('Unexpected player state: ${state.status}');
    }
  }
  expect(bloc.state.status, PlayerStatus.finished);
  await until(() => find.byType(SessionResultPage).evaluate().isNotEmpty);
}
