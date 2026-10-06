import 'package:qabas/core/design_system/components/states/state_views.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';

String failureBody(Failure failure, AppLocalizations l10n) => switch (failure) {
  ValidationFailure(:final message) => message,
  RaqeebTimeoutFailure() => l10n.raqeebTimeout,
  RaqeebTextLimitFailure() => l10n.raqeebTextLimit,
  RateLimitedFailure() => l10n.raqeebRateLimited,
  NetworkFailure() => l10n.errorNetworkBody,
  UpstreamUnavailableFailure() => l10n.errorSourcesBody,
  ServerFailure() => l10n.errorServerBody,
  ForbiddenFailure() => l10n.errorForbiddenBody,
  NotFoundFailure() => l10n.errorNotFoundBody,
  _ => l10n.onboardingSubmitError,
};

QErrorKind failureKind(Failure failure) => switch (failure) {
  NetworkFailure() => QErrorKind.network,
  ServerFailure() => QErrorKind.server,
  UpstreamUnavailableFailure() => QErrorKind.sources,
  RateLimitedFailure() => QErrorKind.rateLimited,
  NotFoundFailure() => QErrorKind.notFound,
  ForbiddenFailure() => QErrorKind.forbidden,
  PayloadTooLargeFailure() => QErrorKind.tooLarge,
  UnsupportedMediaFailure() => QErrorKind.fileType,
  _ => QErrorKind.unexpected,
};
