import 'dart:async';

import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/shared/data/datasources/journey_remote_data_source.dart';
import 'package:qabas/shared/data/mappers/core_mappers.dart';
import 'package:qabas/shared/data/mappers/journey_mappers.dart';
import 'package:qabas/shared/data/mappers/stats_mappers.dart';
import 'package:qabas/shared/domain/entities/journey.dart';
import 'package:qabas/shared/domain/entities/next_step.dart';
import 'package:qabas/shared/domain/entities/stats.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';
import 'package:qabas/shared/domain/repositories/journey_repository.dart';

final class JourneyRepositoryImpl implements JourneyRepository {
  JourneyRepositoryImpl(this.remote, this.events, this.language) {
    _subscription = events.on<AppEvent>().listen((event) {
      if (event is SessionCompleted || event is ProfileChanged || event is GuestSessionCleared || event is LearningProgressChanged) {
        _epoch++;
        _cache = null;
      }
    });
  }
  final JourneyRemoteDataSource remote;
  final AppEventBus events;
  final String Function() language;
  late final StreamSubscription<AppEvent> _subscription;
  Journey? _cache;
  String? _cacheLanguage;
  int _epoch = 0, _readSerial = 0;
  @override
  Journey? get cachedJourney => _cacheLanguage == language() ? _cache : null;
  @override
  SoftLock? prerequisiteLock(ConflictFailure failure) {
    if (failure.code != 'prerequisite_unmet') return null;
    final data = cachedJourney;
    final ids = failure.details['prerequisite_lesson_ids'];
    final start = failure.details['start_with_lesson_id'];
    if (data == null || ids is! List || start is! String || ids.isEmpty) return null;
    LessonRef? ref(String id) {
      final lesson = data.lesson(id), unit = data.unitFor(id);
      return lesson == null || unit == null ? null : LessonRef(lessonId: id, unitId: unit.unitId, title: lesson.title);
    }

    final references = ids.whereType<String>().map(ref).whereType<LessonRef>().toList();
    final entry = data.lesson(start), first = ref(start);
    if (references.length != ids.length ||
        first == null ||
        entry == null ||
        [LessonState.locked, LessonState.unknown].contains(entry.state)) {
      return null;
    }
    return SoftLock(prerequisites: references, startWith: first);
  }

  @override
  Future<Result<Journey>> loadJourney({bool refresh = false}) => guard(() async {
    if (!refresh && cachedJourney != null) return cachedJourney!;
    final epoch = _epoch, locale = language(), serial = ++_readSerial;
    final result = (await remote.journey()).toEntity();
    if (epoch == _epoch && serial == _readSerial && locale == language()) {
      _cache = result;
      _cacheLanguage = locale;
    }
    return result;
  });
  @override
  Future<Result<NextStep>> loadNextStep() => guard(() async => (await remote.next()).toEntity());
  @override
  Future<Result<Stats>> loadStats() => guard(() async => (await remote.stats()).toEntity());
  @override
  Future<Result<UserProfile>> updateTrack(UserTrack track) => guard(() async {
    if (track == UserTrack.unknown) throw ArgumentError.value(track);
    final user = (await remote.updateTrack(track == UserTrack.newMuslim ? 'new_muslim' : 'explorer')).toEntity();
    _epoch++;
    _cache = null;
    events.publish(ProfileChanged(user));
    return user;
  });
  Future<void> dispose() => _subscription.cancel();
}
