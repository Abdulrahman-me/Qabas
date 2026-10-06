import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/app/presentation/home_shell.dart';
import 'package:qabas/app/presentation/placeholder_page.dart';
import 'package:qabas/app/router/routes.dart';
import 'package:qabas/app/router/transitions.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/locale_cubit.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/auth/presentation/pages/session_ended_page.dart';
import 'package:qabas/features/auth/presentation/pages/splash_page.dart';
import 'package:qabas/features/challenges/domain/challenge.dart';
import 'package:qabas/features/challenges/presentation/challenge_bloc.dart';
import 'package:qabas/features/challenges/presentation/challenge_lobby_bloc.dart';
import 'package:qabas/features/challenges/presentation/challenge_page.dart';
import 'package:qabas/features/community/presentation/community_bloc.dart';
import 'package:qabas/features/community/presentation/community_page.dart';
import 'package:qabas/features/dev_tools/presentation/bloc/dev_tools_bloc.dart';
import 'package:qabas/features/dev_tools/presentation/component_gallery.dart';
import 'package:qabas/features/dev_tools/presentation/pages/dev_tools_page.dart';
import 'package:qabas/features/discover/presentation/bloc/discover_bloc.dart';
import 'package:qabas/features/discover/presentation/pages/discover_page.dart';
import 'package:qabas/features/glossary/presentation/glossary_bloc.dart';
import 'package:qabas/features/glossary/presentation/glossary_page.dart';
import 'package:qabas/features/journey/presentation/bloc/journey_bloc.dart';
import 'package:qabas/features/journey/presentation/pages/journey_page.dart';
import 'package:qabas/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:qabas/features/profile/presentation/bloc/preferences_cubit.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_extras_bloc.dart';
import 'package:qabas/features/profile/presentation/bloc/settings_bloc.dart';
import 'package:qabas/features/profile/presentation/pages/about_page.dart';
import 'package:qabas/features/profile/presentation/pages/achievements_page.dart';
import 'package:qabas/features/profile/presentation/pages/profile_page.dart';
import 'package:qabas/features/profile/presentation/pages/settings_page.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_chat_bloc.dart';
import 'package:qabas/features/raqeeb/presentation/bloc/raqeeb_history_bloc.dart';
import 'package:qabas/features/raqeeb/presentation/pages/raqeeb_history_page.dart';
import 'package:qabas/features/raqeeb/presentation/pages/raqeeb_page.dart';
import 'package:qabas/features/reviewer/domain/reviewer_content.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_auth_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_blind_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_dashboard_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_detail_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_login_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_metrics_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_bloc.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_runs_page.dart';
import 'package:qabas/features/reviewer/presentation/reviewer_shell.dart';
import 'package:qabas/features/session/domain/entities/session.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_intro_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/lesson_reader_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_player_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_result_bloc.dart';
import 'package:qabas/features/session/presentation/bloc/session_start_bloc.dart';
import 'package:qabas/features/session/presentation/pages/lesson_intro_page.dart';
import 'package:qabas/features/session/presentation/pages/lesson_reader_page.dart';
import 'package:qabas/features/session/presentation/pages/session_player_page.dart';
import 'package:qabas/features/session/presentation/pages/session_result_page.dart';
import 'package:qabas/features/session/presentation/pages/session_start_page.dart';
import 'package:qabas/features/streak/presentation/bloc/streak_bloc.dart';
import 'package:qabas/features/streak/presentation/pages/streak_page.dart';
import 'package:qabas/features/unit_guide/presentation/unit_guide_bloc.dart';
import 'package:qabas/features/unit_guide/presentation/unit_guide_sheet.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'package:qabas/shared/lesson/presentation/lesson_preview.dart';
import 'package:qabas/shared/presentation/content/content_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

final class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<Object?> _subscription;
  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

String? sessionRedirect(SessionStatus status, String path, {required bool developerEnabled}) {
  if (developerEnabled && [Routes.developer, Routes.gallery].contains(path)) return null;
  final destination = switch (status) {
    SessionStatus.unknown || SessionStatus.authenticating || SessionStatus.failure => Routes.splash,
    SessionStatus.needsOnboarding => Routes.welcome,
    SessionStatus.sessionEnded => Routes.sessionEnded,
    SessionStatus.outdated => Routes.outdated,
    SessionStatus.ready =>
      [Routes.splash, Routes.welcome, Routes.sessionEnded, Routes.outdated, '/'].contains(path) ? Routes.journey : path,
  };
  return path == destination ? null : destination;
}

