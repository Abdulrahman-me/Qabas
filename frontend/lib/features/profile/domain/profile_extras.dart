import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/profile/domain/profile.dart';

abstract interface class ProfileExtrasRepository {
  Future<Result<List<Achievement>>> achievements();
  Future<Result<void>> deleteAccount();
}

final class ProfileExtrasActions {
  const ProfileExtrasActions(this.repository);
  final ProfileExtrasRepository repository;
  Future<Result<List<Achievement>>> achievements() => repository.achievements();
  Future<Result<void>> deleteAccount() => repository.deleteAccount();
}
