import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/session/data/dtos/session_dto.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/domain/entities/session_result.dart';
import 'package:qabas/features/session/domain/repositories/session_repository.dart';
import 'package:qabas/features/session/domain/usecases/session_actions.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/repositories/journey_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/fakes.dart';
import 'exercise_flow_test.dart' show until;

void main() {
  late AppDependencies d;
  late MockBackend mock;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final token = MemoryTokens()..value = 'phase12-tests';
    d = await AppDependencies.create(
      config: AppConfig(),
      tokens: token,
      mockFixtures: Fixtures(read: (p) => File(p).readAsString()),
    );
    mock = d.services<MockBackend>();
    mock.controls.fast = true;
    mock.db.tokens.add(token.value!);
    mock.db.user = await mock.fixtures.example('User');
    mock.db.user!['language'] = 'en';
    mock.db.user!['track'] = 'explorer';
  });
  tearDown(() => d.dispose());
  Future<SessionResult> play(Session session, {bool wrong = false}) async {
    final b = d.playerBloc()..add(SessionLoaded(session.sessionId));
    await until(b, () => b.state.session != null);
    for (var i = 0; i < 150 && b.state.status != PlayerStatus.finished; i++) {
      final s = b.state;
      if (s.status == PlayerStatus.feedback) {
        b.add(const FeedbackContinued());
        await until(b, () => b.state.status != PlayerStatus.feedback);
      } else if (s.status == PlayerStatus.retryRound) {
        b.add(const RetryRoundStarted());
        await until(b, () => b.state.inRetry);
      } else if (s.status == PlayerStatus.finishing) {
        await until(b, () => b.state.status == PlayerStatus.finished || b.state.status == PlayerStatus.failure);
      } else if (s.item is ExerciseItem) {
        final e = (s.item as ExerciseItem).exercise!, key = mock.db.sessionKeys[session.sessionId]![e.id] as Map;
        final a = e.type == ExerciseType.flashcard
            ? const RatingAnswer('good')
            : e.type == ExerciseType.reciteVerse
            ? const SkippedAnswer()
            : correctAnswer(e.type, (key['answer_key'] as Map).cast<String, dynamic>())!;
        b.add(AnswerChecked(e.id, wrong && e.timeLimit != null ? const TimeoutAnswer() : a, const Duration(milliseconds: 100)));
        await until(b, () => b.state.item != s.item || b.state.status != s.status || b.state.failure != null);
      } else {
        b.add(StepCompleted(s.item!.blockId));
        await until(b, () => b.state.item != s.item);
      }
      expect(b.state.failure, isNull, reason: '${b.state.item}');
    }
    expect(b.state.status, PlayerStatus.finished);
    final result = b.state.result!;
    await b.close();
    return result;
  }

  test('every served practice type grades through HTTP and finishes with no unsupported renderer', () async {
    final created = await d.services<StartLessonSession>()('les_test_all');
    final start = (created as Ok<SessionStart>).value;
    final exercises = start.session.items.whereType<ExerciseItem>().toList();
    expect(exercises.length, 16);
    expect(exercises.every((e) => e.exercise!.type != ExerciseType.unknown), true);
    final result = await play(start.session);
    expect(result.kind, 'lesson');
    expect(result.percent, 100);
    expect(mock.db.answers.length, 16);
  });
  test('reader shares the demo authored draft-notice filter', () async {
    final readers = d.services<LessonReaderRepository>();
    final draft = (await readers.reader('les_u0_l1') as Ok<LessonReader>).value;
    expect(draft.items.any((i) => i.blockId == 'b_u0_l01_preview_notice'), true);
    mock.controls.hideDraftNotices = true;
    final demo = (await readers.reader('les_u0_l1') as Ok<LessonReader>).value;
    expect(demo.items.any((i) => i.blockId == 'b_u0_l01_preview_notice'), false);
    expect(demo.items.length, draft.items.length - 1);
  });
  test('cards and quick review, rating identities, nullable timeout, empty deck and abandon', () async {
    final flow = d.services<StartSessionFlow>();
    expect(await flow(kind: SessionKind.review, mode: 'cards'), isA<Err<Session>>());
    mock.db.dueReviews = 3;
    final cards = (await flow(kind: SessionKind.review, mode: 'cards') as Ok<Session>).value;
    expect(cards.items.length, 3);
    expect(cards.feedbackMode, FeedbackMode.immediate);
    final result = await play(cards);
    expect(result.kind, 'review');
    expect(mock.db.dueReviews, 0);
    mock.db.dueReviews = 3;
    final quick = (await flow(kind: SessionKind.review, mode: 'quick') as Ok<Session>).value;
    expect(quick.items.every((i) => (i as ExerciseItem).exercise!.timeLimit == const Duration(seconds: 20)), true);
    final timeout = await play(quick, wrong: true);
    expect(timeout.percent, 0);
    mock.db.dueReviews = 1;
    final leave = (await flow(kind: SessionKind.review, mode: 'cards') as Ok<Session>).value;
    expect(await d.services<AbandonSession>()(leave.sessionId), isA<Ok<void>>());
    expect(mock.db.sessions[leave.sessionId]!['status'], 'abandoned');
  });
  for (final language in ['en', 'ar']) {
    for (final track in ['explorer', 'new_muslim']) {
      test('synthetic curriculum, all lessons and assessments $language/$track', () async {
        mock.db.contractCurriculum = true;
        mock.db.user!['track'] = track;
        await d.locale.languageChanged(language);
        final journey = (await d.services<JourneyRepository>().loadJourney() as Ok<Journey>).value;
        for (final unit in journey.units.where((u) => !u.comingSoon)) {
          for (final lesson in unit.lessons) {
            final s = (await d.services<StartLessonSession>()(lesson.lessonId) as Ok<SessionStart>).value.session;
            expect(s.items.whereType<ExerciseItem>().every((e) => e.exercise!.type != ExerciseType.unknown), true);
            await play(s);
            final reader = (await d.services<LessonReaderRepository>().reader(lesson.lessonId) as Ok<LessonReader>).value;
            expect(reader.items.whereType<ExerciseItem>(), isEmpty);
          }
          for (final kind in [SessionKind.pretest, SessionKind.unitTest]) {
            final s = (await d.services<StartSessionFlow>()(kind: kind, unitId: unit.unitId) as Ok<Session>).value;
            expect(s.feedbackMode, kind == SessionKind.pretest ? FeedbackMode.none : FeedbackMode.end);
            final result = await play(s);
            expect(result.reviewItems.length, kind == SessionKind.unitTest ? s.totalExercises : 0);
            final history = await d.services<ApiClient>().get('/sessions/${s.sessionId}', decode: SessionDto.fromJson);
            expect(history.answers.every((a) => a.result == (kind == SessionKind.pretest ? 'hidden' : 'correct')), true);
          }
        }
      });
    }
  }
}
