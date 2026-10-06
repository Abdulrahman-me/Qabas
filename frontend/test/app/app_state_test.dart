import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/app/router/app_router.dart';
import 'package:qabas/core/characters/character_settings_cubit.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/l10n/locale_cubit.dart';
import 'package:qabas/core/network/auth_events.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/profile/presentation/bloc/preferences_cubit.dart';
import 'package:qabas/shared/domain/entities/local_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/session_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Rapid locale and preference edits preserve newest UI and disk values', () async {
    final store = await PreferencesStore.open();
    final locale = LocaleCubit(store);
    final preferences = PreferencesCubit(store);
    await Future.wait([locale.languageChanged('ar'), locale.languageChanged('en'), locale.languageChanged('ar')]);
    expect(locale.state.language, 'ar');
    expect(store.string('language'), 'ar');
    await Future.wait([
      preferences.preferencesChanged(const LocalPreferences(sound: false)),
      preferences.preferencesChanged(const LocalPreferences(sound: true, haptics: false, reduceMotion: true)),
    ]);
    expect(preferences.state.value.haptics, false);
    expect(preferences.state.value.sound, true);
    final reloaded = PreferencesCubit(store);
    expect(reloaded.state.value, preferences.state.value);
    await locale.close();
    await preferences.close();
    await reloaded.close();
  });
  test('Character casting persists and malformed preferences use defaults', () async {
    final store = await PreferencesStore.open();
    await store.setString('character_casting', 'malformed');
    final cubit = CharacterSettingsCubit(store);
    expect(cubit.state.overrides, isEmpty);
    await cubit.settingsChanged(enabled: false, overrides: {CharacterRole.guide: 'raqeeb_lantern'});
    final restored = CharacterSettingsCubit(store);
    expect(restored.state, cubit.state);
    await cubit.close();
    await restored.close();
  });
  test('Session responds to global auth notices and closes subscription', () async {
    final notices = StreamController<AuthEvent>.broadcast();
    final bloc = FakeAuth().bloc(notices.stream, initial: const AppSessionState(status: SessionStatus.ready, splashElapsed: true));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, SessionStatus.ready);
    notices.add(const AuthExpired());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.status, SessionStatus.sessionEnded);
    notices.add(const ClientOutdated('2.0.0'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.minimumVersion, '2.0.0');
    expect(bloc.state.status, SessionStatus.outdated);
    await bloc.close();
    notices.add(const AuthExpired());
    await notices.close();
  });
  test('Guard routes statuses without session-ended auth loops', () {
    expect(sessionRedirect(SessionStatus.unknown, '/journey', developerEnabled: false), '/splash');
    expect(sessionRedirect(SessionStatus.needsOnboarding, '/profile', developerEnabled: false), '/welcome');
    expect(sessionRedirect(SessionStatus.sessionEnded, '/journey', developerEnabled: false), '/session-ended');
    expect(sessionRedirect(SessionStatus.sessionEnded, '/session-ended', developerEnabled: false), isNull);
    expect(sessionRedirect(SessionStatus.outdated, '/profile', developerEnabled: false), '/outdated');
    expect(sessionRedirect(SessionStatus.ready, '/welcome', developerEnabled: false), '/journey');
    expect(sessionRedirect(SessionStatus.outdated, '/developer', developerEnabled: true), isNull);
  });
}
