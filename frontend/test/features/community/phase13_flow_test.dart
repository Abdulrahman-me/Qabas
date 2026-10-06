import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/duel_socket.dart';
import 'package:qabas/core/network/idempotency_key.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/challenges/data/challenge_dto.dart';
import 'package:qabas/features/challenges/domain/challenge.dart';
import 'package:qabas/features/challenges/presentation/challenge_bloc.dart';
import 'package:qabas/features/community/domain/community.dart';
import 'package:qabas/features/community/presentation/community_bloc.dart';
import 'package:qabas/features/profile/domain/profile_extras.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_media.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_repository.dart';
import 'package:qabas/features/session/data/dtos/recitation_dto.dart';
import 'package:qabas/features/session/data/dtos/session_dto.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/data/repositories/recitation_repository_impl.dart';
import 'package:qabas/features/session/domain/entities/exercise.dart';
import 'package:qabas/features/session/domain/entities/recitation.dart';
import 'package:qabas/features/session/domain/logic/answer_drafts.dart';
import 'package:qabas/features/session/presentation/steps/exercise_step_bloc.dart';
import 'package:qabas/mock_backend/data/mock_state_store.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/handlers/mock_activity.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/mock_backend/mock_db.dart';
import 'package:qabas/shared/domain/entities/content.dart';
import 'package:qabas/shared/domain/entities/media_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';
import '../../support/memory_media_capture.dart';

