import 'package:qabas/core/error/result.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

abstract interface class AuthRepository {
  Future<Result<bool>> hasSession();
  Future<Result<UserProfile>> createGuest();
  Future<Result<UserProfile>> currentUser();
  Future<Result<void>> clearSession();
}
