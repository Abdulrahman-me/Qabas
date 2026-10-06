import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/profile/data/profile_dto.dart';
import 'package:qabas/features/profile/domain/profile.dart';
import 'package:qabas/features/profile/domain/profile_repository.dart';
import 'package:qabas/shared/data/dtos/core_requests_dto.dart';
import 'package:qabas/shared/data/dtos/stats_dto.dart';
import 'package:qabas/shared/data/dtos/user_dto.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';
import 'package:qabas/shared/data/mappers/core_mappers.dart';
import 'package:qabas/shared/data/mappers/stats_mappers.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

final class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this.api, this.events, {AssetBundle? bundle}) : bundle = bundle ?? rootBundle {
    _subscription = events.on<GuestSessionCleared>().listen((_) => _epoch++);
  }
  final ApiClient api;
  final AppEventBus events;
  final AssetBundle bundle;
  late final StreamSubscription<GuestSessionCleared> _subscription;
  int _epoch = 0;
  @override
  Future<Result<UserProfile>> user() => guard(() async => (await api.get('/me', decode: UserDto.fromJson)).toEntity());
  @override
  Future<Result<ProfileSnapshot>> load() => guard(() async {
    final epoch = _epoch;
    final values = await Future.wait<Object>([
      api.get('/me', decode: UserDto.fromJson),
      api.get('/me/stats', decode: StatsDto.fromJson),
      api.get('/me/achievements', decode: AchievementsDto.fromJson),
      api.get('/glossary', query: {'state': 'all', 'limit': 3}, decode: WordsPreviewDto.fromJson),
    ]);
    if (epoch != _epoch) throw const _ProfileReset();
    return ProfileSnapshot(
      user: (values[0] as UserDto).toEntity(),
      stats: (values[1] as StatsDto).toEntity(),
      achievements: (values[2] as AchievementsDto).items.map((a) => a.toEntity()).toList(),
      words: (values[3] as WordsPreviewDto).items.map((t) => t.toEntity()).toList(),
    );
  });
  @override
  Future<Result<UserProfile>> update(ProfileEdit edit) => guard(() async {
    final epoch = _epoch;
    if (edit.language == UserLanguage.unknown || edit.track == UserTrack.unknown || edit == const ProfileEdit()) {
      throw ArgumentError('Unsupported or empty profile edit');
    }
    final request = MePatchDto(
      displayName: edit.displayName,
      language: edit.language?.name,
      track: edit.track == null
          ? null
          : edit.track == UserTrack.newMuslim
          ? 'new_muslim'
          : 'explorer',
      dailyGoalMinutes: edit.dailyGoal,
      privateProfile: edit.privateProfile,
      goalAnchor: edit.goalAnchor,
    );
    final user = (await api.patch('/me', body: request.toJson(), decode: UserDto.fromJson)).toEntity();
    if (epoch != _epoch) throw const _ProfileReset();
    events.publish(ProfileChanged(user));
    return user;
  });
  @override
  Future<SettingsCuriosity?> curiosity(String language) async {
    // TODO(contract): A-26/A-44 — same approved copy gate as onboarding; PATCH cannot clear an anchor with null.
    try {
      final json = jsonDecode(await bundle.loadString('assets/onboarding/curiosity.json')) as Map<String, dynamic>;
      final question = (json['question'] as Map)[language] as String?;
      final rows = (json['anchors'] as List).cast<Map<String, dynamic>>();
      const anchors = ['does_god_exist', 'who_is_god', 'quran_special', 'who_was_muhammad', 'muslim_beliefs', 'why_pray'];
      if (question == null || question.trim().isEmpty || rows.length != anchors.length) return null;
      final labels = <String, String>{};
      for (final anchor in anchors) {
        final label = (rows.singleWhere((r) => r['goal_anchor'] == anchor)['label'] as Map)[language] as String?;
        if (label == null || label.trim().isEmpty) return null;
        labels[anchor] = label;
      }
      return SettingsCuriosity(question, labels);
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() => _subscription.cancel();
}

final class _ProfileReset implements FailureSource {
  const _ProfileReset();
  @override
  Failure toFailure() => const UnauthorizedFailure();
}
