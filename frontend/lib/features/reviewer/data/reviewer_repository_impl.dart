import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/idempotency_key.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:qabas/features/reviewer/data/reviewer_dtos.dart';
import 'package:qabas/features/reviewer/data/reviewer_requests.dart';
import 'package:qabas/features/reviewer/domain/reviewer_models.dart';
import 'package:qabas/features/reviewer/domain/reviewer_repository.dart';
import 'package:qabas/shared/data/dtos/auth_response_dto.dart';
import 'package:qabas/shared/data/mappers/core_mappers.dart';
import 'package:qabas/shared/domain/entities/user_profile.dart';

final class ReviewerRepositoryImpl implements ReviewerRepository {
  ReviewerRepositoryImpl(this.api, this.tokens, {this.sampleEnabled = false});
  final bool sampleEnabled;
  final ApiClient api;
  final TokenStore tokens;
  @override
  String newKey() => newIdempotencyKey();
  @override
  Future<Result<UserProfile>> signIn(String email, String password) => guard(() async {
    final r = await api.post('/auth/reviewer', body: {'email': email, 'password': password}, decode: AuthResponseDto.fromJson);
    final user = r.user.toEntity();
    if (user.role != UserRole.reviewer) throw const ReviewerRoleError();
    await tokens.write(r.accessToken);
    return user;
  });
  @override
  Future<Result<UserProfile>> signInSample() => sampleEnabled
      // TODO(contract): A-57 — local competition account uses the existing mock auth route.
      ? signIn('reviewer@qabas.app', 'qabas-review')
      : Future.value(const Err<UserProfile>(ForbiddenFailure()));
  @override
  Future<Result<void>> signOut() => guard(tokens.clear);
  @override
  Future<Result<ReviewerRunPage>> runs({String? status, String? cursor}) => guard(
    () => api.get(
      '/admin/factory/runs',
      query: {'status': ?status, 'cursor': ?cursor, 'limit': 20},
      decode: (j) => ReviewerRunPage(
        (j['items'] as List).map((v) => ReviewRunRowDto.fromJson(v as Map<String, dynamic>).toEntity()).toList(),
        j['next_cursor'] as String?,
      ),
    ),
  );
  @override
  Future<Result<ReviewFactoryRun>> run(String id) =>
      guard(() => api.get('/admin/factory/runs/${Uri.encodeComponent(id)}', decode: (j) => ReviewFactoryRunDto.fromJson(j).toEntity()));
  @override
  Future<Result<ReviewFactoryRun>> create(ReviewRunCreate r, String key) => guard(
    () => api.post(
      '/admin/factory/runs',
      body: encodeReviewRunCreate(r),
      idempotencyKey: key,
      decode: (j) => ReviewFactoryRunDto.fromJson(j).toEntity(),
    ),
  );
  @override
  Future<Result<ReviewFactoryRun>> gate1(String id, ReviewGate1 r) => guard(
    () => api.post(
      '/admin/factory/runs/${Uri.encodeComponent(id)}/gate1',
      body: encodeReviewGate1(r),
      decode: (j) => ReviewFactoryRunDto.fromJson(j).toEntity(),
    ),
  );
  @override
  Future<Result<ReviewFactoryRun>> gate2(String id, ReviewGate2 r) => guard(
    () => api.post(
      '/admin/factory/runs/${Uri.encodeComponent(id)}/gate2',
      body: encodeReviewGate2(r),
      decode: (j) => ReviewFactoryRunDto.fromJson(j).toEntity(),
    ),
  );
  @override
  Future<Result<void>> regenerate(String id, String sceneId, String? reason) => guard(
    () => api.postNoContent(
      '/admin/factory/runs/${Uri.encodeComponent(id)}/images/${Uri.encodeComponent(sceneId)}/regenerate',
      body: {'reason': reason},
    ),
  );
  @override
  Future<Result<ReviewBlindPair?>> blindPair() =>
      guard(() => api.getNullable('/admin/blind-test/next', decode: (j) => ReviewBlindPairDto.fromJson(j).toEntity()));
  @override
  Future<Result<void>> blindAnswer(String id, ReviewBlindAnswer r) =>
      guard(() => api.postNoContent('/admin/blind-test/${Uri.encodeComponent(id)}', body: encodeReviewBlindAnswer(r)));
  @override
  Future<Result<ReviewMetrics>> metrics() => guard(() => api.get('/admin/metrics', decode: (j) => ReviewMetricsDto.fromJson(j).toEntity()));
}

final class ReviewerRoleError implements FailureSource {
  const ReviewerRoleError();
  @override
  Failure toFailure() => const ForbiddenFailure();
}
