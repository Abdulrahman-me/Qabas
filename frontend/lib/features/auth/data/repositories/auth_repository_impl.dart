import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:qabas/features/auth/domain/repositories/auth_repository.dart';
import 'package:qabas/shared/data/mappers/core_mappers.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

final class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this.remote, this.tokens, {Future<String> Function()? timezone}) : timezone = timezone ?? _deviceTimezone;
  final AuthRemoteDataSource remote;
  final TokenStore tokens;
  final Future<String> Function() timezone;
  // TODO(contract): A-12 — device IANA zone, with UTC when unavailable.
  static Future<String> _deviceTimezone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return 'UTC';
    }
  }

  @override
  Future<Result<bool>> hasSession() => guard(() async => await tokens.read() != null);
  @override
  Future<Result<UserProfile>> createGuest() => guard(() async {
    final response = await remote.createGuest(await timezone());
    await tokens.write(response.accessToken);
    return response.user.toEntity();
  });
  @override
  Future<Result<UserProfile>> currentUser() => guard(() async => (await remote.currentUser()).toEntity());
  @override
  Future<Result<void>> clearSession() => guard(tokens.clear);
}
