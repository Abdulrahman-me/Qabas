import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qabas/app/app.dart';
import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/app/di/injector.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/domain/repositories/auth_repository.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/glossary/presentation/glossary_page.dart';
import 'package:qabas/features/onboarding/domain/entities/onboarding_answers.dart';
import 'package:qabas/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:qabas/features/profile/presentation/bloc/settings_bloc.dart';
import 'package:qabas/features/profile/presentation/pages/about_page.dart';
import 'package:qabas/features/profile/presentation/pages/profile_page.dart';
import 'package:qabas/features/profile/presentation/pages/settings_page.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/mock_backend/mock_router.dart';
import 'package:qabas/shared/content/bundled_scripture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['en', 'ar']) {
    for (final reduced in [false, true]) {
      testWidgets('Profile, settings, instant locale/rollback and About $language/$reduced', (t) async {
        Future<void> until(bool Function() ready) async {
          for (var i = 0; i < 220 && !ready(); i++) {
            await t.pump(const Duration(milliseconds: 80));
          }
          expect(ready(), true);
          expect(t.takeException(), isNull);
          await t.pump(const Duration(milliseconds: 600));
        }

        Future<void> capture(String name) async {
          for (var i = 0; i < 70; i++) {
            await t.pump(const Duration(milliseconds: 16));
          }
          expect(t.takeException(), isNull);
          await binding.takeScreenshot(name);
        }

        Future<void> activate(String key) async {
          final finder = find.byKey(ValueKey(key));
          await t.ensureVisible(finder);
          await t.pump(const Duration(milliseconds: 100));
          await t.tap(finder);
          await t.pump(const Duration(milliseconds: 650));
        }

        final store = await PreferencesStore.open();
        await store.clear();
        await store.setString('language', language);
        await store.setBoolean('reduce_motion', reduced);
        final d = await AppDependencies.create(
          config: AppConfig(),
          store: store,
          initialSessionState: const AppSessionState(status: SessionStatus.ready, splashElapsed: true),
        );
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
          await d.dispose();
        });
        await d.services<TokenStore>().clear();
        final mock = d.services<MockBackend>();
        mock.controls.fast = true;
        mock.controls.curiosityOnboarding = false;
        await d.services<AuthRepository>().createGuest();
        await d.services<OnboardingRepository>().complete(
          OnboardingAnswers(
            track: TrackChoice.newMuslim,
            language: language,
            familiarity: null,
            dailyGoal: 10,
            privateProfile: false,
            goalAnchor: null,
          ),
        );
        await t.pumpWidget(QabasApp(dependencies: d));
        await until(() => find.byKey(const ValueKey('nav-4')).evaluate().isNotEmpty);
        await activate('nav-4');
        await until(() => find.byType(ProfilePage).evaluate().isNotEmpty);
        final bloc = t.element(find.byType(ProfilePage)).read<ProfileBloc>();
        await until(() => bloc.state.snapshot != null);
        final prefix = 'phase10/${defaultTargetPlatform.name}_${language}_${reduced ? 'reduced' : 'motion'}';
        await capture('${prefix}_53_profile');
        await activate('profile-name');
        await t.tap(find.byKey(const ValueKey('profile-name-input')));
        await t.pump(const Duration(milliseconds: 300));
        await t.enterText(find.byKey(const ValueKey('profile-name-input')), language == 'en' ? 'Noura' : 'نورة');
        await t.pump(const Duration(milliseconds: 300));
        await capture('${prefix}_name');
        await activate('profile-name-save');
        await until(() => find.byKey(const ValueKey('profile-name-input')).evaluate().isEmpty);
        final router = GoRouter.of(t.element(find.byType(ProfilePage)));
        final words = find.text(t.element(find.byType(ProfilePage)).l10n.reviewYourWords);
        await t.ensureVisible(words);
        await t.pump(const Duration(milliseconds: 300));
        await capture('${prefix}_words');
        unawaited(router.push('/glossary'));
        await until(() => find.byType(GlossaryPage).evaluate().isNotEmpty);
        router.pop();
        await t.pump(const Duration(milliseconds: 600));
        await activate('profile-settings');
        await until(() => find.byType(SettingsPage).evaluate().isNotEmpty);
        final settings = t.element(find.byType(SettingsPage)).read<SettingsBloc>();
        await until(() => settings.state.user != null);
        if (language == 'ar') expect(find.textContaining('٧:٠٠'), findsOneWidget);
        await capture('${prefix}_55_settings');
        final oldLanguage = d.locale.state.language;
        await activate('settings-language');
        final c = t.element(find.byType(SettingsPage));
        await t.tap(find.text(language == 'en' ? c.l10n.settingsArabic : c.l10n.settingsEnglish).last);
        await until(() => settings.state.status == SettingsStatus.ready && d.locale.state.language != oldLanguage);
        expect(Directionality.of(t.element(find.byType(SettingsPage))), language == 'en' ? TextDirection.rtl : TextDirection.ltr);
        final failure = MockRoute('PATCH', '/me', (_, _) async => BackendResponse.error(400, 'validation_error', 'rejected'));
        mock.router.routes.insert(0, failure);
        await activate('settings-language');
        await t.tap(find.text(language == 'en' ? c.l10n.settingsEnglish : c.l10n.settingsArabic).last);
        await until(() => settings.state.notice == 1);
        expect(d.locale.state.language, oldLanguage == 'en' ? 'ar' : 'en');
        ScaffoldMessenger.of(t.element(find.byType(SettingsPage))).removeCurrentSnackBar();
        await t.pump();
        mock.router.routes.remove(failure);
        await activate('settings-language');
        await t.tap(find.text(language == 'en' ? c.l10n.settingsEnglish : c.l10n.settingsArabic).last);
        await until(() => d.locale.state.language == oldLanguage && settings.state.status == SettingsStatus.ready);
        await activate('settings-sound');
        await until(() => !d.preferences.state.value.sound);
        await activate('settings-haptics');
        await until(() => !d.preferences.state.value.haptics);
        await activate('settings-characters');
        await until(() => !d.characters.state.enabled);
        await activate('settings-motion');
        await until(() => d.preferences.state.value.reduceMotion != reduced);
        await activate('settings-private');
        await until(() => settings.state.user!.privateProfile);
        await capture('${prefix}_preferences');
        await activate('settings-characters');
        await until(() => d.characters.state.enabled);
        await activate('settings-motion');
        await until(() => d.preferences.state.value.reduceMotion == reduced);
        // Reviewed English-only curiosity copy is shown when enabled, with no Arabic fallback.
        mock.controls.curiosityOnboarding = true;
        settings.add(const SettingsOpened());
        await t.pump(const Duration(milliseconds: 100));
        await until(() => settings.state.status == SettingsStatus.ready);
        expect(find.byKey(const ValueKey('settings-curiosity')), language == 'en' ? findsOneWidget : findsNothing);
        mock.controls.curiosityOnboarding = false;
        await activate('settings-about');
        await until(() => find.byType(AboutPage).evaluate().isNotEmpty);
        await capture('${prefix}_56_about');
        await activate('about-verse');
        await until(() => find.text(Scripture.taha10).evaluate().isNotEmpty);
        await capture('${prefix}_full_verse');
        Navigator.of(t.element(find.text(Scripture.taha10))).pop();
        await t.pump(const Duration(milliseconds: 600));
        final promises = find.text(t.element(find.byType(AboutPage)).l10n.aboutOurPromises.toUpperCase());
        await t.ensureVisible(promises);
        await t.pump(const Duration(milliseconds: 300));
        await capture('${prefix}_notices');
        expect(t.takeException(), isNull);
      });
    }
  }
}
