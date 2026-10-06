import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/features/profile/domain/profile.dart';
import 'package:qabas/features/profile/domain/profile_repository.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

enum SettingsStatus { initial, loading, ready, saving, failure }

final class SettingsState extends Equatable {
  const SettingsState({this.status = SettingsStatus.initial, this.user, this.curiosity, this.failure, this.notice = 0});
  final SettingsStatus status;
  final UserProfile? user;
  final SettingsCuriosity? curiosity;
  final Failure? failure;
  final int notice;
  @override
  List<Object?> get props => [status, user, curiosity, failure, notice];
}

sealed class SettingsEvent {
  const SettingsEvent();
}

final class SettingsOpened extends SettingsEvent {
  const SettingsOpened();
}

final class SettingChanged extends SettingsEvent {
  const SettingChanged(this.edit);
  final ProfileEdit edit;
}

final class LocalSettingChanged extends SettingsEvent {
  const LocalSettingChanged(this.edit);
  final LocalPreferencesEdit edit;
}

final class SettingsLanguageObserved extends SettingsEvent {
  const SettingsLanguageObserved();
}

final class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc(
    this.actions, {
    required this.language,
    required this.changeLanguage,
    required this.curiosityEnabled,
    required AppEventBus events,
    required this.changePreferences,
  }) : super(const SettingsState()) {
    on<SettingsEvent>(_handle, transformer: sequential());
    _subscription = events.on<GuestSessionCleared>().listen((_) => _epoch++);
  }
  final Future<bool> Function(LocalPreferencesEdit) changePreferences;
  final ProfileActions actions;
  final String Function() language;
  final Future<void> Function(String) changeLanguage;
  final bool Function() curiosityEnabled;
  late final StreamSubscription<GuestSessionCleared> _subscription;
  int _epoch = 0;
  Future<SettingsCuriosity?> _copy() => curiosityEnabled() ? actions.curiosity(language()) : Future.value();
  Future<void> _handle(SettingsEvent event, Emitter<SettingsState> emit) async {
    final epoch = _epoch;
    if (event is LocalSettingChanged) {
      final saved = await changePreferences(event.edit);
      if (!saved && !emit.isDone && epoch == _epoch) {
        emit(
          SettingsState(
            status: state.status,
            user: state.user,
            curiosity: state.curiosity,
            failure: const UnexpectedFailure('Local preference save failed'),
            notice: state.notice + 1,
          ),
        );
      }
    } else if (event is SettingsOpened) {
      emit(SettingsState(status: SettingsStatus.loading, user: state.user, notice: state.notice));
      final result = await actions.user(), copy = await _copy();
      if (emit.isDone || epoch != _epoch) return;
      emit(switch (result) {
        Ok(:final value) => SettingsState(status: SettingsStatus.ready, user: value, curiosity: copy, notice: state.notice),
        Err(:final failure) => SettingsState(status: SettingsStatus.failure, failure: failure, notice: state.notice),
      });
    } else if (event is SettingsLanguageObserved) {
      final copy = await _copy();
      if (!emit.isDone && epoch == _epoch) {
        emit(SettingsState(status: state.status, user: state.user, curiosity: copy, failure: state.failure, notice: state.notice));
      }
    } else if (event is SettingChanged && state.user != null) {
      final previous = state.user!, previousLanguage = language();
      final edit = event.edit;
      if (edit.apply(previous) == previous) return;
      emit(
        SettingsState(
          status: SettingsStatus.saving,
          user: edit.apply(previous),
          curiosity: edit.language == null ? state.curiosity : null,
          notice: state.notice,
        ),
      );
      // LocaleCubit emits synchronously before the request starts; only changed fields go on the wire.
      if (edit.language != null) unawaited(changeLanguage(edit.language!.name));
      final result = await actions.update(edit);
      if (epoch != _epoch) return;
      if (result is Err<UserProfile> && edit.language != null) await changeLanguage(previousLanguage);
      final copy = await _copy();
      if (emit.isDone || epoch != _epoch) return;
      emit(switch (result) {
        Ok(:final value) => SettingsState(status: SettingsStatus.ready, user: value, curiosity: copy, notice: state.notice),
        Err(:final failure) => SettingsState(
          status: SettingsStatus.ready,
          user: previous,
          curiosity: copy,
          failure: failure,
          notice: state.notice + 1,
        ),
      });
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
