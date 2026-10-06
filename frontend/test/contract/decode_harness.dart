import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/network/duel_socket.dart';
import 'package:qabas/features/challenges/data/challenge_dto.dart';
import 'package:qabas/features/community/data/community_dto.dart';
import 'package:qabas/features/glossary/data/glossary_dto.dart';
import 'package:qabas/features/onboarding/data/dtos/onboarding_dto.dart';
import 'package:qabas/features/profile/data/profile_dto.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_dto.dart';
import 'package:qabas/features/raqeeb/data/raqeeb_mappers.dart';
import 'package:qabas/features/reviewer/data/reviewer_dtos.dart';
import 'package:qabas/features/session/data/dtos/exercise_dto.dart';
import 'package:qabas/features/session/data/dtos/recitation_dto.dart';
import 'package:qabas/features/session/data/dtos/session_dto.dart';
import 'package:qabas/features/session/data/mappers/exercise_mappers.dart';
import 'package:qabas/features/session/data/mappers/session_mappers.dart';
import 'package:qabas/features/streak/data/activity_dto.dart';
import 'package:qabas/features/unit_guide/data/unit_guide_dto.dart';
import 'package:qabas/shared/data/dtos/auth_response_dto.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
import 'package:qabas/shared/data/dtos/core_requests_dto.dart';
import 'package:qabas/shared/data/dtos/error_envelope_dto.dart';
import 'package:qabas/shared/data/dtos/journey_dto.dart';
import 'package:qabas/shared/data/dtos/next_step_dto.dart';
import 'package:qabas/shared/data/dtos/stats_dto.dart';
import 'package:qabas/shared/data/dtos/user_dto.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';
import 'package:qabas/shared/data/mappers/core_mappers.dart';
import 'package:qabas/shared/data/mappers/journey_mappers.dart';
import 'package:qabas/shared/data/mappers/stats_mappers.dart';

