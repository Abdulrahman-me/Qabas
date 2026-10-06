import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/repositories/session_repository.dart';
import 'package:qabas/features/session/domain/usecases/session_actions.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/steps/content_step_bloc.dart';

import 'session_data_test.dart' show lesson;

class FakeSessions implements SessionRepository {
  FakeSessions(this.session);
  final Session session;
  Future<Result<Session>> Function()? read;
  int loads = 0;
  @override
  Future<Result<Session>> load(String id) async {
    loads++;
    return read == null ? Ok(session) : read!();
  }

  @override
  Future<Result<SessionStart>> startLesson(String id) async =>
      Ok(SessionStart(session: session, resumed: false, info: const LessonEntryInfo(unitIndex: 2, lessonIndex: 1, minutes: 5, xp: 20)));
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
void main() {
  final session = lesson('assets/mocks/salah/session_salah_en_explorer.json');
  test('local prediction: selection, gold feedback, immutable progress, no server answer', () async {
    final repo = FakeSessions(session), player = SessionPlayerBloc(LoadSession(FakeSessions(session)));
    player.add(SessionLoaded(session.sessionId));
    await tick();
    player.add(StepCompleted(session.items.first.blockId));
    await tick();
    final prediction = session.items[1] as PredictItem;
    final step = PredictStepBloc(prediction);
    expect(step.cta.enabled, false);
    step.add(const CtaPressed());
    await tick();
    expect(step.state.status, ContentStepStatus.ready);
    step.add(PredictionOptionPicked(prediction.options.last.optionId));
    await tick();
    expect(step.cta.enabled, true);
    step.add(const CtaPressed());
    await tick();
    expect(step.state.intent, StepIntent.predictionChecked);
    expect(step.state.status, ContentStepStatus.feedback);
    player.add(PredictionChecked(prediction.blockId));
    await tick();
    expect(player.state.progress, 2 / 14);
    expect(player.state.cursor, 1);
    step.add(const CtaPressed());
    await tick();
    player.add(StepCompleted(prediction.blockId));
    await tick();
    expect(player.state.cursor, 2);
    expect(player.state.progress, 2 / 14);
    expect(repo.loads, 0);
    expect(() => player.state.completedStepIds.clear(), throwsUnsupportedError);
    await step.close();
    await player.close();
  });
  test('story beats and teach reveals are one top-level step; summary starts fully shown', () async {
    final story = StoryStepBloc(session.items.whereType<StoryItem>().single);
    for (var i = 0; i < 3; i++) {
      story.add(const CtaPressed());
      await tick();
      expect(story.state.beat, i + 1);
      expect(story.state.intent, StepIntent.none);
    }
    story.add(const CtaPressed());
    await tick();
    expect(story.state.intent, StepIntent.completed);
    final teach = TeachStepBloc(session.items.whereType<TeachItem>().first);
    expect(teach.state.shown, 1);
    teach.add(const AllTeachPointsShown());
    await tick();
    expect(teach.state.shown, (teach.item as TeachItem).points.length);
    final summary = TeachStepBloc(session.items.whereType<TeachItem>().last);
    expect(summary.state.shown, (summary.item as TeachItem).points.length);
    await story.close();
    await teach.close();
    await summary.close();
  });
  test('content tour ends as preview; placeholders do not earn graded progress', () async {
    final player = SessionPlayerBloc(LoadSession(FakeSessions(session)))..add(SessionLoaded(session.sessionId));
    await tick();
    while (player.state.status != PlayerStatus.previewEnded) {
      final item = player.state.item!;
      player.add(item is ExerciseItem ? ExercisePlaceholderContinued(item.blockId) : StepCompleted(item.blockId));
      await tick();
    }
    expect(player.state.progress, 7 / 14);
    expect(player.state.completedStepIds.length, 7);
    await player.close();
  });
  test('load failure, retry and quitting a stalled read; disposal suppresses late emissions', () async {
    final repo = FakeSessions(session)..read = () async => const Err(NetworkFailure());
    final player = SessionPlayerBloc(LoadSession(repo))..add(SessionLoaded(session.sessionId));
    await tick();
    expect(player.state.status, PlayerStatus.failure);
    repo.read = null;
    player.add(const SessionLoadRetried());
    await tick();
    expect(player.state.status, PlayerStatus.playing);
    final stalled = Completer<Result<Session>>();
    repo.read = () => stalled.future;
    player.add(const SessionLoadRetried());
    await tick();
    player.add(const QuitConfirmed());
    await tick();
    stalled.complete(Ok(session));
    await tick();
    expect(player.state.status, PlayerStatus.left);
    await player.close();
  });
}