GoRouter createRouter(AppDependencies dependencies, RouterRefresh refresh, GallerySettings gallery) {
  final developer = dependencies.config.developerMenuEnabled(kDebugMode);
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (_, state) {
      final session = dependencies.session.state;
      final path = state.uri.path;
      if (path == '/reviewer/login' && session.status != SessionStatus.outdated) return null;
      if (path.startsWith('/reviewer/') &&
          [SessionStatus.ready, SessionStatus.needsOnboarding].contains(session.status) &&
          session.user?.role != UserRole.reviewer) {
        return session.status == SessionStatus.ready ? Routes.journey : Routes.welcome;
      }
      if (session.status == SessionStatus.ready &&
          session.user?.role == UserRole.reviewer &&
          !path.startsWith('/reviewer/') &&
          !(developer && [Routes.developer, Routes.gallery].contains(path))) {
        return '/reviewer/runs';
      }
      // Reviewer sign-in can complete without mounting the learner splash.
      if (session.status == SessionStatus.ready && session.user?.role == UserRole.reviewer && path.startsWith('/reviewer/')) {
        return null;
      }
      if (!session.splashElapsed &&
          [SessionStatus.ready, SessionStatus.needsOnboarding].contains(session.status) &&
          !(developer && [Routes.developer, Routes.gallery].contains(state.uri.path))) {
        return state.uri.path == Routes.splash ? null : Routes.splash;
      }
      return sessionRedirect(session.status, state.uri.path, developerEnabled: developer);
    },
    routes: [
      GoRoute(
        path: '/reviewer/login',
        pageBuilder: (_, state) => fadeThrough(
          state,
          BlocBuilder<AppSessionBloc, AppSessionState>(
            builder: (c, s) => [SessionStatus.unknown, SessionStatus.authenticating].contains(s.status)
                ? const Scaffold(body: QLoadingView())
                : BlocProvider(
                    create: (_) => dependencies.reviewerAuthBloc(),
                    child: ReviewerLoginPage(
                      sampleEnabled: dependencies.config.judgesDemo,
                      accountNote: dependencies.config.isLive(LiveGroup.reviewer),
                      onSignedIn: (user) {
                        dependencies.session.add(UserProfileReceived(user));
                        c.go('/reviewer/runs');
                      },
                    ),
                  ),
          ),
        ),
      ),
      ShellRoute(
        builder: (c, state, child) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => dependencies.reviewerAuthBloc()),
            BlocProvider(create: (_) => dependencies.reviewerContentBloc()),
          ],
          child: BlocConsumer<ReviewerAuthBloc, ReviewerAuthState>(
            listener: (c, s) {
              if (s.status == ReviewerAuthStatus.signedOut) {
                dependencies.session.add(const AppStarted());
                c.go(Routes.splash);
              }
            },
            builder: (c, s) => ReviewerShell(
              onLanguageChanged: dependencies.locale.languageChanged,
              onDeveloperOpened: developer ? () => c.push(Routes.developer) : null,
              onSignOut: () => c.read<ReviewerAuthBloc>().add(const ReviewerSignedOut()),
              child: child,
            ),
          ),
        ),
        routes: [
          for (final detail in [false, true])
            GoRoute(
              path: detail ? '/reviewer/runs/:runId' : '/reviewer/runs',
              pageBuilder: (routeContext, state) => fadeThrough(
                state,
                BlocProvider(
                  create: (_) => dependencies.reviewerRunsBloc()..add(const RunsOpened()),
                  child: ReviewerRunsPage(
                    detail: !detail
                        ? null
                        : BlocProvider(
                            key: ValueKey(state.pathParameters['runId']),
                            create: (_) => dependencies.reviewerDetailBloc()..add(RunOpened(state.pathParameters['runId']!)),
                            child: ReviewerDetailPage(
                              runId: state.pathParameters['runId']!,
                              previewBuilder: (draft, preview) => Localizations.override(
                                context: routeContext,
                                locale: Locale(preview.language),
                                child: Theme(
                                  data: QTheme.light(arabic: preview.language == 'ar'),
                                  child: Directionality(
                                    textDirection: preview.language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                                    child: BlocProvider(
                                      create: (_) =>
                                          dependencies.reviewerContentBloc()
                                            ..add(ContentReceived(reviewerTerms(draft, preview.language), reviewerSources(draft))),
                                      child: LessonPreview(
                                        items: preview.items,
                                        objectives: preview.objectives,
                                        completion: preview.completion,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          GoRoute(
            path: '/reviewer/blind',
            pageBuilder: (_, state) => fadeThrough(
              state,
              BlocProvider(
                create: (_) => dependencies.reviewerBlindBloc()..add(const BlindOpened()),
                child: BlocListener<LocaleCubit, LocaleState>(
                  listenWhen: (a, b) => a.language != b.language,
                  listener: (c, _) => c.read<ReviewerBlindBloc>().add(const BlindOpened()),
                  child: ReviewerBlindPage(
                    previewBuilder: (lesson) => BlocProvider(
                      create: (_) => dependencies.reviewerContentBloc(),
                      child: LessonPreview(items: lesson.items, objectives: lesson.objectives, completion: lesson.completion),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/reviewer/metrics',
            pageBuilder: (_, state) => fadeThrough(
              state,
              BlocProvider(
                create: (_) => dependencies.reviewerMetricsBloc()..add(const MetricsOpened()),
                child: const ReviewerMetricsPage(),
              ),
            ),
          ),
        ],
      ),

      GoRoute(
        path: Routes.splash,
        pageBuilder: (_, state) => fadeThrough(state, SplashPage(warmup: dependencies.warmUp())),
      ),
      GoRoute(
        path: Routes.welcome,
        pageBuilder: (_, state) => fadeThrough(
          state,
          BlocProvider(
            create: (_) => dependencies.onboardingBloc(),
            child: OnboardingPageView(
              onCompleted: (user) {
                dependencies.preferences.onboardingPreferencesReloaded();
                dependencies.session.add(UserProfileReceived(user));
              },
            ),
          ),
        ),
      ),
      GoRoute(path: Routes.sessionEnded, pageBuilder: (_, state) => fadeThrough(state, const SessionEndedPage())),
      GoRoute(
        path: Routes.outdated,
        pageBuilder: (_, state) => fadeThrough(
          state,
          Scaffold(
            body: QBlockingScreen(
              onUpdate: () {
                final config = dependencies.config;
                final url = kIsWeb
                    ? config.webUpdateUrl
                    : defaultTargetPlatform == TargetPlatform.iOS
                    ? config.iosStoreUrl
                    : config.androidStoreUrl;
                if (url.isNotEmpty) unawaited(launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
              },
            ),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, shell) => fadeThrough(state, HomeShell(shell: shell)),
        branches: [
          for (final entry in [Routes.journey, Routes.discover, Routes.raqeeb, Routes.community, Routes.profile].asMap().entries)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: entry.value,
                  builder: (_, _) => switch (entry.key) {
                    0 => BlocProvider(
                      create: (_) => dependencies.journeyBloc()..add(const JourneyOpened()),
                      child: BlocListener<LocaleCubit, LocaleState>(
                        listenWhen: (a, b) => a.language != b.language,
                        listener: (context, _) => context.read<JourneyBloc>().add(const JourneyRefreshed()),
                        child: const JourneyPage(),
                      ),
                    ),
                    1 => BlocProvider(
                      create: (_) => dependencies.discoverBloc()..add(const DiscoverOpened()),
                      child: BlocListener<LocaleCubit, LocaleState>(
                        listenWhen: (a, b) => a.language != b.language,
                        listener: (context, _) => context.read<DiscoverBloc>().add(const DiscoverRefreshed()),
                        child: const DiscoverPage(),
                      ),
                    ),
                    2 => MultiBlocProvider(
                      providers: [
                        BlocProvider(create: (_) => dependencies.contentBloc()),
                        BlocProvider(create: (_) => dependencies.raqeebBloc()),
                      ],
                      child: const RaqeebPage(),
                    ),
                    3 => MultiBlocProvider(
                      providers: [
                        BlocProvider(create: (_) => dependencies.communityBloc()..add(const CommunityOpened())),
                        BlocProvider(create: (_) => dependencies.friendsBloc()..add(const FriendsOpened())),
                      ],
                      child: BlocListener<LocaleCubit, LocaleState>(
                        listenWhen: (a, b) => a.language != b.language,
                        listener: (c, _) {
                          c.read<CommunityBloc>().add(const CommunityOpened());
                          c.read<FriendsBloc>().add(const FriendsOpened());
                        },
                        child: const CommunityPage(),
                      ),
                    ),
                    4 => BlocProvider(
                      create: (_) => dependencies.profileBloc()..add(const ProfileOpened()),
                      child: BlocListener<LocaleCubit, LocaleState>(
                        listenWhen: (a, b) => a.language != b.language,
                        listener: (context, _) => context.read<ProfileBloc>().add(const ProfileOpened()),
                        child: ProfilePage(
                          developerEnabled: developer,
                          reviewerSampleEnabled: dependencies.config.judgesDemo,
                          reviewerSignInEnabled: dependencies.config.isLive(LiveGroup.reviewer),
                        ),
                      ),
                    ),
                    _ => PlaceholderPage(index: entry.key, developerEnabled: developer),
                  },
                ),
              ],
            ),
        ],
      ),
      for (final path in ['/challenge', '/challenge/invitations'])
        GoRoute(
          path: path,
          pageBuilder: (_, state) => fadeThrough(
            state,
            BlocProvider(
              create: (_) => dependencies.challengeLobbyBloc()..add(ChallengeLobbyOpened(friend: state.uri.queryParameters['friend'])),
              child: ChallengeLobbyPage(invitationsOnly: path.endsWith('invitations')),
            ),
          ),
        ),
      GoRoute(
        path: '/challenge/play',
        pageBuilder: (_, state) => fadeThrough(
          state,
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => dependencies.contentBloc()),
              BlocProvider(
                create: (_) {
                  final bloc = dependencies.challengeBloc(), q = state.uri.queryParameters;
                  if (q['id'] != null) {
                    bloc.add(ChallengeOpened(q['id']!, accept: q['accept'] == 'true'));
                  } else {
                    bloc.add(
                      ChallengeStarted(
                        preset: q['new'] == 'group' ? ChallengePreset.group : ChallengePreset.duel,
                        friends: q['friends']?.split(',').where((id) => id.isNotEmpty).toList() ?? [],
                        botFill: q['fill'] == 'true',
                      ),
                    );
                  }
                  return bloc;
                },
              ),
            ],
            child: const ChallengePage(),
          ),
        ),
      ),
      GoRoute(
        path: Routes.settings,
        pageBuilder: (_, state) => fadeThrough(
          state,
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => dependencies.settingsBloc()..add(const SettingsOpened())),
              BlocProvider(create: (_) => dependencies.accountDeletionBloc()),
            ],
            child: const SettingsPage(),
          ),
        ),
      ),
      GoRoute(path: Routes.about, pageBuilder: (_, state) => fadeThrough(state, const AboutPage())),
      GoRoute(
        path: Routes.glossary,
        pageBuilder: (_, state) => fadeThrough(
          state,
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => dependencies.glossaryBloc()..add(const GlossaryOpened())),
              BlocProvider(create: (_) => dependencies.contentBloc()),
            ],
            child: BlocListener<LocaleCubit, LocaleState>(
              listenWhen: (a, b) => a.language != b.language,
              listener: (c, _) => c.read<GlossaryBloc>().add(const GlossaryOpened()),
              child: const GlossaryPage(),
            ),
          ),
        ),
      ),
      GoRoute(
        path: Routes.achievements,
        pageBuilder: (context, state) => fadeThrough(
          state,
          BlocProvider(create: (_) => dependencies.achievementsBloc()..add(const AchievementsOpened()), child: const AchievementsPage()),
        ),
      ),
      GoRoute(
        path: '/raqeeb/history',
        pageBuilder: (_, state) => fadeThrough(
          state,
          BlocProvider(create: (_) => dependencies.raqeebHistoryBloc()..add(const RaqeebHistoryOpened()), child: const RaqeebHistoryPage()),
        ),
      ),
      GoRoute(
        path: '/raqeeb/c/:conversationId',
        pageBuilder: (_, state) => fadeThrough(
          state,
          MultiBlocProvider(
            key: ValueKey(state.pathParameters['conversationId']),
            providers: [
              BlocProvider(create: (_) => dependencies.contentBloc()),
              BlocProvider(create: (_) => dependencies.raqeebBloc()..add(ConversationOpened(state.pathParameters['conversationId']!))),
            ],
            child: RaqeebPage(conversationId: state.pathParameters['conversationId']),
          ),
        ),
      ),
      GoRoute(
        path: '/reader/:lessonId',
        pageBuilder: (_, state) => fadeThrough(
          state,
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => dependencies.readerBloc()..add(ReaderOpened(state.pathParameters['lessonId']!))),
              BlocProvider(create: (_) => dependencies.contentBloc()),
            ],
            child: LessonReaderPage(lessonId: state.pathParameters['lessonId']!),
          ),
        ),
      ),
      GoRoute(
        path: '/lesson/:lessonId/intro',
        pageBuilder: (context, state) => fadeThrough(
          state,
          MultiBlocProvider(
            key: ValueKey(state.pathParameters['lessonId']),
            providers: [
              BlocProvider(create: (_) => dependencies.contentBloc()),
              BlocProvider(create: (_) => dependencies.lessonIntroBloc()..add(LessonIntroOpened(state.pathParameters['lessonId']!))),
            ],
            child: const LessonIntroPage(),
          ),
          fromBottom: true,
        ),
      ),
      GoRoute(
        path: '/session/:sessionId',
        pageBuilder: (_, state) => fadeThrough(
          state,
          MultiBlocProvider(
            key: ValueKey(state.pathParameters['sessionId']),
            providers: [
              BlocProvider(create: (_) => dependencies.contentBloc()),
              BlocProvider(create: (_) => dependencies.playerBloc()..add(SessionLoaded(state.pathParameters['sessionId']!))),
            ],
            child: SessionPlayerPage(createExerciseBloc: dependencies.exerciseBloc),
          ),
        ),
      ),
      GoRoute(
        path: '/session/:sessionId/result',
        pageBuilder: (_, state) => fadeThrough(
          state,
          MultiBlocProvider(
            key: ValueKey(state.pathParameters['sessionId']),
            providers: [
              BlocProvider(create: (_) => dependencies.contentBloc()),
              BlocProvider(create: (_) => dependencies.resultBloc()..add(SessionResultOpened(state.pathParameters['sessionId']!))),
            ],
            child: const SessionResultPage(),
          ),
        ),
      ),
      for (final assessment in [('pretest', SessionKind.pretest), ('test', SessionKind.unitTest)])
        GoRoute(
          path: '/units/:unitId/${assessment.$1}',
          pageBuilder: (_, state) {
            final request = SessionStartRequested(kind: assessment.$2, unitId: state.pathParameters['unitId']);
            return fadeThrough(
              state,
              BlocProvider(
                create: (_) => dependencies.sessionStartBloc()..add(request),
                child: SessionStartPage(request: request),
              ),
            );
          },
        ),
      GoRoute(
        path: '/units/:unitId/guide',
        pageBuilder: (context, state) => QSheetPage<void>(
          key: state.pageKey,
          barrierLabel: context.l10n.commonClose,
          reduceMotion: context.reduceMotion,
          child: SafeArea(
            bottom: false,
            child: MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => dependencies.unitGuideBloc()..add(UnitGuideOpened(state.pathParameters['unitId']!))),
                BlocProvider(create: (_) => dependencies.contentBloc()),
              ],
              child: UnitGuideSheetPage(unitId: state.pathParameters['unitId']!),
            ),
          ),
        ),
      ),
      GoRoute(
        path: Routes.review,
        pageBuilder: (_, state) {
          final request = SessionStartRequested(
            kind: SessionKind.review,
            mode: state.uri.queryParameters['mode'] == 'quick' ? 'quick' : 'cards',
          );
          return fadeThrough(
            state,
            BlocProvider(
              create: (_) => dependencies.sessionStartBloc()..add(request),
              child: SessionStartPage(request: request),
            ),
          );
        },
      ),
      GoRoute(
        path: Routes.streak,
        pageBuilder: (_, state) => fadeThrough(
          state,
          BlocProvider(
            create: (_) => dependencies.streakBloc()..add(StreakOpened(celebrate: state.uri.queryParameters['celebrate'] == '1')),
            child: const StreakPage(),
          ),
        ),
      ),
      if (developer) ...[
        GoRoute(
          path: Routes.gallery,
          pageBuilder: (context, state) => fadeThrough(
            state,
            ComponentGallery(
              settings: gallery,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(Routes.developer);
                }
              },
            ),
          ),
        ),
        GoRoute(
          path: Routes.developer,
          pageBuilder: (_, state) => fadeThrough(
            state,
            BlocProvider(
              create: (_) => dependencies.developerBloc()..add(const DevToolsOpened()),
              child: _DeveloperComposition(dependencies: dependencies),
            ),
          ),
        ),
      ],
    ],
  );
}

class _DeveloperComposition extends StatelessWidget {
  const _DeveloperComposition({required this.dependencies});
  final AppDependencies dependencies;
  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleCubit>(), preferences = context.watch<PreferencesCubit>();
    return DevToolsPage(
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.profile);
        }
      },
      language: locale.state.language,
      onLanguageChanged: locale.languageChanged,
      preferences: preferences.state.value,
      onPreferencesChanged: preferences.preferencesChanged,
      characterIds: dependencies.registry.specs.keys.toList(),
      onCastingChanged: (id) =>
          dependencies.characters.settingsChanged(overrides: {...dependencies.characters.state.overrides, CharacterRole.guide: id}),
      onGateReset: () {
        dependencies.session.add(const AppStarted());
        context.go(Routes.splash);
      },
      onLocalReset: () async {
        await preferences.localPreferencesCleared();
        await locale.languageChanged('en');
        await dependencies.characters.settingsChanged(enabled: true, overrides: {});
      },
    );
  }
}
