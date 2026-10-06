import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/features/challenges/domain/challenge.dart';
import 'package:qabas/features/challenges/presentation/challenge_bloc.dart';
import 'package:qabas/features/challenges/presentation/challenge_lobby_bloc.dart';
import 'package:qabas/features/challenges/presentation/challenge_page.dart';
import 'package:qabas/features/community/presentation/community_bloc.dart';
import 'package:qabas/features/community/presentation/community_page.dart';
import 'package:qabas/features/profile/domain/profile_extras.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_extras_bloc.dart';
import 'package:qabas/features/profile/presentation/pages/account_deletion_sheet.dart';
import 'package:qabas/features/profile/presentation/pages/achievements_page.dart';
import 'package:qabas/features/raqeeb/presentation/pages/raqeeb_history_page.dart';
import 'package:qabas/features/streak/presentation/pages/streak_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';

import '../journey/journey_responsive_test.dart' show mountJourney, pumpJourney, journeyUntil, journeySizes;

void main() {
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Phase 13 community, invites, achievements, calendar, history and live match resize $language/$reduced', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(402, 874);
        t.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mountJourney(t, locale: language, reduced: reduced);
        final mock = d.services<MockBackend>();
        await t.runAsync(() async {
          for (final model in ['League', 'Quests', 'Page[Friend]', 'Invite', 'Page[Invitation]', 'Duel', 'Achievements']) {
            await mock.fixtures.example(model);
          }
          await mock.fixtures.object('contract/challenges/group_challenge.json');
          await mock.fixtures.load('contract/challenges/group_ws_script.json');
        });
        final router = GoRouter.of(t.element(find.byKey(const ValueKey('nav-0'))));
        router.go('/community');
        await pumpJourney(t);
        final community = t.element(find.byType(CommunityPage)).read<CommunityBloc>();
        await journeyUntil(t, () => community.state.league != null, diagnostic: () => '${community.state.leagueFailure}');
        expect(community.state.quests, isNotNull);
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull, reason: 'community $size');
        }
        expect(t.element(find.byType(CommunityPage)).read<CommunityBloc>(), same(community));
        mock.db.noLeague = true;
        community.add(const CommunityOpened());
        await journeyUntil(t, () => community.state.noLeague);
        expect(t.takeException(), isNull);
        mock.db.noLeague = false;
        community.add(const CommunityOpened());
        await pumpJourney(t);
        final communityContext = t.element(find.byType(CommunityPage));
        final friends = communityContext.read<FriendsBloc>()..add(const InviteCreated());
        unawaited(
          showQSheet<void>(
            communityContext,
            builder: (_) => BlocProvider.value(value: friends, child: const InviteSheet()),
          ),
        );
        await journeyUntil(t, () => friends.state.invite != null);
        await pumpJourney(t);
        await t.enterText(find.descendant(of: find.byType(InviteSheet), matching: find.byType(TextField)), 'INVALID');
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull, reason: 'invite sheet $size');
          expect(find.text('INVALID'), findsOneWidget);
        }
        friends.add(const InviteAccepted('INVALID'));
        await journeyUntil(t, () => friends.state.failure != null);
        expect(find.byType(InviteSheet), findsOneWidget);
        router.pop();
        await pumpJourney(t);
        final deletion = AccountDeletionBloc(d.services<ProfileExtrasActions>());
        unawaited(
          showQSheet<void>(
            communityContext,
            builder: (_) => BlocProvider.value(value: deletion, child: const AccountDeletionSheet()),
          ),
        );
        await pumpJourney(t);
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull, reason: 'delete sheet $size');
        }
        mock.controls.offline = true;
        deletion.add(const AccountDeletionConfirmed());
        await journeyUntil(t, () => deletion.state.status == AccountDeletionStatus.failure);
        expect(find.byType(QInlineError), findsOneWidget);
        expect(mock.db.user, isNotNull);
        mock.controls.offline = false;
        router.pop();
        await pumpJourney(t);
        await deletion.close();
        for (final route in ['/achievements', '/streak', '/raqeeb/history', '/challenge/invitations', '/challenge']) {
          unawaited(router.push<void>(route));
          await pumpJourney(t);
          for (final size in journeySizes) {
            t.view.physicalSize = size;
            await t.pump();
            expect(t.takeException(), isNull, reason: '$route $size');
          }
          if (route == '/achievements') expect(find.byType(AchievementsPage), findsOneWidget);
          if (route == '/streak') expect(find.byType(StreakPage), findsOneWidget);
          if (route == '/raqeeb/history') expect(find.byType(RaqeebHistoryPage), findsOneWidget);
          if (route == '/challenge') {
            final lobby = t.element(find.byType(ChallengeLobbyPage)).read<ChallengeLobbyBloc>();
            lobby.add(ChallengeFriendSelected(lobby.state.friends.first.id));
            await t.pump();
            t.view.physicalSize = const Size(320, 400);
            await t.pump();
            expect(lobby.state.selected, isNotEmpty);
          }
          router.pop();
          await pumpJourney(t);
        }
        t.view.physicalSize = const Size(402, 874);
        unawaited(router.push<void>('/challenge/play?new=group&friends=usr_f1&fill=true'));
        await t.pump();
        await journeyUntil(t, () => find.byType(ChallengePage).evaluate().isNotEmpty);
        final b = t.element(find.byType(ChallengePage)).read<ChallengeBloc>();
        await journeyUntil(
          t,
          () => b.state.phase == ChallengePhase.countdown || b.state.phase == ChallengePhase.question,
          diagnostic: () => '${b.state.status} ${b.state.failure}',
        );
        final seen = <ChallengePhase>{};
        for (var attempt = 0; attempt < 100 && b.state.phase != ChallengePhase.results; attempt++) {
          final phase = b.state.phase;
          if (seen.add(phase) && phase != ChallengePhase.lobby) {
            for (final size in journeySizes) {
              t.view.physicalSize = size;
              await t.pump();
              expect(t.takeException(), isNull, reason: '$phase $size');
            }
          }
          if (b.state.phase == ChallengePhase.question && b.state.answer == null) {
            b.add(ChallengeAnswerSelected(b.state.question!.options.first.choice));
          }
          await t.pump(const Duration(milliseconds: 200));
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        }
        expect(b.state.phase, ChallengePhase.results, reason: '${b.state.status} ${b.state.failure}');
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull, reason: 'results $size');
        }
        expect(b.state.result!.scores.length, 4);
        await t.pumpWidget(const SizedBox.shrink());
        await t.runAsync(d.dispose);
        await pumpJourney(t);
      });
    }
  }
}
