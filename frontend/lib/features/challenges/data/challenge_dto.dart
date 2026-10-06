import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/core/network/duel_socket.dart';
import 'package:qabas/features/challenges/domain/challenge.dart';
import 'package:qabas/shared/data/dtos/content_dto.dart';
import 'package:qabas/shared/data/mappers/content_mappers.dart';
import 'package:qabas/shared/domain/entities/content.dart';
part 'challenge_dto.g.dart';

@JsonSerializable()
final class ChallengeDto {
  const ChallengeDto({
    required this.duelId,
    required this.status,
    required this.mode,
    required this.preset,
    required this.opponentType,
    required this.players,
    required this.config,
    required this.wsUrl,
    required this.createdAt,
    required this.expiresAt,
    required this.result,
  });
  factory ChallengeDto.fromJson(Map<String, dynamic> json) => _$ChallengeDtoFromJson(json);
  final String duelId, status, mode, preset, opponentType, wsUrl, createdAt, expiresAt;
  final List<Map<String, dynamic>> players;
  final Map<String, dynamic> config;
  @JsonKey(required: true)
  final Map<String, dynamic>? result;
  Challenge toEntity() => Challenge(
    id: duelId,
    status: status,
    mode: mode,
    preset: switch (preset) {
      'duel' => ChallengePreset.duel,
      'group' => ChallengePreset.group,
      _ => throw const FormatException('Unknown challenge preset'),
    },
    players: players
        .map(
          (p) => ChallengePlayer(
            p['user_id'] as String,
            p['display_name'] as String,
            p['avatar_key'] as String,
            p['is_me'] as bool,
            p['is_bot'] as bool,
            p['status'] as String,
          ),
        )
        .toList(),
    config: ChallengeConfig(config['question_count'] as int, config['time_limit_ms'] as int, config['reveal_ms'] as int),
    wsUrl: Uri.parse(wsUrl),
    createdAt: DateTime.parse(createdAt),
    expiresAt: DateTime.parse(expiresAt),
    result: result == null ? null : challengeResult(result!),
  );
}

List<ContentSpan> _spans(dynamic rows) => contentSpans((rows as List).cast<Map<String, dynamic>>().map(SpanDto.fromJson).toList());
ChallengeChoice challengeChoice(Map<String, dynamic> j) {
  if (j['option_id'] is String) return ChallengeChoice(optionId: j['option_id'] as String);
  if (j['value'] is bool) return ChallengeChoice(value: j['value'] as bool);
  throw const FormatException('Unsupported closed answer');
}

Map<String, Object?> encodeChoice(ChallengeChoice choice) => {
  if (choice.optionId != null) 'option_id': choice.optionId,
  if (choice.value != null) 'value': choice.value,
};
Map<String, int> _totals(dynamic rows) => {
  for (final row in (rows as List).cast<Map<String, dynamic>>()) row['user_id'] as String: row['points'] as int,
};
ChallengeResult challengeResult(Map<String, dynamic> j) => ChallengeResult(
  (j['winner_user_ids'] as List).cast<String>(),
  j['is_draw'] as bool,
  (j['scores'] as List)
      .cast<Map<String, dynamic>>()
      .map((s) => ChallengeScore(s['user_id'] as String, s['rank'] as int, s['points'] as int, s['correct'] as int))
      .toList(),
  j['xp_awarded'] as int,
);
ChallengeQuestion challengeQuestion(Map<String, dynamic> j) {
  final ex = j['exercise'] as Map<String, dynamic>, payload = ex['payload'] as Map<String, dynamic>;
  final type = ex['type'];
  if (!['multiple_choice', 'verse_meaning', 'true_false'].contains(type)) throw const FormatException('Unsupported challenge exercise');
  final options = type == 'true_false'
      ? <ChallengeOption>[
          ChallengeOption(const ChallengeChoice(value: true), const []),
          ChallengeOption(const ChallengeChoice(value: false), const []),
        ]
      : (payload['options'] as List)
            .cast<Map<String, dynamic>>()
            .map((o) => ChallengeOption(ChallengeChoice(optionId: o['option_id'] as String), _spans(o['spans'])))
            .toList();
  return ChallengeQuestion(
    index: j['question_index'] as int,
    total: j['total'] as int,
    prompt: _spans(ex['prompt']),
    statement: payload['statement'] == null ? const [] : _spans(payload['statement']),
    options: options,
    issuedAt: DateTime.parse(j['issued_at'] as String),
    deadline: DateTime.parse(j['deadline_at'] as String),
    verse: payload['verse'] == null ? null : EvidenceDto.fromJson(payload['verse'] as Map<String, dynamic>).toEntity(),
  );
}

