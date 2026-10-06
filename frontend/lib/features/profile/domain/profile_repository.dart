import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/profile/domain/profile.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<Result<ProfileSnapshot>> load();
  Future<Result<UserProfile>> user();
  Future<Result<UserProfile>> update(ProfileEdit edit);
  Future<SettingsCuriosity?> curiosity(String language);
}

final class ProfileActions {
  const ProfileActions(this.repository);
  final ProfileRepository repository;
  Future<Result<ProfileSnapshot>> load() => repository.load();
  Future<Result<UserProfile>> user() => repository.user();
  Future<Result<UserProfile>> update(ProfileEdit edit) => repository.update(edit);
  Future<SettingsCuriosity?> curiosity(String language) => repository.curiosity(language);
}
