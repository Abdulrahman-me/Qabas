import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/events/app_event_bus.dart';
import 'package:qabas/core/events/app_events.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/profile/data/profile_dto.dart';
import 'package:qabas/features/profile/domain/profile.dart';
import 'package:qabas/features/profile/domain/profile_extras.dart';

final class ProfileExtrasRepositoryImpl implements ProfileExtrasRepository {
  ProfileExtrasRepositoryImpl(this.api, this.tokens, this.preferences, this.events, {required this.resetPreferences});
  final ApiClient api;
  final TokenStore tokens;
  final PreferencesStore preferences;
  final AppEventBus events;
  final Future<void> Function() resetPreferences;
  bool _serverDeleted = false;
  @override
  Future<Result<List<Achievement>>> achievements() =>
      guard(() async => (await api.get('/me/achievements', decode: AchievementsDto.fromJson)).items.map((a) => a.toEntity()).toList());
  @override
  Future<Result<void>> deleteAccount() => guard(() async {
    // A failed local cleanup retries cleanup; it never repeats DELETE with the revoked token.
    if (!_serverDeleted) {
      await api.delete('/me');
      _serverDeleted = true;
    }
    await tokens.clear();
    await preferences.clear();
    await resetPreferences();
    _serverDeleted = false;
    events.publish(const GuestSessionCleared());
  });
}