Future<void> eventually(bool Function() ready, {Duration timeout = const Duration(seconds: 4)}) async {
  final end = DateTime.now().add(timeout);
  while (!ready() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(ready(), true);
}

void main() {
  late AppDependencies d;
  late MockBackend mock;
  late MemoryTokens tokens;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tokens = MemoryTokens()..value = 'phase13-test';
    d = await AppDependencies.create(
      config: AppConfig(),
      tokens: tokens,
      mockFixtures: Fixtures(read: (p) => File(p).readAsString()),
    );
    mock = d.services<MockBackend>();
    mock.controls.fast = true;
    mock.db.tokens.add(tokens.value!);
    mock.db.user = await mock.fixtures.example('User');
    await seedMockActivity(mock.db, mock.fixtures);
  });
  tearDown(() => d.dispose());

  test('league, quests, no league, friends accept/conflict/remove and reset', () async {
    final c = d.communityBloc()..add(const CommunityOpened());
    await eventually(() => c.state.status == CommunityStatus.ready);
    expect(c.state.league!.members, isNotEmpty);
    expect(c.state.quests!.items, isNotEmpty);
    expect(c.state.invitations, greaterThan(0));
    mock.db.noLeague = true;
    c.add(const CommunityOpened());
    await eventually(() => c.state.noLeague);
    final actions = d.services<CommunityActions>();
    final before = (await actions.friends() as Ok<List<Friend>>).value;
    final invite = (await actions.invite() as Ok<FriendInvite>).value;
    expect(invite.shareText, contains(invite.code));
    final friend = (await actions.accept(' ${invite.code.toLowerCase()} ') as Ok<Friend>).value;
    expect((await actions.friends() as Ok<List<Friend>>).value.length, before.length + 1);
    expect(await actions.accept(invite.code), isA<Err<Friend>>());
    expect(await actions.remove(friend.id), isA<Ok<void>>());
    d.services<AppEventBus>().publish(const GuestSessionCleared());
    await eventually(() => c.state.status == CommunityStatus.initial);
    await c.close();
  });

  test('every supplied group socket event decodes into pure typed state', () async {
    final script = await mock.fixtures.load('contract/challenges/group_ws_script.json') as List;
    for (final event in script.cast<Map<String, dynamic>>()) {
      expect(
        decodeChallengeEvent(WsEvent(type: event['type'] as String, data: Map<String, dynamic>.from(event['data'] as Map))),
        isA<ChallengeUpdate>(),
      );
    }
    final verse = await mock.fixtures.object('contract/exercises/verse_meaning/exercise.json');
    final question = challengeQuestion({
      'question_index': 0,
      'total': 3,
      'exercise': verse,
      'issued_at': '2026-10-06T08:00:00Z',
      'deadline_at': '2026-10-06T08:00:10Z',
    });
    expect(question.verse, isA<QuranEvidence>());
    expect(question.options, isNotEmpty);
  });

  for (final preset in ChallengePreset.values) {
    test('full ${preset.name}: questions, locked answer, fresh-ticket reconnect, reveal and ranks', () async {
      final actions = d.services<ChallengeActions>();
      final friends = (await actions.friends() as Ok<List<ChallengeInvitee>>).value;
      final b = d.challengeBloc();
      final questions = <int>{}, reveals = <int>{};
      final phases = <ChallengePhase>{};
      var dropped = false;
      final sub = b.stream.listen((s) {
        phases.add(s.phase);
        if (s.phase == ChallengePhase.reveal) reveals.add(s.reveal!.index);
        if (s.phase == ChallengePhase.question && s.question != null && s.status == ChallengeStatus.connected) {
          if (questions.add(s.question!.index)) {
            b.add(ChallengeAnswerSelected(s.question!.options.first.choice));
          }
          if (preset == ChallengePreset.group && !dropped && s.locked) {
            dropped = true;
            unawaited(mock.challengeSockets.disconnect(s.challenge!.id));
          }
        }
      });
      b.add(
        ChallengeStarted(
          preset: preset,
          friends: preset == ChallengePreset.group ? [friends.first.id] : [],
          botFill: preset == ChallengePreset.group,
        ),
      );
      // The real countdown and seven reveal windows already take about 24 seconds;
      // leave room for scheduling when the full widget suite runs concurrently.
      await eventually(() => b.state.phase == ChallengePhase.results, timeout: const Duration(seconds: 60));
      expect(b.state.failure, isNull, reason: '${b.state.failure}');
      expect(questions.length, preset == ChallengePreset.group ? 3 : 7);
      expect(reveals.length, questions.length);
      expect(phases, containsAll([ChallengePhase.countdown, ChallengePhase.question, ChallengePhase.reveal, ChallengePhase.results]));
      expect(b.state.result!.scores.length, preset == ChallengePreset.group ? 4 : 2);
      expect(b.state.summary.length, questions.length);
      expect(b.state.result!.xp, anyOf(4, 8, 15));
      if (preset == ChallengePreset.group) {
        expect(dropped, true);
        expect(mock.challengeSockets.connects, 2);
      }
      final fresh = (await actions.get(b.state.challenge!.id) as Ok<Challenge>).value;
      expect(fresh.result, b.state.result);
      final socket = await mock.challengeSockets.connect(fresh.wsUrl);
      final subscription = socket.events.listen((_) {});
      await expectLater(mock.challengeSockets.connect(fresh.wsUrl), throwsA(isA<Exception>()));
      await socket.close();
      await subscription.cancel();
      await sub.cancel();
      await b.close();
    }, timeout: const Timeout(Duration(seconds: 90)));
  }

  test('recitation permission denied, all check outcomes, explicit accept and skip, demo unavailable', () async {
    final json = await mock.fixtures.object('contract/exercises/recite_verse/exercise.json');
    final exercise = ExerciseHeaderDto.fromJson(json).toEntity();
    mock.db.sessions['recite-session'] = {
      'items': [
        {'type': 'exercise', 'exercise': json},
      ],
    };
    final capture = MemoryCapture()..permission = const Err(MicrophoneDeniedFailure());
    final repo = RecitationRepositoryImpl(d.services<ApiClient>(), enabled: true);
    final b = ExerciseStepBloc(exercise, capture: capture, recitation: repo);
    b.add(const RecitationRecordPressed());
    await eventually(() => b.state.recitationStatus == RecitationStatus.failure);
    expect(b.state.recitationFailure, isA<MicrophoneDeniedFailure>());
    capture.permission = const Ok(null);
    for (final outcome in ['unclear', 'busy', 'errors', 'missing_extra', 'passed']) {
      mock.controls.recitationOutcome = outcome;
      b.add(const RecitationRecordPressed());
      await eventually(() => b.state.recitationStatus == RecitationStatus.recording);
      b.add(const RecitationRecordingStopped());
      await eventually(
        () => [RecitationStatus.unclear, RecitationStatus.failure, RecitationStatus.evaluated].contains(b.state.recitationStatus),
      );
      if (outcome == 'busy') {
        expect(b.state.recitationFailure, isA<UpstreamUnavailableFailure>());
      }
      if (outcome == 'unclear') {
        expect(b.state.check!.unclear, true);
        expect(b.state.draft.isComplete, false);
      }
      if (outcome == 'errors') {
        expect(b.state.check!.words.any((w) => w.result == RecitationWordResult.substituted), true);
        expect(b.state.draft.isComplete, false);
        b.add(const RecitationAccepted());
        await eventually(() => b.state.draft.isComplete);
      }
      if (outcome == 'missing_extra') {
        expect(b.state.check!.words.map((w) => w.result), containsAll([RecitationWordResult.missing, RecitationWordResult.extra]));
      }
      if (outcome == 'passed') {
        expect(b.state.draft, isA<RecitationDraft>());
        expect(b.state.draft.isComplete, true);
      }
    }
    b.add(const RecitationSkipped());
    await eventually(() => (b.state.draft as RecitationDraft).skipped);
    expect(b.state.check, isNull);
    await b.close();
    final demoCapture = MemoryCapture();
    final demo = ExerciseStepBloc(
      exercise,
      capture: demoCapture,
      recitation: RecitationRepositoryImpl(d.services<ApiClient>(), enabled: false),
    );
    demo.add(const RecitationRecordPressed());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(demo.state.recitationStatus, RecitationStatus.unavailable);
    expect(demoCapture.starts, 0);
    await demo.close();
    for (final fixture in ['passed', 'errors', 'unclear']) {
      expect(
        RecitationCheckDto.fromJson(await mock.fixtures.object('contract/recitation/check_$fixture.json')).toEntity(),
        isA<RecitationCheck>(),
      );
    }
  });

  test('recitation binds owner, verse, range and expected text; check/answer/finish replay grants 3 XP once', () async {
    final api = d.services<ApiClient>();
    final raw = await api.post(
      '/sessions',
      body: const SessionCreateDto(lessonId: 'les_test_all').toJson(),
      decode: (j) => j,
    );
    final id = raw['session_id'] as String;
    final exerciseJson = await mock.fixtures.object('contract/exercises/recite_verse/exercise.json');
    final exercise = ExerciseHeaderDto.fromJson(exerciseJson).toEntity();
    final session = mock.db.sessions[id]!;
    session['items'] = [
      {'type': 'exercise', 'exercise': exerciseJson},
    ];
    session['total_exercises'] = 1;
    mock.db.sessionKeys[id] = {
      exercise.id: {'answer_key': null},
    };
    mock.controls.recitationOutcome = 'passed';
    final repository = RecitationRepositoryImpl(api, enabled: true);
    final audio = MediaFile(
      name: 'verse.m4a',
      mime: 'audio/mp4',
      kind: MediaKind.audio,
      bytes: [1, 2, 3],
      duration: const Duration(seconds: 2),
    );
    final key = repository.newActionId();
    final check = (await repository.check(exercise, audio, key) as Ok<RecitationCheck>).value;
    expect((await repository.check(exercise, audio, key) as Ok<RecitationCheck>).value.id, check.id);
    expect(mock.db.checks.length, 1);
    final stored = mock.db.checks[check.id]!;
    Future<Result<Map<String, dynamic>>> submit() => guard(
      () => api.post(
        '/sessions/$id/answers',
        body: {
          'exercise_id': exercise.id,
          'answer': {'check_id': check.id},
          'elapsed_ms': 2000,
          'is_retry': false,
        },
        decode: (j) => j,
      ),
    );
    for (final mutation in <String, Object>{
      'user_id': 'another-user',
      'surah': 1,
      'ayah': 2,
      'word_start': 2,
      'word_end': 3,
      'expected_digest': 'different-text',
    }.entries) {
      final original = stored[mutation.key];
      stored[mutation.key] = mutation.value;
      final result = await submit();
      expect((result as Err<Map<String, dynamic>>).failure, ConflictFailure('recitation_check_mismatch'));
      expect(mock.db.answers, isEmpty);
      stored[mutation.key] = original;
    }
    final answer = (await submit() as Ok<Map<String, dynamic>>).value;
    expect(answer['xp_awarded'], 3);
    expect((await submit() as Ok<Map<String, dynamic>>).value, answer);
    expect((session['answers'] as List).length, 1);
    final first = await api.post('/sessions/$id/finish', body: {'duration_ms': 2000}, decode: (j) => j);
    final xp = mock.db.stats!['xp_total'];
    final repeat = await api.post('/sessions/$id/finish', body: {'duration_ms': 2000}, decode: (j) => j);
    expect(repeat, first);
    expect(mock.db.stats!['xp_total'], xp);
    expect((first['xp'] as Map)['breakdown'], contains(equals({'reason': 'recitation_passed', 'xp': 3})));
    expect((first['score'] as Map)['total'], 0);
    expect((exercise.payload as RecitePayload).surah, 112);
  });

  test('media-only image/document/audio upload, stable idempotency, history and restart', () async {
    final r = d.services<RaqeebRepository>();
    final conversation = (await r.start(r.newActionId()) as Ok<Conversation>).value;
    final files = [
      MediaFile(name: 'photo.png', mime: 'image/png', kind: MediaKind.image, bytes: [1, 2, 3]),
      MediaFile(name: 'book.pdf', mime: 'application/pdf', kind: MediaKind.document, bytes: [4, 5, 6]),
      MediaFile(name: 'voice.m4a', mime: 'audio/mp4', kind: MediaKind.audio, bytes: [7, 8, 9], duration: const Duration(seconds: 2)),
    ];
    final media = d.services<RaqeebMediaActions>();
    final key = newIdempotencyKey();
    final first = (await media.send(conversation.conversationId, '', files, key) as Ok<PostMessageResponse>).value;
    final repeat = (await media.send(conversation.conversationId, '', files, key) as Ok<PostMessageResponse>).value;
    expect(repeat.userMessage.messageId, first.userMessage.messageId);
    expect(first.userMessage.attachments.length, 3);
    expect(first.userMessage.text, isNull);
    expect((await media.history(null) as Ok<ConversationPage>).value.items.single.id, conversation.conversationId);
    final store = MockStateStore(d.services<PreferencesStore>());
    await store.save(mock.db);
    final restored = MockDb();
    store.restore(restored);
    expect(restored.conversations.keys, contains(conversation.conversationId));
    expect(restored.raqeebWork, isNotEmpty);
    expect(restored.raqeebMessages.length, 2);
    expect(
      validateMedia(
        MediaFile(name: 'long.m4a', mime: 'audio/mp4', kind: MediaKind.audio, bytes: [1], duration: const Duration(seconds: 61)),
      ),
      isA<MediaLimitFailure>(),
    );
  });

  test('delete account revokes server auth, clears token/preferences and publishes reset once', () async {
    final store = d.services<PreferencesStore>();
    final actions = d.services<ProfileExtrasActions>();
    final challenges = d.services<ChallengeActions>();
    final duel = (await challenges.create(ChallengePreset.duel, const [], false) as Ok<Challenge>).value;
    final connection = (await challenges.connect(duel) as Ok<ChallengeConnection>).value;
    var closed = false;
    final socketSubscription = connection.events.listen((_) {}, onDone: () => closed = true);
    connection.ready();
    await store.setString('language', 'ar');
    var resets = 0;
    final sub = d.services<AppEventBus>().on<GuestSessionCleared>().listen((_) {
      resets++;
    });
    expect(await actions.deleteAccount(), isA<Ok<void>>());
    await eventually(() => resets == 1);
    await eventually(() => closed);
    expect(tokens.value, isNot('phase13-test'));
    expect(store.string('language'), 'en');
    expect(mock.db.user?['user_id'], isNot('usr_7f3k2a'));
    expect(mock.db.tokens, isNot(contains('phase13-test')));

    expect(mock.db.conversations, isEmpty);
    // The same repository must delete a newly created guest after an earlier successful deletion.
    await eventually(() => d.session.state.status == SessionStatus.needsOnboarding && tokens.value != null);
    final secondToken = tokens.value!;
    expect(await actions.deleteAccount(), isA<Ok<void>>());
    await eventually(() => resets == 2);
    expect(mock.db.tokens, isNot(contains(secondToken)));
    await sub.cancel();
    await socketSubscription.cancel();
  });
}