ChallengeReveal challengeReveal(Map<String, dynamic> j) => ChallengeReveal(
  j['question_index'] as int,
  challengeChoice(j['correct_answer'] as Map<String, dynamic>),
  _spans(j['explanation']),
  (j['players'] as List)
      .cast<Map<String, dynamic>>()
      .map((p) => ChallengePlayerAnswer(p['user_id'] as String, p['correct'] as bool, p['elapsed_ms'] as int, p['points'] as int))
      .toList(),
  _totals(j['totals']),
);
ChallengeUpdate decodeChallengeEvent(WsEvent event) {
  final d = Map<String, dynamic>.from(event.data);
  switch (event.type) {
    case 'state':
      final duel = ChallengeDto.fromJson(d['duel'] as Map<String, dynamic>).toEntity(), live = d['live'] as Map<String, dynamic>?;
      return ChallengeSnapshot(
        challenge: duel,
        serverTime: DateTime.parse(d['server_ts'] as String),
        phase: live == null
            ? ChallengePhase.lobby
            : switch (live['phase']) {
                'countdown' => ChallengePhase.countdown,
                'question' => ChallengePhase.question,
                'result' => ChallengePhase.reveal,
                'finished' => ChallengePhase.results,
                _ => throw const FormatException('Unknown live phase'),
              },
        question: live?['question'] == null ? null : challengeQuestion(live!['question'] as Map<String, dynamic>),
        deadline: live?['deadline_at'] == null ? null : DateTime.parse(live!['deadline_at'] as String),
        answer: live?['my_answer'] == null
            ? null
            : challengeChoice((live!['my_answer'] as Map<String, dynamic>)['answer'] as Map<String, dynamic>),
        answered: live == null ? const {} : (live['answered_user_ids'] as List).cast<String>().toSet(),
        totals: live == null ? const {} : _totals(live['totals']),
        reveals: live == null ? const [] : (live['results_so_far'] as List).cast<Map<String, dynamic>>().map(challengeReveal).toList(),
      );
    case 'countdown':
      return ChallengeCountdown(DateTime.parse(d['starts_at'] as String));
    case 'question':
      return ChallengeQuestionIssued(challengeQuestion(d));
    case 'answer_received':
      return ChallengeAnswerLocked(d['question_index'] as int);
    case 'opponent_answered':
      return ChallengeOpponentAnswered(d['question_index'] as int, d['user_id'] as String);
    case 'player_ready':
      return ChallengePlayerStatus(d['user_id'] as String, 'joined');
    case 'player_status':
      return ChallengePlayerStatus(d['user_id'] as String, d['status'] as String);
    case 'player_left':
      return ChallengePlayerStatus(d['user_id'] as String, 'declined');
    case 'opponent_disconnected':
      return ChallengeConnectionChanged(
        d['user_id'] as String,
        Duration(milliseconds: d['grace_ms'] as int), // rules:allow server duration
      ); // rules:allow wire duration, not a motion constant
    case 'opponent_reconnected':
      return ChallengeConnectionChanged(d['user_id'] as String, null);
    case 'question_result':
      return ChallengeRevealed(challengeReveal(d));
    case 'finished':
      return ChallengeFinished(
        challengeResult(d['result'] as Map<String, dynamic>),
        (d['summary'] as List)
            .cast<Map<String, dynamic>>()
            .map(
              (s) => ChallengeSummary(
                s['question_index'] as int,
                _spans(s['prompt']),
                challengeChoice(s['correct_answer'] as Map<String, dynamic>),
                _spans(s['explanation']),
              ),
            )
            .toList(),
      );
    case 'error':
      throw ChallengeSocketFailure(d['code'] as String);
    case 'pong':
      return const ChallengePong();
    default:
      throw const FormatException('Unknown socket event');
  }
}

final class ChallengeSocketFailure implements Exception {
  const ChallengeSocketFailure(this.code);
  final String code;
}
