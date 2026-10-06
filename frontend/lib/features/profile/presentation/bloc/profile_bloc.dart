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

enum ProfileStatus { initial, loading, ready, saving, failure }

final class ProfileState extends Equatable {
  const ProfileState({this.status = ProfileStatus.initial, this.snapshot, this.failure, this.notice = 0, this.nameSaved = 0});
  final ProfileStatus status;
  final ProfileSnapshot? snapshot;
  final Failure? failure;
  final int notice, nameSaved;
  @override
  List<Object?> get props => [status, snapshot, failure, notice, nameSaved];
}

sealed class ProfileEvent {
  const ProfileEvent();
}

final class ProfileOpened extends ProfileEvent {
  const ProfileOpened();
}

final class DisplayNameSubmitted extends ProfileEvent {
  const DisplayNameSubmitted(this.name);
  final String name;
}

final class _ProfileCleared extends ProfileEvent {
  const _ProfileCleared();
}

final class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc(this.actions, AppEventBus events) : super(const ProfileState()) {
    on<ProfileEvent>(_handle, transformer: sequential());
    _subscription = events.on<AppEvent>().listen((event) {
      if (event is GuestSessionCleared) {
        _epoch++;
        add(const _ProfileCleared());
      }
      if (event is ProfileChanged || event is SessionCompleted || event is TermsMastered || event is XpChanged) {
        if (!_refreshQueued) {
          _refreshQueued = true;
          add(const ProfileOpened());
        }
      }
    });
  }
  final ProfileActions actions;
  late final StreamSubscription<AppEvent> _subscription;
  int _epoch = 0;
  bool _refreshQueued = false;
  Future<void> _handle(ProfileEvent event, Emitter<ProfileState> emit) async {
    if (event is _ProfileCleared) {
      emit(const ProfileState());
      return;
    }
    final epoch = _epoch;
    if (event is ProfileOpened) {
      _refreshQueued = false;
      emit(ProfileState(status: ProfileStatus.loading, snapshot: state.snapshot, notice: state.notice, nameSaved: state.nameSaved));
      final result = await actions.load();
      if (emit.isDone || epoch != _epoch) return;
      emit(switch (result) {
        Ok(:final value) => ProfileState(status: ProfileStatus.ready, snapshot: value, notice: state.notice, nameSaved: state.nameSaved),
        Err(:final failure) => ProfileState(
          status: ProfileStatus.failure,
          snapshot: state.snapshot,
          failure: failure,
          notice: state.snapshot == null ? state.notice : state.notice + 1,
          nameSaved: state.nameSaved,
        ),
      });
    }
    if (event is DisplayNameSubmitted && state.snapshot != null) {
      final name = event.name.trim();
      if (name.runes.length < 2 || name.runes.length > 24) {
        emit(
          ProfileState(
            status: ProfileStatus.ready,
            snapshot: state.snapshot,
            failure: const ValidationFailure('', field: 'display_name'),
            notice: state.notice + 1,
            nameSaved: state.nameSaved,
          ),
        );
        return;
      }
      emit(ProfileState(status: ProfileStatus.saving, snapshot: state.snapshot, notice: state.notice, nameSaved: state.nameSaved));
      final result = await actions.update(ProfileEdit(displayName: name));
      if (emit.isDone || epoch != _epoch) return;
      if (result case Ok(:final value)) {
        final old = state.snapshot!;
        emit(
          ProfileState(
            status: ProfileStatus.ready,
            snapshot: ProfileSnapshot(user: value, stats: old.stats, achievements: old.achievements, words: old.words),
            notice: state.notice,
            nameSaved: state.nameSaved + 1,
          ),
        );
      } else {
        emit(
          ProfileState(
            status: ProfileStatus.ready,
            snapshot: state.snapshot,
            failure: (result as Err).failure,
            notice: state.notice + 1,
            nameSaved: state.nameSaved,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
