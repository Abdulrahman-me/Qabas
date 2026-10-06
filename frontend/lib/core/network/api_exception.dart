import 'package:qabas/core/error/failures.dart';

final class ApiException implements FailureSource {
  ApiException({this.status, required this.code, required this.message, Map<String, Object?> details = const {}})
    : details = Map.unmodifiable(details);
  final int? status;
  final String code, message;
  final Map<String, Object?> details;
  Duration? get retryAfter {
    final value = details['retry_after_ms'];
    return value is num ? Duration(milliseconds: value.toInt().clamp(0, 86400000)) : null;
  }

  @override
  Failure toFailure() => switch (status) {
    null => const NetworkFailure(),
    400 => ValidationFailure(message, details: details, field: details['field'] is String ? details['field'] as String : null),
    401 => const UnauthorizedFailure(),
    403 => const ForbiddenFailure(),
    404 => NotFoundFailure(reason: details['reason'] is String ? details['reason'] as String : null),
    409 => ConflictFailure(code, details: details),
    413 => const PayloadTooLargeFailure(),
    415 => const UnsupportedMediaFailure(),
    426 => const ClientOutdatedFailure(),
    429 => RateLimitedFailure(retryAfter ?? Duration.zero),
    // Contract 503s carry an envelope; bare gateway pages mean the service itself is unavailable.
    503 when code != 'unknown' => UpstreamUnavailableFailure(retryAfter: retryAfter),
    _ => const ServerFailure(),
  };
  // Intentionally omits envelope contents from accidental exception logging.
  @override
  String toString() => 'ApiException(status: $status)';
}
