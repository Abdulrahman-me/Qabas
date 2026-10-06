import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/profile/domain/profile.dart';
import 'package:qabas/features/profile/domain/profile_extras.dart';

enum AchievementsStatus { initial, loading, ready, failure }

final class AchievementsState extends Equatable {
  AchievementsState({this.status = AchievementsStatus.initial, List<Achievement> items = const [], this.failure})
    : items = List.unmodifiable(items);
  final AchievementsStatus status;
  final List<Achievement> items;
  final Failure? failure;
  @override
  List<Object?> get props => [status, items, failure];
}

final class AchievementsOpened {
  const AchievementsOpened();
}

final class AchievementsBloc extends Bloc<AchievementsOpened, AchievementsState> {
  AchievementsBloc(this.actions) : super(AchievementsState()) {
    on<AchievementsOpened>((_, emit) async {
      emit(AchievementsState(status: AchievementsStatus.loading, items: state.items));
      final result = await actions.achievements();
      if (emit.isDone) return;
      emit(switch (result) {
        Ok(:final value) => AchievementsState(status: AchievementsStatus.ready, items: value),
        Err(:final failure) => AchievementsState(status: AchievementsStatus.failure, items: state.items, failure: failure),
      });
    }, transformer: restartable());
  }
  final ProfileExtrasActions actions;
}

enum AccountDeletionStatus { idle, deleting, deleted, failure }

final class AccountDeletionState extends Equatable {
  const AccountDeletionState({this.status = AccountDeletionStatus.idle, this.failure});
  final AccountDeletionStatus status;
  final Failure? failure;
  @override
  List<Object?> get props => [status, failure];
}

final class AccountDeletionConfirmed {
  const AccountDeletionConfirmed();
}

final class AccountDeletionBloc extends Bloc<AccountDeletionConfirmed, AccountDeletionState> {
  AccountDeletionBloc(this.actions) : super(const AccountDeletionState()) {
    on<AccountDeletionConfirmed>((_, emit) async {
      if (state.status == AccountDeletionStatus.deleted) return;
      emit(const AccountDeletionState(status: AccountDeletionStatus.deleting));
      final result = await actions.deleteAccount();
      if (emit.isDone) return;
      emit(
        result is Err
            ? AccountDeletionState(status: AccountDeletionStatus.failure, failure: result.failure)
            : const AccountDeletionState(status: AccountDeletionStatus.deleted),
      );
    }, transformer: droppable());
  }
  final ProfileExtrasActions actions;
}
