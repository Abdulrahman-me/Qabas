import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/reviewer/domain/reviewer_actions.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

enum ReviewerAuthStatus { idle, submitting, signedIn, signedOut, failure }

final class ReviewerAuthState extends Equatable {
  const ReviewerAuthState({this.status = ReviewerAuthStatus.idle, this.user, this.failure});
  final ReviewerAuthStatus status;
  final UserProfile? user;
  final Failure? failure;
  @override
  List<Object?> get props => [status, user, failure];
}

sealed class ReviewerAuthEvent {
  const ReviewerAuthEvent();
}

final class ReviewerSignedIn extends ReviewerAuthEvent {
  const ReviewerSignedIn(this.email, this.password);
  final String email, password;
}

final class ReviewerSampleOpened extends ReviewerAuthEvent {
  const ReviewerSampleOpened();
}

final class ReviewerSignedOut extends ReviewerAuthEvent {
  const ReviewerSignedOut();
}

final class ReviewerAuthBloc extends Bloc<ReviewerAuthEvent, ReviewerAuthState> {
  ReviewerAuthBloc(ReviewerActions actions) : super(const ReviewerAuthState()) {
    on<ReviewerAuthEvent>((e, emit) async {
      emit(const ReviewerAuthState(status: ReviewerAuthStatus.submitting));
      if (e is ReviewerSignedIn || e is ReviewerSampleOpened) {
        final result = e is ReviewerSignedIn
            ? await actions.repository.signIn(e.email, e.password)
            : await actions.repository.signInSample();
        if (emit.isDone) return;
        emit(switch (result) {
          Ok<UserProfile>(:final value) => ReviewerAuthState(status: ReviewerAuthStatus.signedIn, user: value),
          Err<UserProfile>(:final failure) => ReviewerAuthState(status: ReviewerAuthStatus.failure, failure: failure),
        });
      } else {
        final result = await actions.repository.signOut();
        if (emit.isDone) return;
        emit(switch (result) {
          Ok<void>() => const ReviewerAuthState(status: ReviewerAuthStatus.signedOut),
          Err<void>(:final failure) => ReviewerAuthState(status: ReviewerAuthStatus.failure, failure: failure),
        });
      }
    }, transformer: sequential());
  }
}
