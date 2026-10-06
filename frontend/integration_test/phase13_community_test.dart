import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/challenges/domain/challenge.dart';
import 'package:qabas/features/challenges/presentation/challenge_bloc.dart';
import 'package:qabas/features/challenges/presentation/challenge_page.dart';
import 'package:qabas/features/community/presentation/community_bloc.dart';
import 'package:qabas/features/community/presentation/community_page.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/profile/presentation/pages/achievements_page.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_actions.dart';
import 'package:qabas/features/raqeeb/domain/raqeeb_media.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'package:qabas/features/raqeeb/presentation/pages/raqeeb_history_page.dart';
import 'package:qabas/features/raqeeb/presentation/pages/raqeeb_page.dart';
import 'package:qabas/shared/domain/entities/media_file.dart';
import 'package:qabas/shared/domain/repositories/media_capture.dart';
import 'support/tour_harness.dart';

final class _FixtureCapture implements MediaCapture {
  _FixtureCapture(this.bytes);
  final List<int> bytes;
  @override
  Future<Result<MediaFile?>> image({bool camera = false}) async =>
      Ok(MediaFile(name: 'test_photo.webp', mime: 'image/webp', kind: MediaKind.image, bytes: bytes));
  @override
  Future<Result<MediaFile?>> document() async =>
      Ok(MediaFile(name: 'test_document.pdf', mime: 'application/pdf', kind: MediaKind.document, bytes: [37, 80, 68, 70]));
  @override
  Future<Result<void>> startRecording() async => const Ok(null);
  @override
  Future<Result<MediaFile>> stopRecording(Duration duration) async =>
      Ok(MediaFile(name: 'test_voice.m4a', mime: 'audio/mp4', kind: MediaKind.audio, bytes: [1, 2, 3], duration: duration));
  @override
  Future<void> cancelRecording() async {}
  @override
  Future<void> openSettings() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const selected = String.fromEnvironment('PHASE13_CASE');
  const communityOnly = bool.fromEnvironment('PHASE13_COMMUNITY_ONLY');
  const groupOnly = bool.fromEnvironment('PHASE13_GROUP_ONLY');
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      if (selected.isNotEmpty && selected != '${language}_${reduced ? 'reduced' : 'motion'}') continue;
      testWidgets('Phase 13 native $language/$reduced', (t) async {
        debugPrint('PHASE13:FRESH');
        final h = await TourHarness.fresh(t, binding, language, reduced, onboarded: true, group: 'community', phase: 'phase13');
        debugPrint('PHASE13:MOUNTED');
        await h.until(() => find.byType(JourneyPage).evaluate().isNotEmpty);
        final router = GoRouter.of(t.element(find.byType(JourneyPage)));
        router.go('/community');
        await h.until(() => find.byType(CommunityPage).evaluate().isNotEmpty);
        final community = t.element(find.byType(CommunityPage)).read<CommunityBloc>();
        await h.until(() => community.state.league != null);
        await h.shot('47_community');
        await t.drag(find.byType(ListView).first, const Offset(0, -360));
        await h.wait();
        await h.shot('48_community_quests');
        if (communityOnly) return;
        unawaited(router.push<void>('/achievements'));
        await h.until(() => find.byType(AchievementsPage).evaluate().isNotEmpty);
        await h.shot('54_achievements');
        router.pop();
        await h.wait();
        final script = await h.mock.fixtures.load('contract/challenges/group_ws_script.json') as List;
        final answers = [
          for (final event in script.cast<Map<String, dynamic>>())
            if (event['type'] == 'question_result') Map<String, dynamic>.from((event['data'] as Map)['correct_answer'] as Map),
        ];
        for (final preset in ['group', 'duel']) {
          unawaited(
            router.push<void>(preset == 'group' ? '/challenge/play?new=group&friends=usr_f1&fill=true' : '/challenge/play?new=duel'),
          );
          await h.until(() => find.byType(ChallengePage).evaluate().isNotEmpty);
          final b = t.element(find.byType(ChallengePage)).read<ChallengeBloc>();
          await h.until(() => b.state.phase == ChallengePhase.countdown);
          if (preset == 'group') await h.shot('49_challenge_countdown', settleMs: 0);
          var index = 0;
          while (b.state.phase != ChallengePhase.results && index < 8) {
            await h.until(
              () => b.state.phase == ChallengePhase.question || b.state.phase == ChallengePhase.results,
              reason: '${b.state.status} ${b.state.failure}',
            );
            if (b.state.phase == ChallengePhase.results) break;
            if (preset == 'group' && index == 0) await h.shot('50_challenge_question');
            final choice = ChallengeChoice(optionId: answers[index % answers.length]['option_id'] as String);
            b.add(ChallengeAnswerSelected(choice));
            await h.until(() => b.state.phase == ChallengePhase.reveal);
            if (preset == 'group' && index == 0) await h.shot('51_challenge_reveal', settleMs: 0);
            if (preset == 'group' && index == 1) {
              await h.mock.challengeSockets.disconnect(b.state.challenge!.id);
              await h.until(() => b.state.status == ChallengeStatus.connected);
              expect(h.mock.challengeSockets.connects, greaterThan(1));
            }
            index++;
            await h.until(() => b.state.phase == ChallengePhase.question || b.state.phase == ChallengePhase.results);
          }
          expect(b.state.phase, ChallengePhase.results);
          expect(b.state.result!.scores.length, preset == 'group' ? 4 : 2);
          if (preset == 'group') {
            await h.shot('52_challenge_results');
            if (groupOnly) return;
          }
          router.pop();
          await h.wait();
        }
        unawaited(router.push<void>('/streak'));
        await h.wait();
        await h.shot('streak_calendar');
        router.pop();
        await h.wait();
        // Device capture is a fixture adapter here; this verifies the native UI/upload/history flow, not OS pickers or acoustic recording.
        await h.d.services.unregister<RaqeebChatBloc>();
        final bytes = (await DefaultAssetBundle.of(
          t.element(find.byType(CommunityPage)),
        ).load('assets/mocks/contract/mock_assets/test/u1l0.webp')).buffer.asUint8List();
        h.d.services.registerFactory<RaqeebChatBloc>(
          () => RaqeebChatBloc(
            start: h.d.services<StartConversation>(),
            open: h.d.services<OpenConversation>(),
            send: h.d.services<SendRaqeebMessage>(),
            watch: h.d.services<WatchAssistantMessage>(),
            rate: h.d.services<RateAnswer>(),
            capture: _FixtureCapture(bytes),
            media: h.d.services<RaqeebMediaActions>(),
          ),
        );
        router.go('/raqeeb');
        await h.until(() => find.byType(RaqeebPage).evaluate().isNotEmpty);
        final chat = t.element(find.byType(RaqeebPage)).read<RaqeebChatBloc>();
        chat.add(const AttachmentPicked(MediaKind.image));
        await h.until(() => chat.state.attachments.length == 1);
        await h.shot('raqeeb_photo_draft');
        chat.add(const MessageSent(''));
        await h.until(() => chat.state.status == ChatStatus.ready && chat.state.turns.isNotEmpty);
        await h.shot('raqeeb_photo_answer');
        unawaited(router.push<void>('/raqeeb/history'));
        await h.until(() => find.byType(RaqeebHistoryPage).evaluate().isNotEmpty);
        await h.shot('raqeeb_history');
        expect(t.takeException(), isNull);
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  }
}
