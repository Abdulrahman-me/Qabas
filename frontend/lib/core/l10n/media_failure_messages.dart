import 'package:flutter/widgets.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';

String mediaFailureBody(Failure failure, BuildContext context) => switch (failure) {
  MicrophoneDeniedFailure() => context.l10n.mediaMicrophoneDenied,
  MediaCaptureFailure() => context.l10n.mediaCaptureFailed,
  MediaLimitFailure(:final kind, :final recitation, :final count) =>
    count
        ? context.l10n.mediaCountLimit
        : switch (kind) {
            MediaKind.image => context.l10n.mediaImageLimit,
            MediaKind.document => context.l10n.mediaDocumentLimit,
            MediaKind.audio => recitation ? context.l10n.mediaRecitationLimit : context.l10n.mediaVoiceLimit,
          },
  _ => failureBody(failure, context.l10n),
};
