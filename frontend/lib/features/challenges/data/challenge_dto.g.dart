// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChallengeDto _$ChallengeDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ChallengeDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['result']);
    final val = ChallengeDto(
      duelId: $checkedConvert('duel_id', (v) => v as String),
      status: $checkedConvert('status', (v) => v as String),
      mode: $checkedConvert('mode', (v) => v as String),
      preset: $checkedConvert('preset', (v) => v as String),
      opponentType: $checkedConvert('opponent_type', (v) => v as String),
      players: $checkedConvert('players', (v) => (v as List<dynamic>).map((e) => e as Map<String, dynamic>).toList()),
      config: $checkedConvert('config', (v) => v as Map<String, dynamic>),
      wsUrl: $checkedConvert('ws_url', (v) => v as String),
      createdAt: $checkedConvert('created_at', (v) => v as String),
      expiresAt: $checkedConvert('expires_at', (v) => v as String),
      result: $checkedConvert('result', (v) => v as Map<String, dynamic>?),
    );
    return val;
  },
  fieldKeyMap: const {
    'duelId': 'duel_id',
    'opponentType': 'opponent_type',
    'wsUrl': 'ws_url',
    'createdAt': 'created_at',
    'expiresAt': 'expires_at',
  },
);
