import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/features/challenges/domain/challenge.dart';

enum LobbyStatus { initial, loading, ready, working, failure }

final class ChallengeLobbyState extends Equatable {
  ChallengeLobbyState({
    this.status = LobbyStatus.initial,
    List<ChallengeInvitee> friends = const [],
    List<ChallengeInvitation> invitations = const [],
    Set<String> selected = const {},
    this.botFill = true,
    this.failure,
    this.accepted,
  }) : friends = List.unmodifiable(friends),
       invitations = List.unmodifiable(invitations),
       selected = Set.unmodifiable(selected);
  final LobbyStatus status;
  final List<ChallengeInvitee> friends;
  final List<ChallengeInvitation> invitations;
  final Set<String> selected;
  final bool botFill;
  final Failure? failure;
  final String? accepted;
  ChallengeLobbyState changed({
    LobbyStatus? status,
    List<ChallengeInvitee>? friends,
    List<ChallengeInvitation>? invitations,
    Set<String>? selected,
    bool? botFill,
    Failure? failure,
    String? accepted,
  }) => ChallengeLobbyState(
    status: status ?? this.status,
    friends: friends ?? this.friends,
    invitations: invitations ?? this.invitations,
    selected: selected ?? this.selected,
    botFill: botFill ?? this.botFill,
    failure: failure,
    accepted: accepted,
  );
  @override
  List<Object?> get props => [status, friends, invitations, selected, botFill, failure, accepted];
}

sealed class ChallengeLobbyEvent {
  const ChallengeLobbyEvent();
}

final class ChallengeLobbyOpened extends ChallengeLobbyEvent {
  const ChallengeLobbyOpened({this.friend});
  final String? friend;
}

final class ChallengeFriendSelected extends ChallengeLobbyEvent {
  const ChallengeFriendSelected(this.id);
  final String id;
}

final class ChallengeBotFillChanged extends ChallengeLobbyEvent {
  const ChallengeBotFillChanged(this.value);
  final bool value;
}

final class ChallengeInvitationDeclined extends ChallengeLobbyEvent {
  const ChallengeInvitationDeclined(this.id);
  final String id;
}

final class ChallengeLobbyBloc extends Bloc<ChallengeLobbyEvent, ChallengeLobbyState> {
  ChallengeLobbyBloc(this.actions, {this.events}) : super(ChallengeLobbyState()) {
    on<ChallengeLobbyEvent>((e, emit) async {
      if (e is ChallengeFriendSelected) {
        final selected = {...state.selected};
        if (!selected.remove(e.id) && selected.length < 3) selected.add(e.id);
        emit(state.changed(selected: selected));
        return;
      }
      if (e is ChallengeBotFillChanged) {
        emit(state.changed(botFill: e.value));
        return;
      }
      if (e is ChallengeInvitationDeclined) {
        emit(state.changed(status: LobbyStatus.working));
        final result = await actions.decline(e.id);
        if (emit.isDone) return;
        if (result is Ok) events?.publish(const ChallengeInvitationsChanged());
        emit(
          result is Err
              ? state.changed(status: LobbyStatus.failure, failure: result.failure)
              : state.changed(status: LobbyStatus.ready, invitations: state.invitations.where((i) => i.id != e.id).toList()),
        );
        return;
      }
      if (e is ChallengeLobbyOpened) {
        emit(state.changed(status: LobbyStatus.loading));
        final results = await Future.wait([actions.friends(), actions.invitations()]);
        if (emit.isDone) return;
        final f = results[0], i = results[1];
        emit(
          ChallengeLobbyState(
            status: f is Err || i is Err ? LobbyStatus.failure : LobbyStatus.ready,
            friends: f is Ok ? (f as Ok).value as List<ChallengeInvitee> : state.friends,
            invitations: i is Ok ? (i as Ok).value as List<ChallengeInvitation> : state.invitations,
            selected: e.friend == null ? state.selected : {e.friend!},
            botFill: state.botFill,
            failure: f is Err
                ? (f as Err).failure
                : i is Err
                ? (i as Err).failure
                : null,
          ),
        );
      }
    }, transformer: sequential());
  }
  final ChallengeActions actions;
  final AppEventBus? events;
}
