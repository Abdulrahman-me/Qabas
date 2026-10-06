import 'package:qabas/app/config/app_config.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/dev_tools/domain/repositories/dev_tools_repository.dart';
import 'package:qabas/mock_backend/mock_backend.dart';
import 'package:qabas/shared/data/dtos/auth_response_dto.dart';
import 'package:qabas/shared/data/dtos/core_requests_dto.dart';
import 'package:qabas/shared/data/dtos/user_dto.dart';
import 'package:qabas/shared/data/mappers/core_mappers.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

final class DevToolsRepositoryImpl implements DevToolsRepository {
  DevToolsRepositoryImpl({
    required this.config,
    required this.api,
    required this.tokens,
    required this.preferences,
    required this.events,
    this.mock,
  });
  final AppConfig config;
  final ApiClient api;
  final TokenStore tokens;
  final PreferencesStore preferences;
  final AppEventBus events;
  final MockBackend? mock;
  UserProfile? _probeUser;
  final Map<String, String> _lessons = {}, _unit0 = {};
  Future<DevSnapshot> _snapshot() async {
    if (mock != null && _lessons.isEmpty) {
      final curriculum = await mock!.fixtures.object('demo_curriculum/curriculum.json');
      final units = curriculum['units'] as List<dynamic>;
      for (final unit in units.cast<Map<String, dynamic>>()) {
        for (final lesson in (unit['lessons'] as List<dynamic>).cast<Map<String, dynamic>>()) {
          _lessons[lesson['lesson_id'] as String] = lesson['lesson_id'] as String;
          if (unit['index'] == 0) _unit0[lesson['lesson_id'] as String] = (lesson['title'] as Map)['en'] as String;
        }
      }
    }
    if (mock != null) {
      final practice = await mock!.fixtures.object('contract/sessions/session_practice_all_types.json');
      _unit0[practice['lesson_id'] as String] = 'Contract practice: all exercise types';
    }
    final controls = mock?.controls;
    return DevSnapshot(
      mode: config.mode.name,
      baseUrl: config.baseUrl,
      liveGroups: config.liveGroups.map((group) => group.name).join(', '),
      mockAvailable: mock != null,
      devFlagsEnabled: config.flavor == AppFlavor.dev,
      serverContract: api.serverContract,
      probeUser: _probeUser,
      probeClient: mock?.lastRequest?.header('Qabas-Client'),
      probeLanguage: mock?.lastRequest?.header('Accept-Language'),
      probeContract: mock?.lastRequest?.header('Qabas-Contract'),
      lessonChoices: Map.unmodifiable(_lessons),
      unit0Choices: Map.unmodifiable(_unit0),
      values: {
        DevOption.reviewStale: controls?.reviewStale ?? false,
        DevOption.prepareRecording: config.recordingDemo,
        DevOption.contractCurriculum: mock?.db.contractCurriculum ?? false,
        DevOption.fast: controls?.fast ?? false,
        DevOption.offline: controls?.offline ?? false,
        DevOption.raqeebOutcome: controls?.raqeebOutcome ?? 'A',
        DevOption.recitationUnclear: controls?.recitationUnclear ?? false,
        DevOption.recitationOutcome: controls?.recitationOutcome ?? 'errors',
        DevOption.noLeague: mock?.db.noLeague ?? false,
        DevOption.botSpeed: controls?.botSpeed ?? 1.0,
        DevOption.unknownVisual: controls?.unknownVisual ?? false,
        DevOption.hideDraftNotices: controls?.hideDraftNotices ?? config.hideDraftNotices,
        DevOption.curiosityOnboarding: controls?.curiosityOnboarding ?? config.curiosityOnboarding,
        DevOption.track: mock?.db.user?['track'] ?? 'explorer',
      },
    );
  }

