import 'package:json_annotation/json_annotation.dart';
import 'package:qabas/features/community/domain/community.dart';
part 'community_dto.g.dart';

@JsonSerializable()
final class LeagueMemberDto {
  const LeagueMemberDto({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.xpWeek,
    required this.isMe,
    required this.avatarKey,
    required this.inPromotionZone,
  });
  factory LeagueMemberDto.fromJson(Map<String, dynamic> json) => _$LeagueMemberDtoFromJson(json);
  final int rank, xpWeek;
  final String userId, displayName, avatarKey;
  final bool isMe, inPromotionZone;
  LeagueMember toEntity() => LeagueMember(rank, userId, displayName, xpWeek, isMe, avatarKey, inPromotionZone);
}

@JsonSerializable()
final class LeagueTierDto {
  const LeagueTierDto({required this.tierKey, required this.index, required this.name, required this.isTopTier});
  factory LeagueTierDto.fromJson(Map<String, dynamic> json) => _$LeagueTierDtoFromJson(json);
  final String tierKey, name;
  final int index;
  final bool isTopTier;
}

@JsonSerializable()
final class LeagueDto {
  const LeagueDto({
    required this.leagueId,
    required this.weekStart,
    required this.weekEnd,
    required this.endsInSeconds,
    required this.myRank,
    required this.tier,
    required this.promotionZoneSize,
    required this.demotion,
    required this.members,
  });
  factory LeagueDto.fromJson(Map<String, dynamic> json) => _$LeagueDtoFromJson(json);
  final String leagueId, weekStart, weekEnd;
  final int endsInSeconds, myRank, promotionZoneSize;
  final LeagueTierDto tier;
  final bool demotion;
  final List<LeagueMemberDto> members;
  League toEntity() => League(
    name: tier.name,
    tier: tier.tierKey,
    topTier: tier.isTopTier,
    endsIn: endsInSeconds,
    promotionSize: promotionZoneSize,
    members: members.map((m) => m.toEntity()).toList(),
  );
}

@JsonSerializable()
final class QuestDto {
  const QuestDto({
    required this.questId,
    required this.kind,
    required this.title,
    required this.progress,
    required this.goal,
    required this.rewardXp,
    required this.completed,
  });
  factory QuestDto.fromJson(Map<String, dynamic> json) => _$QuestDtoFromJson(json);
  final String questId, kind, title;
  final int progress, goal, rewardXp;
  final bool completed;
  Quest toEntity() => Quest(questId, kind, title, progress, goal, rewardXp, completed);
}

@JsonSerializable()
final class QuestsDto {
  const QuestsDto({required this.date, required this.resetsInSeconds, required this.items});
  factory QuestsDto.fromJson(Map<String, dynamic> json) => _$QuestsDtoFromJson(json);
  final String date;
  final int resetsInSeconds;
  final List<QuestDto> items;
  Quests toEntity() => Quests(resetsInSeconds, items.map((q) => q.toEntity()).toList());
}

@JsonSerializable()
final class FriendDto {
  const FriendDto({
    required this.userId,
    required this.displayName,
    required this.avatarKey,
    required this.xpWeek,
    required this.streakCurrent,
    required this.online,
  });
  factory FriendDto.fromJson(Map<String, dynamic> json) => _$FriendDtoFromJson(json);
  final String userId, displayName, avatarKey;
  @JsonKey(required: true)
  final int? xpWeek, streakCurrent;
  final bool online;
  Friend toEntity() => Friend(userId, displayName, avatarKey, xpWeek, streakCurrent, online);
}

@JsonSerializable()
final class FriendInviteDto {
  const FriendInviteDto({required this.inviteId, required this.code, required this.shareText, required this.expiresAt});
  factory FriendInviteDto.fromJson(Map<String, dynamic> json) => _$FriendInviteDtoFromJson(json);
  final String inviteId, code, shareText, expiresAt;
  FriendInvite toEntity() => FriendInvite(code, shareText, DateTime.parse(expiresAt));
}

@JsonSerializable()
final class FriendsDto {
  const FriendsDto({required this.items, required this.nextCursor});
  factory FriendsDto.fromJson(Map<String, dynamic> json) => _$FriendsDtoFromJson(json);
  final List<FriendDto> items;
  @JsonKey(required: true)
  final String? nextCursor;
}
