import 'dart:async';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/features/community/domain/community.dart';

enum CommunityStatus { initial, loading, ready }

final class CommunityState extends Equatable {
  const CommunityState({
    this.status = CommunityStatus.initial,
    this.league,
    this.quests,
    this.leagueFailure,
    this.questsFailure,
    this.inviteFailure,
    this.invitations = 0,
  });
  final CommunityStatus status;
  final League? league;
  final Quests? quests;
  final Failure? leagueFailure, questsFailure, inviteFailure;
  final int invitations;
  bool get noLeague => leagueFailure is NotFoundFailure && (leagueFailure as NotFoundFailure).reason == 'no_league_this_week';
  @override
  List<Object?> get props => [status, league, quests, leagueFailure, questsFailure, inviteFailure, invitations];
}

sealed class CommunityEvent {
  const CommunityEvent();
}

final class CommunityOpened extends CommunityEvent {
  const CommunityOpened();
}

final class _CommunityCleared extends CommunityEvent {
  const _CommunityCleared();
}

final class CommunityBloc extends Bloc<CommunityEvent, CommunityState> {
  CommunityBloc(this.actions, AppEventBus events) : super(const CommunityState()) {
    on<CommunityEvent>((event, emit) async {
      if (event is _CommunityCleared) {
        emit(const CommunityState());
        return;
      }
      final epoch = _epoch;
      emit(CommunityState(status: CommunityStatus.loading, league: state.league, quests: state.quests, invitations: state.invitations));
      final results = await Future.wait([actions.league(), actions.quests(), actions.invitations()]);
      if (emit.isDone || epoch != _epoch) return;
      final l = results[0], q = results[1], i = results[2];
      emit(
        CommunityState(
          status: CommunityStatus.ready,
          league: l is Ok ? (l as Ok).value as League : null,
          quests: q is Ok ? (q as Ok).value as Quests : null,
          leagueFailure: l is Err ? (l as Err).failure : null,
          questsFailure: q is Err ? (q as Err).failure : null,
          invitations: i is Ok ? (i as Ok).value as int : state.invitations,
          inviteFailure: i is Err ? (i as Err).failure : null,
        ),
      );
    }, transformer: restartable());
    _events = events.on<AppEvent>().listen((e) {
      if (e is GuestSessionCleared) {
        _epoch++;
        add(const _CommunityCleared());
      } else if (e is SessionCompleted || e is ProfileChanged || e is XpChanged || e is ChallengeInvitationsChanged) {
        add(const CommunityOpened());
      }
    });
  }
  final CommunityActions actions;
  late final StreamSubscription<AppEvent> _events;
  int _epoch = 0;
  @override
  Future<void> close() async {
    await _events.cancel();
    await super.close();
  }
}

enum FriendsStatus { initial, loading, ready, working, failure }

final class FriendsState extends Equatable {
  FriendsState({this.status = FriendsStatus.initial, List<Friend> items = const [], this.invite, this.failure, this.accepted = 0})
    : items = List.unmodifiable(items);
  final FriendsStatus status;
  final List<Friend> items;
  final FriendInvite? invite;
  final Failure? failure;
  final int accepted;
  @override
  List<Object?> get props => [status, items, invite, failure, accepted];
}

sealed class FriendsEvent {
  const FriendsEvent();
}

final class FriendsOpened extends FriendsEvent {
  const FriendsOpened();
}

final class InviteCreated extends FriendsEvent {
  const InviteCreated();
}

final class InviteAccepted extends FriendsEvent {
  const InviteAccepted(this.code);
  final String code;
}

final class FriendRemoved extends FriendsEvent {
  const FriendRemoved(this.id);
  final String id;
}

final class _FriendsCleared extends FriendsEvent {
  const _FriendsCleared();
}

final class FriendsBloc extends Bloc<FriendsEvent, FriendsState> {
  FriendsBloc(this.actions, AppEventBus events) : super(FriendsState()) {
    on<FriendsEvent>((event, emit) async {
      if (event is _FriendsCleared) {
        emit(FriendsState());
        return;
      }
      if (state.status == FriendsStatus.working) return;
      final epoch = _epoch;
      emit(
        FriendsState(
          status: event is FriendsOpened ? FriendsStatus.loading : FriendsStatus.working,
          items: state.items,
          invite: state.invite,
          accepted: state.accepted,
        ),
      );
      final Result<Object?> result = switch (event) {
        FriendsOpened() => await actions.friends(),
        InviteCreated() => await actions.invite(),
        InviteAccepted(:final code) => await actions.accept(code),
        FriendRemoved(:final id) => await actions.remove(id),
        _ => const Ok(null),
      };
      if (emit.isDone || epoch != _epoch) return;
      if (result case Err(:final failure)) {
        emit(
          FriendsState(status: FriendsStatus.failure, items: state.items, invite: state.invite, failure: failure, accepted: state.accepted),
        );
        return;
      }
      final value = (result as Ok).value;
      emit(
        FriendsState(
          status: FriendsStatus.ready,
          items: event is FriendsOpened
              ? value as List<Friend>
              : event is FriendRemoved
              ? state.items.where((f) => f.id != event.id).toList()
              : event is InviteAccepted
              ? [...state.items.where((f) => f.id != (value as Friend).id), value as Friend]
              : state.items,
          invite: event is InviteCreated ? value as FriendInvite : state.invite,
          accepted: state.accepted + (event is InviteAccepted ? 1 : 0),
        ),
      );
    }, transformer: sequential());
    _events = events.on<GuestSessionCleared>().listen((_) {
      _epoch++;
      add(const _FriendsCleared());
    });
  }
  final CommunityActions actions;
  late final StreamSubscription<GuestSessionCleared> _events;
  int _epoch = 0;
  @override
  Future<void> close() async {
    await _events.cancel();
    await super.close();
  }
}
