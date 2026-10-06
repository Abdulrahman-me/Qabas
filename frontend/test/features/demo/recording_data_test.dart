import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/media_resolver.dart';
import 'package:qabas/core/network/multipart_request.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_dto.dart';
import 'package:qabas/features/reviewer/data/reviewer_dtos.dart';
import 'package:qabas/features/reviewer/data/reviewer_repository_impl.dart';
import 'package:qabas/mock_backend/controls/mock_controls.dart';
import 'package:qabas/mock_backend/data/mock_state_store.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/lesson/data/dtos/session_dto.dart';
import 'package:qabas/shared/lesson/data/mappers/session_mappers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../support/fakes.dart';

AppConfig recordingConfig() =>
    AppConfig(flavor: AppFlavor.demo, demoDeveloper: true, recordingDemo: true, hideDraftNotices: true, curiosityOnboarding: false);
Fixtures recordingFixtures() => Fixtures(read: (p) => File(p).readAsString(), recording: true);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('recording is rejected outside the mock demo and release entry is enabled', () {
    expect(() => AppConfig(recordingDemo: true), throwsArgumentError);
    expect(() => AppConfig(judgesDemo: true), throwsArgumentError);
    expect(recordingConfig().developerMenuEnabled(false), true);
    expect(AppConfig(flavor: AppFlavor.demo).developerMenuEnabled(false), false);
    expect(
      () => AppConfig(flavor: AppFlavor.prod, mode: ApiMode.live, baseUrl: 'https://qabas.app/v1', recordingDemo: true),
      throwsArgumentError,
    );
  });
  for (final language in ['en', 'ar']) {
    test('complete $language recording fixtures decode with learner and reviewer renderers', () async {
      final f = recordingFixtures();
      final q = (await f.load('recording/challenges_$language.json') as List).cast<Map<String, dynamic>>();
      final prompts = <String>{};
      for (final e in q.where((e) => e['type'] == 'question')) {
        final exercise = ExerciseHeaderDto.fromJson((e['data'] as Map)['exercise'] as Map<String, dynamic>);
        expect(exercise.type, 'multiple_choice');
        final prompt = jsonEncode(((e['data'] as Map)['exercise'] as Map)['prompt']);
        prompts.add(prompt);
        expect(prompt.contains('سؤال جماعي'), false);
        final options = ((e['data'] as Map)['exercise'] as Map)['payload'] as Map;
        final index = (e['data'] as Map)['question_index'];
        final answer =
            (q.firstWhere((e) => e['type'] == 'question_result' && (e['data'] as Map)['question_index'] == index)['data']
                as Map)['correct_answer'];
        expect((options['options'] as List).any((o) => (o as Map)['option_id'] == (answer as Map)['option_id']), true);
      }
      expect(prompts.length, 7);
      for (final mode in ['cards', 'quick']) {
        final j = await f.object('recording/review_${mode}_$language.json');
        final session = SessionDto.fromJson(j).toEntity();
        expect(session.items, isNotEmpty);
        expect(session.title.contains('اختبارية'), false);
      }
      final pairs = (await f.load('recording/blind_$language.json') as List).cast<Map<String, dynamic>>();
      expect(pairs.length, 3);
      for (final p in pairs) {
        final pair = ReviewBlindPairDto.fromJson(p).toEntity();
        expect(pair.lessonA.items.length, greaterThan(5));
        expect(pair.lessonB.items.length, greaterThan(5));
        expect(jsonEncode(p).contains('Review draft only'), false);
        expect(jsonEncode(p).contains('مسودة للمراجعة فقط'), false);
      }
      final r = ReviewFactoryRunDto.fromJson(await f.object('recording/factory_run.json')).toEntity();
      expect(r.draft!.previews, isNotEmpty);
      expect(r.draft!.visuals, isNotEmpty);
      {
        final visual = (await f.object('recording/factory_run.json'))['draft'] as Map;
        expect(jsonEncode(visual['visuals']).contains('cdn.example.com'), false);
      }
      for (final answer in ['prayer', 'hadith', 'islam', 'arabic', 'other']) {
        final message = AssistantMessageDto.fromJson(await f.object('recording/raqeeb_${answer}_$language.json'));
        expect(message, isNotNull);
      }
    });
  }
  test('recording review cards can be rated through the served session', () async {
    final tokens = MemoryTokens();
    final mock = MockBackend(fixtures: recordingFixtures(), controls: MockControls()..fast = true);
    final api = ApiClient.create(
      config: recordingConfig(),
      tokens: tokens,
      mock: mock,
      platform: 'android',
      language: () => 'en',
      retryDelay: (_) async {},
    );
    final guest = await api.post('/auth/guest', body: {'timezone': 'UTC'}, decode: (j) => j);
    await tokens.write(guest['access_token'] as String);
    final session = await api.post('/sessions', body: {'kind': 'review', 'mode': 'cards'}, decode: (j) => j);
    final exercise = ((session['items'] as List).first as Map)['exercise'] as Map;
    final evaluation = await api.post(
      '/sessions/${session['session_id']}/answers',
      body: {
        'exercise_id': exercise['exercise_id'],
        'answer': {'rating': 'good'},
        'is_retry': false,
        'elapsed_ms': 500,
      },
      decode: (j) => j,
    );
    expect(evaluation['exercise_id'], exercise['exercise_id']);
    expect(evaluation['correct'], true);
    await api.dispose();
    mock.close();
  });
  test('recording learner restores after reviewer login, restart and logout with rotated token', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await PreferencesStore.open();
    final tokens = MemoryTokens();
    final controls = MockControls()..fast = true;
    var mock = MockBackend(fixtures: recordingFixtures(), controls: controls, stateStore: MockStateStore(store));
    ApiClient client() => ApiClient.create(
      config: recordingConfig(),
      tokens: tokens,
      mock: mock,
      platform: 'android',
      language: () => 'en',
      retryDelay: (_) async {},
    );
    var api = client();
    final guest = await api.post('/auth/guest', body: {'timezone': 'UTC'}, decode: (j) => j);
    final learnerToken = guest['access_token'] as String;
    await tokens.write(learnerToken);
    mock.db.user!['onboarding_completed'] = true;
    mock.db.completedLessons.add('les_u0_l1');
    mock.db.dueReviews = 7;
    final learnerId = mock.db.user!['user_id'];
    var reviewer = ReviewerRepositoryImpl(api, tokens);
    expect(await reviewer.signInSample(), isA<Err>());
    expect(mock.db.user!['role'], 'learner');
    reviewer = ReviewerRepositoryImpl(api, tokens, sampleEnabled: true);
    expect(await reviewer.signInSample(), isA<Ok>());
    expect(mock.db.user!['role'], 'reviewer');
    expect(mock.db.suspendedLearner, isNotNull);
    expect(mock.db.tokens.contains(learnerToken), false);
    expect(store.string('mock_server')!.contains(learnerToken), false);
    await api.dispose();
    mock.close();
    mock = MockBackend(fixtures: recordingFixtures(), controls: controls, stateStore: MockStateStore(store));
    api = client();
    reviewer = ReviewerRepositoryImpl(api, tokens);
    expect(await reviewer.signOut(), isA<Ok>());
    final restored = await api.post('/auth/guest', body: {'timezone': 'UTC'}, decode: (j) => j);
    expect((restored['user'] as Map)['user_id'], learnerId);
    expect((restored['user'] as Map)['onboarding_completed'], true);
    expect(restored['access_token'], isNot(learnerToken));
    expect(mock.db.completedLessons, contains('les_u0_l1'));
    expect(mock.db.dueReviews, 7);
    await api.dispose();
    mock.close();
  });
  test('blind pairs advance, language matches, reset refills and gate content retains blockers', () async {
    final tokens = MemoryTokens();
    final controls = MockControls()..fast = true;
    final mock = MockBackend(fixtures: recordingFixtures(), controls: controls);
    final api = ApiClient.create(
      config: recordingConfig(),
      tokens: tokens,
      mock: mock,
      platform: 'web',
      language: () => 'en',
      retryDelay: (_) async {},
    );
    final reviewer = ReviewerRepositoryImpl(api, tokens);
    await reviewer.signIn('reviewer@qabas.app', 'qabas-review');
    for (var i = 1; i <= 3; i++) {
      final p = await api.get('/admin/blind-test/next', decode: (j) => j);
      expect(p['pair_id'], 'pair_recording_$i');
      await api.postNoContent(
        '/admin/blind-test/${p['pair_id']}',
        body: {'clearer': 'a', 'more_accurate': 'same', 'guessed_handwritten': 'unsure'},
      );
    }
    expect(await reviewer.blindPair(), isA<Ok>().having((r) => r.value, 'exhaustion', isNull));
    controls.reviewerReset++;
    expect((await api.get('/admin/blind-test/next', decode: (j) => j))['pair_id'], 'pair_recording_1');
    final run = await api.get('/admin/factory/runs/run_recording', decode: (j) => j);
    expect((run['qa_report'] as Map)['issues'], isNotEmpty);
    expect(run['review_digest'], isNotNull);
    await api.dispose();
    mock.close();
  });
  test('suggestion selection and original image survive the transport and persisted history', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await PreferencesStore.open();
    final tokens = MemoryTokens();
    final f = recordingFixtures();
    final mock = MockBackend(
      fixtures: f,
      controls: MockControls()
        ..fast = true
        ..raqeebOutcome = 'auto',
      stateStore: MockStateStore(store),
    );
    final api = ApiClient.create(
      config: recordingConfig(),
      tokens: tokens,
      mock: mock,
      platform: 'web',
      language: () => 'en',
      retryDelay: (_) async {},
    );
    final g = await api.post('/auth/guest', body: {'timezone': 'UTC'}, decode: (j) => j);
    await tokens.write(g['access_token'] as String);
    final conv = await api.post('/raqeeb/conversations', body: {'context': null}, decode: (j) => j);
    final bytes = await File('assets/mocks/contract/mock_assets/test/u1l0.webp').readAsBytes();
    final sent = await api.postMultipart(
      '/raqeeb/conversations/${conv['conversation_id']}/messages',
      form: MultipartRequest(
        fields: {'text': 'What does the word “Islam” mean?'},
        files: [UploadPart(field: 'images', filename: 'original.webp', mimeType: 'image/webp', bytes: bytes)],
      ),
      idempotencyKey: const Uuid().v4(),
      decode: (j) => j,
    );
    final url = (((sent['user_message'] as Map)['attachments'] as List).first as Map)['url'] as String;
    expect((MediaResolver(recordingConfig()).resolve(url) as MemoryMedia).bytes, bytes);
    expect(() => MediaResolver(AppConfig()).resolve(url), throwsFormatException);
    final id = (sent['assistant_message'] as Map)['message_id'];
    Map<String, dynamic> message = {};
    for (var i = 0; i < 9; i++) {
      message = await api.get('/raqeeb/messages/$id', decode: (j) => j);
    }
    expect(jsonEncode(message).contains('willing submission'), true);
    expect(store.string('mock_server'), contains(url));
    await api.dispose();
    mock.close();
  });
}
