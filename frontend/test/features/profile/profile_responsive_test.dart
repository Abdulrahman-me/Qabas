import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/l10n/locale_cubit.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/features/glossary/presentation/glossary_page.dart';
import 'package:qabas/features/profile/presentation/bloc/preferences_cubit.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:qabas/features/profile/presentation/bloc/settings_bloc.dart';
import 'package:qabas/features/profile/presentation/pages/about_page.dart';
import 'package:qabas/features/profile/presentation/pages/profile_page.dart';
import 'package:qabas/features/profile/presentation/pages/settings_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/mock_backend/mock_router.dart';
import 'package:qabas/shared/content/bundled_scripture.dart';

import '../journey/journey_responsive_test.dart' show mountJourney, pumpJourney, journeyUntil, journeySizes;

Future<void> activate(WidgetTester t, String key) async {
  final finder = find.byKey(ValueKey(key));
  await t.ensureVisible(finder);
  await t.pump();
  await t.tap(finder);
  await pumpJourney(t);
}

class _ApprovedCopy extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async => jsonEncode({
    'question': {'en': 'What would you most like to understand?', 'ar': null},
    'anchors': [
      for (final key in ['does_god_exist', 'who_is_god', 'quran_special', 'who_was_muhammad', 'muslim_beliefs', 'why_pray'])
        {
          'goal_anchor': key,
          'label': {'en': key, 'ar': null},
        },
    ],
  });
  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