  @override
  Future<Result<DevSnapshot>> inspect() => guard(_snapshot);
  @override
  Future<Result<DevSnapshot>> probe() => guard(() async {
    if (await tokens.read() == null) {
      final auth = await api.post('/auth/guest', body: const GuestRequestDto('UTC').toJson(), decode: AuthResponseDto.fromJson);
      await tokens.write(auth.accessToken);
    }
    _probeUser = (await api.get('/me', decode: UserDto.fromJson)).toEntity();
    return _snapshot();
  });
  @override
  Future<Result<DevSnapshot>> change(DevOption option, Object? value) => guard(() async {
    if (option == DevOption.clearLocal) {
      await preferences.clearLocal();
      return _snapshot();
    }
    final backend = mock;
    if (backend == null) throw StateError('Mock controls are unavailable in live mode');
    final controls = backend.controls;
    switch (option) {
      case DevOption.contractCurriculum:
        backend.db.contractCurriculum = value as bool;
        events.publish(const LearningProgressChanged());
      case DevOption.fast:
        controls.fast = value as bool;
      case DevOption.offline:
        controls.offline = value as bool;
      case DevOption.nextStatus:
        controls.nextStatus = value as int;
        if (value == 401 || value == 426) await _probeAuthNotice();
      case DevOption.revoke:
        backend.db.tokens.clear();
        backend.db.tokenDigests.clear();
        await backend.persist();
        await _probeAuthNotice();
      case DevOption.reset:
        backend.db.reset();
        controls.reset();
        await tokens.clear();
        _probeUser = null;
        await backend.persist();
        events.publish(const GuestSessionCleared());
      case DevOption.raqeebOutcome:
        controls.raqeebOutcome = value as String;
      case DevOption.resetReviewer:
        if (config.recordingDemo) {
          controls.reviewerReset++;
          events.publish(const ReviewerSamplesReset());
        }
      case DevOption.prepareRecording:
        if (config.recordingDemo && backend.db.user?['role'] == 'learner') {
          backend.db.dueReviews = 12;
          controls.offline = false;
          controls.nextStatus = null;
          controls.raqeebOutcome = 'auto';
          events.publish(const LearningProgressChanged());
        }
      case DevOption.reviewStale:
        controls.reviewStale = value as bool;
      case DevOption.recitationUnclear:
        if (config.flavor == AppFlavor.dev) controls.recitationUnclear = value as bool;
      case DevOption.recitationOutcome:
        if (config.flavor == AppFlavor.dev) {
          controls.recitationOutcome = value as String;
          controls.recitationUnclear = false;
        }
      case DevOption.noLeague:
        mock?.db.noLeague = value as bool;
        events.publish(const XpChanged());
      case DevOption.botSpeed:
        controls.botSpeed = value as double;
      case DevOption.unknownVisual:
        controls.unknownVisual = value as bool;
      case DevOption.hideDraftNotices:
        if (config.flavor == AppFlavor.dev) controls.hideDraftNotices = value as bool;
      case DevOption.curiosityOnboarding:
        if (config.flavor == AppFlavor.dev) controls.curiosityOnboarding = value as bool;
      case DevOption.completedLesson:
        backend.db.completedLessons.add(value as String);
        backend.db.inProgressLessons.remove(value);
        events.publish(const LearningProgressChanged());
      case DevOption.resetProgress:
        backend.db.completedLessons.clear();
        backend.db.inProgressLessons.clear();
        events.publish(const LearningProgressChanged());
      case DevOption.track:
        final user = await api.patch(
          '/me',
          body: MePatchDto(track: value as String).toJson(),
          decode: UserDto.fromJson,
        );
        events.publish(ProfileChanged(user.toEntity()));
      case DevOption.referencePreviewReset:
        // TODO(contract): A-37 — replace only the developer reference snapshot.
        backend.db.sessions.removeWhere((_, s) => s['lesson_id'] == 'les_u1_l3');
      case DevOption.clearLocal:
        break;
    }
    await backend.persist();
    return _snapshot();
  });
  Future<void> _probeAuthNotice() async {
    try {
      await api.get('/me', decode: UserDto.fromJson);
    } on FailureSource {
      /* The global auth gate handles this notice. */
    }
  }
}
