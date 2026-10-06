import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/features/profile/domain/profile.dart';
import 'package:qabas/features/profile/domain/profile_repository.dart';
import 'package:qabas/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:qabas/features/profile/presentation/bloc/settings_bloc.dart';
import 'package:qabas/shared/domain/entities/local_preferences.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

import '../../support/session_fakes.dart';

class FakeProfile implements ProfileRepository {
  UserProfile value = learner();
  Future<Result<UserProfile>> Function(ProfileEdit)? patch;
  int patches = 0;
  @override
  Future<Result<UserProfile>> user() async => Ok(value);
  @override
  Future<Result<UserProfile>> update(ProfileEdit edit) async {
    patches++;
    if (patch != null) return patch!(edit);
    value = edit.apply(value);
    return Ok(value);
  }

  @override
  Future<Result<ProfileSnapshot>> load() async => const Err(NetworkFailure());
  @override
  Future<SettingsCuriosity?> curiosity(String language) async =>
      language == 'en' ? SettingsCuriosity('Question', {'why_pray': 'Why pray?'}) : null;
}

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 20));
void main() {
  for (final failure in [const NetworkFailure(), const ServerFailure(), const ValidationFailure('invalid')]) {
    test('Language applies before response, failure restores language and emits notice: $failure', () async {
      final repo = FakeProfile(), bus = AppEventBus();
      var language = 'en';
      final pending = Completer<Result<UserProfile>>();
      repo.patch = (_) => pending.future;
      final bloc = SettingsBloc(
        ProfileActions(repo),
        language: () => language,
        changeLanguage: (v) async {
          language = v;
        },
        curiosityEnabled: () => true,
        events: bus,
        changePreferences: (_) async => true,
      );
      bloc.add(const SettingsOpened());
      await tick();
      bloc.add(const SettingChanged(ProfileEdit(language: UserLanguage.ar)));
      await tick();
      expect(language, 'ar');
      expect(bloc.state.status, SettingsStatus.saving);
      expect(bloc.state.curiosity, isNull);
      expect(bloc.state.user!.language, UserLanguage.ar);
      pending.complete(Err(failure));
      await tick();
      expect(language, 'en');
      expect(bloc.state.status, SettingsStatus.ready);
      expect(bloc.state.notice, 1);
      expect(bloc.state.user, repo.value);
      expect(bloc.state.curiosity, isNotNull);
      await bloc.close();
      await bus.dispose();
    });
  }
  test('Serial server edits preserve previous successful fields; local changes and copy gating', () async {
    final repo = FakeProfile(), bus = AppEventBus();
    var language = 'en', enabled = false, locals = 0;
    final bloc = SettingsBloc(
      ProfileActions(repo),
      language: () => language,
      changeLanguage: (v) async {
        language = v;
      },
      curiosityEnabled: () => enabled,
      events: bus,
      changePreferences: (_) async {
        locals++;
        return false;
      },
    );
    bloc.add(const SettingsOpened());
    await tick();
    expect(bloc.state.curiosity, isNull);
    enabled = true;
    bloc.add(const SettingsLanguageObserved());
    await tick();
    expect(bloc.state.curiosity, isNotNull);
    bloc.add(const SettingChanged(ProfileEdit(dailyGoal: 15)));
    bloc.add(const SettingChanged(ProfileEdit(privateProfile: false)));
    await tick();
    expect(bloc.state.user!.dailyGoalMinutes, 15);
    expect(bloc.state.user!.privateProfile, false);
    bloc.add(const LocalSettingChanged(LocalPreferencesEdit(sound: false)));
    await tick();
    expect(locals, 1);
    expect(bloc.state.notice, 1);
    final previous = bloc.state.user;
    repo.patch = (_) async => const Err(NetworkFailure());
    bloc.add(const SettingChanged(ProfileEdit(track: UserTrack.newMuslim)));
    await tick();
    expect(bloc.state.user, previous);
    expect(bloc.state.notice, 2);
    bloc.add(const SettingChanged(ProfileEdit(dailyGoal: 15)));
    await tick();
    expect(repo.patches, 3);
    await bloc.close();
    await bus.dispose();
    expect(locals, 1);
  });
  test('Queued local toggles apply to the latest preferences without losing other fields', () async {
    final repo = FakeProfile(), bus = AppEventBus();
    var local = const LocalPreferences();
    final bloc = SettingsBloc(
      ProfileActions(repo),
      language: () => 'en',
      changeLanguage: (_) async {},
      curiosityEnabled: () => false,
      events: bus,
      changePreferences: (edit) async {
        local = edit.apply(local);
        await tick();
        return true;
      },
    );
    bloc.add(const LocalSettingChanged(LocalPreferencesEdit(sound: false)));
    bloc.add(const LocalSettingChanged(LocalPreferencesEdit(haptics: false)));
    bloc.add(const LocalSettingChanged(LocalPreferencesEdit(companionEnabled: false)));
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(local.sound, false);
    expect(local.haptics, false);
    expect(local.companionEnabled, false);
    expect(local.reminderHour, 19);
    expect(repo.patches, 0);
    await bloc.close();
    await bus.dispose();
  });
  test('Reset suppresses late settings success and locale rollback for a new learner', () async {
    final repo = FakeProfile(), bus = AppEventBus();
    var language = 'en';
    final pending = Completer<Result<UserProfile>>();
    repo.patch = (_) => pending.future;
    final bloc = SettingsBloc(
      ProfileActions(repo),
      language: () => language,
      changeLanguage: (v) async {
        language = v;
      },
      curiosityEnabled: () => true,
      events: bus,
      changePreferences: (_) async => true,
    );
    bloc.add(const SettingsOpened());
    await tick();
    bloc.add(const SettingChanged(ProfileEdit(language: UserLanguage.ar)));
    await tick();
    bus.publish(const GuestSessionCleared());
    await tick();
    language = 'ar';
    pending.complete(const Err(UnauthorizedFailure()));
    await tick();
    expect(bloc.state.notice, 0);
    expect(language, 'ar');
    await bloc.close();
    await bus.dispose();
  });
  test('Profile fetch failure exposes a retry; retry reissues reads', () async {
    final bus = AppEventBus(), repo = FakeProfile();
    final bloc = ProfileBloc(ProfileActions(repo), bus);
    bloc.add(const ProfileOpened());
    await tick();
    expect(bloc.state.status, ProfileStatus.failure);
    expect(bloc.state.failure, isA<NetworkFailure>());
    bloc.add(const ProfileOpened());
    await tick();
    expect(bloc.state.status, ProfileStatus.failure);
    await bloc.close();
    await bus.dispose();
  });
}
