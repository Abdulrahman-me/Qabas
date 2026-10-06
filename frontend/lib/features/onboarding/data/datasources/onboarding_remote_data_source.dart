import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/onboarding/data/dtos/onboarding_dto.dart';

final class OnboardingRemoteDataSource {
  const OnboardingRemoteDataSource(this.api);
  final ApiClient api;
  Future<OnboardingResponseDto> complete(OnboardingRequestDto request) =>
      api.post('/onboarding', body: request.toJson(), decode: OnboardingResponseDto.fromJson);
}