void main() {
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Profile/settings/about, name, preferences, rollback and retained resize $language/$reduced', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(402, 874);
        t.platformDispatcher.textScaleFactorTestValue = 1.35;
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final d = await mountJourney(t, locale: language, reduced: reduced, profileCopyBundle: _ApprovedCopy());
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
          await t.runAsync(d.dispose);
        });
        final mock = d.services<MockBackend>();
        await t.runAsync(() async {
          await mock.fixtures.example('Achievements');
          await mock.fixtures.example('Page[TermCard]');
        });
        final router = GoRouter.of(t.element(find.byType(Scaffold).first));
        router.go('/profile');
        await pumpJourney(t);
        final bloc = t.element(find.byType(ProfilePage)).read<ProfileBloc>();
        await journeyUntil(t, () => bloc.state.snapshot != null, diagnostic: () => '${bloc.state.failure}');
        final data = bloc.state.snapshot;
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull, reason: 'profile/$size');
          expect(t.element(find.byType(ProfilePage)).read<ProfileBloc>(), same(bloc));
          expect(bloc.state.snapshot, same(data));
        }
        t.view.physicalSize = const Size(320, 400);
        await t.pump();
        await activate(t, 'profile-name');
        await t.enterText(find.byKey(const ValueKey('profile-name-input')), 'Noura');
        await t.pump();
        t.view.viewInsets = const FakeViewPadding(bottom: 150);
        await t.pump();
        addTearDown(t.view.resetViewInsets);
        for (final size in [const Size(320, 400), const Size(600, 400), const Size(1440, 900)]) {
          t.view.physicalSize = size;
          await t.pump();
          expect(t.takeException(), isNull);
          expect(t.widget<TextField>(find.byKey(const ValueKey('profile-name-input'))).controller!.text, 'Noura');
        }
        t.view.viewInsets = const FakeViewPadding();
        await t.pump();
        await activate(t, 'profile-name-save');
        await journeyUntil(t, () => bloc.state.snapshot!.user.displayName == 'Noura');
        expect(find.byKey(const ValueKey('profile-name-input')), findsNothing);
        // Both entries open their named future-phase destination, and leave the mounted Profile intact.
        final context = t.element(find.byType(ProfilePage));
        final wordsHeader = find.byWidgetPredicate((w) => w is SectionHeader && w.title == context.l10n.reviewYourWords);
        final wordAction = find.descendant(of: wordsHeader, matching: find.byType(Pressable));
        await t.ensureVisible(wordAction);
        await t.pump();
        await t.tap(wordAction);
        await pumpJourney(t);
        expect(find.byType(GlossaryPage), findsOneWidget);
        router.pop();
        await pumpJourney(t);
        expect(t.element(find.byType(ProfilePage)).read<ProfileBloc>(), same(bloc));
        await activate(t, 'profile-settings');
        final settings = t.element(find.byType(SettingsPage)).read<SettingsBloc>();
        await journeyUntil(t, () => settings.state.user != null);
        final settingsUser = settings.state.user;
        final reminder = t.widget<QSettingsRow>(find.byKey(const ValueKey('settings-reminder')));
        expect(RegExp(r'[0-9]').hasMatch(reminder.value!), language == 'en');
        if (language == 'ar') expect(reminder.value, contains('٧:٠٠'));
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump(const Duration(seconds: 1));
          for (final key in ['settings-language', 'settings-goal', 'settings-motion', 'settings-private', 'settings-about']) {
            await t.ensureVisible(find.byKey(ValueKey(key)));
            await t.pump();
            expect(t.takeException(), isNull, reason: 'settings/$size/$key');
          }
          expect(settings.state.user, same(settingsUser));
        }
        t.view.physicalSize = const Size(320, 400);
        await t.pump();
        await activate(t, 'settings-sound');
        await activate(t, 'settings-haptics');
        await activate(t, 'settings-characters');
        expect(d.preferences.state.value.sound, false);
        expect(d.preferences.state.value.haptics, false);
        expect(d.characters.state.enabled, false);
        await activate(t, 'settings-motion');
        expect(d.preferences.state.value.reduceMotion, !reduced);
        await activate(t, 'settings-discreet');
        await activate(t, 'settings-goal');
        final c = t.element(find.byType(SettingsPage));
        final fifteen = c.l10n.onboardingPerDay(11, c.n(15));
        await t.tap(find.text(fifteen).last);
        await pumpJourney(t);
        expect(settings.state.user!.dailyGoalMinutes, 15);
        final private = settings.state.user!.privateProfile;
        await activate(t, 'settings-private');
        expect(settings.state.user!.privateProfile, !private);
        // Track selection re-fetches the shared path and keeps progress.
        await activate(t, 'settings-track');
        await t.tap(find.text(t.element(find.byType(SettingsPage)).l10n.commonPathNewMuslim).last);
        await pumpJourney(t);
        expect(settings.state.user!.track.name, 'newMuslim');
        await activate(t, 'settings-track');
        await t.tap(find.text(t.element(find.byType(SettingsPage)).l10n.commonPathExplorer).last);
        await pumpJourney(t);
        expect(settings.state.user!.track.name, 'explorer');
        // Persisted local values can be reconstructed without restarting the app.
        final prefs = PreferencesCubit(d.services<PreferencesStore>());
        expect(prefs.state.value, d.preferences.state.value);
        await prefs.close();
        await activate(t, 'settings-language');
        final target = language == 'en' ? c.l10n.settingsArabic : c.l10n.settingsEnglish;
        await t.tap(find.text(target).last);
        await pumpJourney(t);
        expect(d.locale.state.language, language == 'en' ? 'ar' : 'en');
        expect(Directionality.of(t.element(find.byType(SettingsPage))), language == 'en' ? TextDirection.rtl : TextDirection.ltr);
        final storedLocale = LocaleCubit(d.services<PreferencesStore>());
        expect(storedLocale.state.language, d.locale.state.language);
        await storedLocale.close();
        // A server rejection restores the entire optimistic user and locale and shows a localized snackbar.
        final failing = MockRoute('PATCH', '/me', (_, _) async => BackendResponse.error(400, 'validation_error', 'rejected'));
        mock.router.routes.insert(0, failing);
        final before = settings.state.user;
        await activate(t, 'settings-language');
        final reverse = language == 'en' ? c.l10n.settingsEnglish : c.l10n.settingsArabic;
        await t.tap(find.text(reverse).last);
        await pumpJourney(t);
        expect(settings.state.user, before);
        expect(settings.state.notice, 1);
        expect(d.locale.state.language, language == 'en' ? 'ar' : 'en');
        expect(find.byType(SnackBar), findsOneWidget);
        ScaffoldMessenger.of(t.element(find.byType(SettingsPage))).removeCurrentSnackBar();
        await t.pump();
        mock.router.routes.remove(failing);
        await activate(t, 'settings-about');
        expect(find.byType(AboutPage), findsOneWidget);
        for (final size in journeySizes) {
          t.view.physicalSize = size;
          await t.pump(const Duration(seconds: 1));
          final verse = find.byKey(const ValueKey('about-verse'));
          await t.ensureVisible(verse);
          await t.pump();
          expect(t.takeException(), isNull, reason: 'about/$size');
        }
        await activate(t, 'about-verse');
        expect(find.text(Scripture.taha10), findsOneWidget);
        Navigator.of(t.element(find.text(Scripture.taha10))).pop();
        await pumpJourney(t);
        router.pop();
        await pumpJourney(t);
        // Turn characters back on through the same flow and verify global presentation settings.
        await activate(t, 'settings-characters');
        expect(d.characters.state.enabled, true);
        router.pop();
        await pumpJourney(t);
        await journeyUntil(t, () => bloc.state.status == ProfileStatus.ready);
        expect(bloc.state.snapshot!.user.displayName, 'Noura');
        await t.pumpWidget(const SizedBox.shrink());
        await pumpJourney(t);
      });
    }
  }
  testWidgets('Profile and Settings loading/error/retry, empty achievements/words and unknown badge', (t) async {
    final d = await mountJourney(t, profileCopyBundle: _ApprovedCopy());
    final mock = d.services<MockBackend>();
    await t.runAsync(() async {
      await mock.fixtures.example('Achievements');
      await mock.fixtures.example('Page[TermCard]');
    });
    final broken = MockRoute('GET', '/me', (_, _) async => BackendResponse.error(400, 'validation_error', 'rejected'));
    mock.router.routes.insert(0, broken);
    final router = GoRouter.of(t.element(find.byType(Scaffold).first));
    router.go('/profile');
    await pumpJourney(t);
    expect(find.byType(QErrorView), findsOneWidget);
    mock.router.routes.remove(broken);
    final emptyAchievements = MockRoute('GET', '/me/achievements', (_, _) async => const BackendResponse(200, {'items': []}));
    final emptyWords = MockRoute('GET', '/glossary', (_, _) async => const BackendResponse(200, {'items': [], 'next_cursor': null}));
    mock.router.routes.insertAll(0, [emptyAchievements, emptyWords]);
    t.widget<QErrorView>(find.byType(QErrorView)).onRetry();
    await pumpJourney(t);
    final bloc = t.element(find.byType(ProfilePage)).read<ProfileBloc>();
    await journeyUntil(t, () => bloc.state.snapshot != null);
    expect(bloc.state.snapshot!.achievements, isEmpty);
    expect(bloc.state.snapshot!.words, isEmpty);
    expect(find.text(t.element(find.byType(ProfilePage)).l10n.profileNoWords), findsOneWidget);
    mock.router.routes.insert(0, broken);
    unawaited(router.push('/settings'));
    await pumpJourney(t);
    expect(find.byType(QErrorView), findsOneWidget);
    mock.router.routes.remove(broken);
    t.widget<QErrorView>(find.byType(QErrorView)).onRetry();
    await pumpJourney(t);
    expect(find.byKey(const ValueKey('settings-language')), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.runAsync(d.dispose);
    await pumpJourney(t);
  });
}
