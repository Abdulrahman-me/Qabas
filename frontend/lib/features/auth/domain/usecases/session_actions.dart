import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/auth/domain/repositories/auth_repository.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

final class CreateGuestSession {
  const CreateGuestSession(this.repository);
  final AuthRepository repository;
  Future<Result<UserProfile>> call() => repository.createGuest();
}

final class LoadCurrentUser {
  const LoadCurrentUser(this.repository);
  final AuthRepository repository;
  Future<Result<UserProfile>> call() => repository.currentUser();
}

final class HasStoredSession {
  const HasStoredSession(this.repository);
  final AuthRepository repository;
  Future<Result<bool>> call() => repository.hasSession();
}

final class ClearSession {
  const ClearSession(this.repository);
  final AuthRepository repository;
  Future<Result<void>> call() => repository.clearSession();
}
