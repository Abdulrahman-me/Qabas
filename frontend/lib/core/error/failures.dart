import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure();
  @override
  List<Object?> get props => [];
}

final class NetworkFailure extends Failure {
  const NetworkFailure();
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure();
}

final class ForbiddenFailure extends Failure {
  const ForbiddenFailure();
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure({this.reason});
  final String? reason;
  @override
  List<Object?> get props => [reason];
}

final class ValidationFailure extends Failure {
  const ValidationFailure(this.message, {this.field, this.details = const {}});
  final String message;
  final String? field;
  final Map<String, Object?> details;
  @override
  List<Object?> get props => [message, field, details];
}

final class ConflictFailure extends Failure {
  ConflictFailure(this.code, {Map<String, Object?> details = const {}}) : details = Map.unmodifiable(details);
  final String code;
  final Map<String, Object?> details;
  @override
  List<Object?> get props => [code, details];
}

final class RateLimitedFailure extends Failure {
  const RateLimitedFailure(this.retryAfter);
  final Duration retryAfter;
  @override
  List<Object?> get props => [retryAfter];
}

final class PayloadTooLargeFailure extends Failure {
  const PayloadTooLargeFailure();
}

final class UnsupportedMediaFailure extends Failure {
  const UnsupportedMediaFailure();
}

final class ClientOutdatedFailure extends Failure {
  const ClientOutdatedFailure();
}

final class UpstreamUnavailableFailure extends Failure {
  const UpstreamUnavailableFailure({this.retryAfter});
  final Duration? retryAfter;
  @override
  List<Object?> get props => [retryAfter];
}

final class ServerFailure extends Failure {
  const ServerFailure();
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(this.debugMessage);
  final String debugMessage;
  @override
  List<Object?> get props => [debugMessage];
}

/// Keeps guard/domain independent of the HTTP implementation.
abstract interface class FailureSource implements Exception {
  Failure toFailure();
}

final class RaqeebTimeoutFailure extends Failure {
  const RaqeebTimeoutFailure();
}

final class RaqeebTextLimitFailure extends Failure {
  const RaqeebTextLimitFailure();
}

enum MediaKind { image, document, audio }

final class MediaLimitFailure extends Failure {
  const MediaLimitFailure(this.kind, {this.recitation = false, this.count = false});
  final MediaKind kind;
  final bool recitation, count;
  @override
  List<Object?> get props => [kind, recitation, count];
}

final class MicrophoneDeniedFailure extends Failure {
  const MicrophoneDeniedFailure();
}

final class MediaCaptureFailure extends Failure {
  const MediaCaptureFailure();
}
