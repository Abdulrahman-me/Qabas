// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'community_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LeagueMemberDto _$LeagueMemberDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'LeagueMemberDto',
  json,
  ($checkedConvert) {
    final val = LeagueMemberDto(
      rank: $checkedConvert('rank', (v) => (v as num).toInt()),
      userId: $checkedConvert('user_id', (v) => v as String),
      displayName: $checkedConvert('display_name', (v) => v as String),
      xpWeek: $checkedConvert('xp_week', (v) => (v as num).toInt()),
      isMe: $checkedConvert('is_me', (v) => v as bool),
      avatarKey: $checkedConvert('avatar_key', (v) => v as String),
      inPromotionZone: $checkedConvert('in_promotion_zone', (v) => v as bool),
    );
    return val;
  },
  fieldKeyMap: const {
    'userId': 'user_id',
    'displayName': 'display_name',
    'xpWeek': 'xp_week',
    'isMe': 'is_me',
    'avatarKey': 'avatar_key',
    'inPromotionZone': 'in_promotion_zone',
  },
);

LeagueTierDto _$LeagueTierDtoFromJson(Map<String, dynamic> json) => $checkedCreate('LeagueTierDto', json, ($checkedConvert) {
  final val = LeagueTierDto(
    tierKey: $checkedConvert('tier_key', (v) => v as String),
    index: $checkedConvert('index', (v) => (v as num).toInt()),
    name: $checkedConvert('name', (v) => v as String),
    isTopTier: $checkedConvert('is_top_tier', (v) => v as bool),
  );
  return val;
}, fieldKeyMap: const {'tierKey': 'tier_key', 'isTopTier': 'is_top_tier'});

LeagueDto _$LeagueDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'LeagueDto',
  json,
  ($checkedConvert) {
    final val = LeagueDto(
      leagueId: $checkedConvert('league_id', (v) => v as String),
      weekStart: $checkedConvert('week_start', (v) => v as String),
      weekEnd: $checkedConvert('week_end', (v) => v as String),
      endsInSeconds: $checkedConvert('ends_in_seconds', (v) => (v as num).toInt()),
      myRank: $checkedConvert('my_rank', (v) => (v as num).toInt()),
      tier: $checkedConvert('tier', (v) => LeagueTierDto.fromJson(v as Map<String, dynamic>)),
      promotionZoneSize: $checkedConvert('promotion_zone_size', (v) => (v as num).toInt()),
      demotion: $checkedConvert('demotion', (v) => v as bool),
      members: $checkedConvert(
        'members',
        (v) => (v as List<dynamic>).map((e) => LeagueMemberDto.fromJson(e as Map<String, dynamic>)).toList(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'leagueId': 'league_id',
    'weekStart': 'week_start',
    'weekEnd': 'week_end',
    'endsInSeconds': 'ends_in_seconds',
    'myRank': 'my_rank',
    'promotionZoneSize': 'promotion_zone_size',
  },
);

QuestDto _$QuestDtoFromJson(Map<String, dynamic> json) => $checkedCreate('QuestDto', json, ($checkedConvert) {
  final val = QuestDto(
    questId: $checkedConvert('quest_id', (v) => v as String),
    kind: $checkedConvert('kind', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    progress: $checkedConvert('progress', (v) => (v as num).toInt()),
    goal: $checkedConvert('goal', (v) => (v as num).toInt()),
    rewardXp: $checkedConvert('reward_xp', (v) => (v as num).toInt()),
    completed: $checkedConvert('completed', (v) => v as bool),
  );
  return val;
}, fieldKeyMap: const {'questId': 'quest_id', 'rewardXp': 'reward_xp'});

QuestsDto _$QuestsDtoFromJson(Map<String, dynamic> json) => $checkedCreate('QuestsDto', json, ($checkedConvert) {
  final val = QuestsDto(
    date: $checkedConvert('date', (v) => v as String),
    resetsInSeconds: $checkedConvert('resets_in_seconds', (v) => (v as num).toInt()),
    items: $checkedConvert('items', (v) => (v as List<dynamic>).map((e) => QuestDto.fromJson(e as Map<String, dynamic>)).toList()),
  );
  return val;
}, fieldKeyMap: const {'resetsInSeconds': 'resets_in_seconds'});

FriendDto _$FriendDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'FriendDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['xp_week', 'streak_current']);
    final val = FriendDto(
      userId: $checkedConvert('user_id', (v) => v as String),
      displayName: $checkedConvert('display_name', (v) => v as String),
      avatarKey: $checkedConvert('avatar_key', (v) => v as String),
      xpWeek: $checkedConvert('xp_week', (v) => (v as num?)?.toInt()),
      streakCurrent: $checkedConvert('streak_current', (v) => (v as num?)?.toInt()),
      online: $checkedConvert('online', (v) => v as bool),
    );
    return val;
  },
  fieldKeyMap: const {
    'userId': 'user_id',
    'displayName': 'display_name',
    'avatarKey': 'avatar_key',
    'xpWeek': 'xp_week',
    'streakCurrent': 'streak_current',
  },
);

FriendInviteDto _$FriendInviteDtoFromJson(Map<String, dynamic> json) => $checkedCreate('FriendInviteDto', json, ($checkedConvert) {
  final val = FriendInviteDto(
    inviteId: $checkedConvert('invite_id', (v) => v as String),
    code: $checkedConvert('code', (v) => v as String),
    shareText: $checkedConvert('share_text', (v) => v as String),
    expiresAt: $checkedConvert('expires_at', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'inviteId': 'invite_id', 'shareText': 'share_text', 'expiresAt': 'expires_at'});

FriendsDto _$FriendsDtoFromJson(Map<String, dynamic> json) => $checkedCreate('FriendsDto', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['next_cursor']);
  final val = FriendsDto(
    items: $checkedConvert('items', (v) => (v as List<dynamic>).map((e) => FriendDto.fromJson(e as Map<String, dynamic>)).toList()),
    nextCursor: $checkedConvert('next_cursor', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'nextCursor': 'next_cursor'});