final decoders = <String, Object? Function(Map<String, dynamic>)>{
  'FactoryRun': (j) => ReviewFactoryRunDto.fromJson(j).toEntity(),
  'Draft': (j) => ReviewDraftDto.fromJson(j).toEntity(),
  'Gate1': (j) => ReviewGate1Dto.fromJson(j).toEntity(),
  'Gate2': (j) => ReviewGate2Dto.fromJson(j).toEntity(),
  'BlindPair': (j) => ReviewBlindPairDto.fromJson(j).toEntity(),
  'BlindAnswer': (j) => ReviewBlindAnswerDto.fromJson(j).toEntity(),
  'Metrics': (j) => ReviewMetricsDto.fromJson(j).toEntity(),
  'RunCreate': (j) => ReviewRunCreateDto.fromJson(j).toEntity(),
  'DraftFragment': (j) => ReviewDraftFragmentDto.fromJson(j).toEntity(),
  'LessonPlan': (j) => ReviewLessonPlanDto.fromJson(j).toEntity(),
  'ReviewerReq': (j) => ReviewReviewerReqDto.fromJson(j).toEntity(),
  'ReviewerExercise': (j) => ReviewReviewerExerciseDto.fromJson(j).toEntity(),
  'Page[RunRow]': (j) => (j['items'] as List).map((v) => ReviewRunRowDto.fromJson(v as Map<String, dynamic>).toEntity()).toList(),
  'League': (json) => LeagueDto.fromJson(json).toEntity(),
  'Quests': (json) => QuestsDto.fromJson(json).toEntity(),
  'Page[Friend]': (json) => FriendsDto.fromJson(json).items.map((f) => f.toEntity()).toList(),
  'Invite': (json) => FriendInviteDto.fromJson(json).toEntity(),
  'Duel': (json) => ChallengeDto.fromJson(json).toEntity(),
  'DuelResult': challengeResult,
  'RecitationCheck': (json) => RecitationCheckDto.fromJson(json).toEntity(),
  'WsEvent': (json) => decodeChallengeEvent(WsEvent(type: json['type'] as String, data: Map<String, dynamic>.from(json['data'] as Map))),
  'Achievements': (json) => AchievementsDto.fromJson(json).items.map((a) => a.toEntity()).toList(),
  'Page[TermCard]': (json) => GlossaryPageDto.fromJson(json),
  'Guide': (json) => UnitGuideDto.fromJson(json),
  'LessonRead': (json) => LessonReaderDto.fromJson(json),
  'User': (json) => UserDto.fromJson(json).toEntity(),
  'NextStep': (json) => NextStepDto.fromJson(json).toEntity(),
  'ErrorEnvelope': (json) => ErrorEnvelopeDto.fromJson(json).error.toEntity(),
  'AuthResp': (json) => AuthResponseDto.fromJson(json).user.toEntity(),
  'GuestReq': GuestRequestDto.fromJson,
  'MePatch': MePatchDto.fromJson,
  'OnboardingReq': OnboardingRequestDto.fromJson,
  'OnboardingResp': (json) => OnboardingResponseDto.fromJson(json).user.toEntity(),
  'Journey': (json) => JourneyDto.fromJson(json).toEntity(),
  'Session': (json) => SessionDto.fromJson(json).toEntity(),
  'SessionCreate': SessionCreateDto.fromJson,
  'Source': (json) => SourceDto.fromJson(json).toEntity(),
  'Evidence': (json) => EvidenceDto.fromJson(json).toEntity(),
  'Visual': (json) => VisualDto.fromJson(json).toEntity(),
  'TermCard': (json) => TermCardDto.fromJson(json).toEntity(),
  'Exercise': (json) => ExerciseHeaderDto.fromJson(json).toEntity(),
  'AnswerEvaluation': AnswerEvaluationDto.fromJson,
  'AnswerRecorded': AnswerRecordedDto.fromJson,
  'AnswerSubmit': AnswerSubmitDto.fromJson,
  'FinishReq': FinishRequestDto.fromJson,
  'SessionResult': (json) => SessionResultDto.fromJson(json).toEntity(),
  for (final type in [
    'multiple_choice',
    'flashcard',
    'fill_blank',
    'which_evidence',
    'timeline_order',
    'verse_meaning',
    'scenario',
    'true_false_reason',
    'match_pairs',
    'categorize',
    'spot_error',
    'order_steps',
    'map_place',
    'recite_verse',
  ])
    'Payload[$type]': (json) => decodeExercisePayload(type, json),
  'ConvCreate': ConversationCreateDto.fromJson,
  'FeedbackReq': AnswerFeedbackDto.fromJson,
  'RaqeebCompleted': (json) => CompletedMessageDto.fromJson(json).toEntity(),
  'AssistantProcessing': (json) => ProcessingMessageDto.fromJson(json).toEntity(),
  'AssistantFailed': (json) => FailedMessageDto.fromJson(json).toEntity(),
  'AssistantMessage': (json) => AssistantMessageDto.fromJson(json).toEntity(),
  'Conversation': (json) => ConversationDto.fromJson(json).toEntity(),
  'ConvDetail': (json) => ConversationDetailDto.fromJson(json).toEntity(),
  'PostMessageResp': (json) => PostMessageResponseDto.fromJson(json).toEntity(),
  'Referral': (json) => ReferralDto.fromJson(json).toEntity(),
  'Activity': (json) => ActivityDto.fromJson(json).toEntity(),
  'Stats': (json) => StatsDto.fromJson(json).toEntity(),
};
void contractSuite(String index, String root) {
  final rows = (jsonDecode(File(index).readAsStringSync()) as List).cast<Map<String, dynamic>>();
  final models = <String>{}, covered = <String>{};
  var count = 0;
  for (final row in rows) {
    final model = row['model'] as String;
    models.add(model);
    final decoder = decoders[model];
    if (decoder == null) continue;
    covered.add(model);
    count++;
    test('${row['file']} decodes and maps $model', () {
      final json = jsonDecode(File('$root/${row['file']}').readAsStringSync());
      if (model == 'WsEvent' && json is List) {
        for (final event in json.cast<Map<String, dynamic>>()) {
          expect(decoder(event), isNotNull);
        }
      } else {
        expect(decoder(json as Map<String, dynamic>), isNotNull);
      }
    });
  }
  test('Contract coverage report for $index', () {
    final remaining = models.difference(covered).toList()..sort();
    // Test output is intentionally explicit about unimplemented future phases.
    // ignore: avoid_print
    print(
      'Contract coverage: $count/${rows.length} files; ${covered.length}/${models.length} models. Covered: ${covered.toList()..sort()}. Remaining: $remaining',
    );
    expect(covered, contains('ErrorEnvelope'));
  });
}
