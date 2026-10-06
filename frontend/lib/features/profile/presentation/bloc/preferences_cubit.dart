import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/shared/domain/entities/local_preferences.dart';

enum PreferencesStatus { ready, saving, failure }

final class PreferencesState extends Equatable {
  const PreferencesState(this.value, {this.status = PreferencesStatus.ready});
  final LocalPreferences value;
  final PreferencesStatus status;
  @override
  List<Object?> get props => [value, status];
}

final class PreferencesCubit extends Cubit<PreferencesState> {
  PreferencesCubit(this._store)
    : super(
        PreferencesState(
          LocalPreferences(
            sound: _store.boolean('sound', fallback: true),
            haptics: _store.boolean('haptics', fallback: true),
            reduceMotion: _store.boolean('reduce_motion'),
            discreetReminders: _store.boolean('discreet_reminders'),
            companionEnabled: _store.boolean('companion_enabled', fallback: true),
            reminderHour: int.tryParse(_store.string('reminder_hour') ?? '') ?? 19,
          ),
        ),
      );
  final PreferencesStore _store;
  Future<void> _writes = Future.value();
  int _revision = 0;
  Future<void> preferencesChanged(LocalPreferences next) async {
    final revision = ++_revision;
    emit(PreferencesState(next, status: PreferencesStatus.saving));
    return _writes = _writes.then((_) async {
      try {
        await _store.setBoolean('sound', next.sound);
        await _store.setBoolean('haptics', next.haptics);
        await _store.setBoolean('reduce_motion', next.reduceMotion);
        await _store.setBoolean('discreet_reminders', next.discreetReminders);
        await _store.setBoolean('companion_enabled', next.companionEnabled);
        await _store.setString('reminder_hour', next.reminderHour.toString());
        if (!isClosed && revision == _revision) emit(PreferencesState(next));
      } catch (_) {
        if (!isClosed && revision == _revision) emit(PreferencesState(next, status: PreferencesStatus.failure));
      }
    });
  }

  void onboardingPreferencesReloaded() => emit(
    PreferencesState(
      state.value.copyWith(
        discreetReminders: _store.boolean('discreet_reminders'),
        reminderHour: int.tryParse(_store.string('reminder_hour') ?? '') ?? 19,
      ),
    ),
  );

  Future<void> localPreferencesCleared() async {
    final revision = ++_revision;
    emit(PreferencesState(state.value, status: PreferencesStatus.saving));
    return _writes = _writes.then((_) async {
      try {
        await _store.clearLocal();
        if (!isClosed && revision == _revision) emit(const PreferencesState(LocalPreferences()));
      } catch (_) {
        if (!isClosed && revision == _revision) emit(PreferencesState(state.value, status: PreferencesStatus.failure));
      }
    });
  }
}
