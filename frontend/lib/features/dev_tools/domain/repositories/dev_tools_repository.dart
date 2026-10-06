import 'package:equatable/equatable.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

enum DevOption {
  reviewStale,
  resetReviewer,
  prepareRecording,
  contractCurriculum,
  fast,
  offline,
  nextStatus,
  revoke,
  reset,
  clearLocal,
  raqeebOutcome,
  recitationUnclear,
  recitationOutcome,
  noLeague,
  botSpeed,
  unknownVisual,
  hideDraftNotices,
  curiosityOnboarding,
  completedLesson,
  resetProgress,
  track,
  referencePreviewReset,
}

final class DevSnapshot extends Equatable {
  DevSnapshot({
    required this.mode,
    required this.baseUrl,
    required this.liveGroups,
    required this.mockAvailable,
    required this.devFlagsEnabled,
    required Map<DevOption, Object?> values,
    this.serverContract,
    this.probeUser,
    this.probeClient,
    this.probeLanguage,
    this.probeContract,
    this.lessonChoices = const {},
    this.unit0Choices = const {},
  }) : values = Map.unmodifiable(values);
  final String mode, baseUrl, liveGroups;
  final String? serverContract, probeClient, probeLanguage, probeContract;
  final bool mockAvailable, devFlagsEnabled;
  final Map<DevOption, Object?> values;
  final Map<String, String> lessonChoices, unit0Choices;
  final UserProfile? probeUser;
  @override
  List<Object?> get props => [
    mode,
    baseUrl,
    liveGroups,
    mockAvailable,
    devFlagsEnabled,
    values,
    serverContract,
    probeUser,
    probeClient,
    probeLanguage,
    probeContract,
    lessonChoices,
    unit0Choices,
  ];
}

abstract interface class DevToolsRepository {
  Future<Result<DevSnapshot>> inspect();
  Future<Result<DevSnapshot>> change(DevOption option, Object? value);
  Future<Result<DevSnapshot>> probe();
}
