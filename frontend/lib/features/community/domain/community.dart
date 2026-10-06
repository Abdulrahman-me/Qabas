import 'package:equatable/equatable.dart';
import 'package:qabas/core/error/result.dart';

final class LeagueMember extends Equatable {
  const LeagueMember(this.rank, this.id, this.name, this.xp, this.isMe, this.avatar, this.promoted);
  final int rank, xp;
  final String id, name, avatar;
  final bool isMe, promoted;
  @override
  List<Object?> get props => [rank, id, name, xp, isMe, avatar, promoted];
}

final class League extends Equatable {
  League({
    required this.name,
    required this.tier,
    required this.topTier,
    required this.endsIn,
    required this.promotionSize,
    required List<LeagueMember> members,
  }) : members = List.unmodifiable(members);
  final String name, tier;
  final bool topTier;
  final int endsIn, promotionSize;
  final List<LeagueMember> members;
  @override
  List<Object?> get props => [name, tier, topTier, endsIn, promotionSize, members];
}

final class Quest extends Equatable {
  const Quest(this.id, this.kind, this.title, this.progress, this.goal, this.reward, this.completed);
  final String id, kind, title;
  final int progress, goal, reward;
  final bool completed;
  @override
  List<Object?> get props => [id, kind, title, progress, goal, reward, completed];
}

final class Quests extends Equatable {
  Quests(this.resetsIn, List<Quest> items) : items = List.unmodifiable(items);
  final int resetsIn;
  final List<Quest> items;
  @override
  List<Object?> get props => [resetsIn, items];
}

final class Friend extends Equatable {
  const Friend(this.id, this.name, this.avatar, this.xp, this.streak, this.online);
  final String id, name, avatar;
  final int? xp, streak;
  final bool online;
  @override
  List<Object?> get props => [id, name, avatar, xp, streak, online];
}

final class FriendInvite extends Equatable {
  const FriendInvite(this.code, this.shareText, this.expiresAt);
  final String code, shareText;
  final DateTime expiresAt;
  @override
  List<Object?> get props => [code, shareText, expiresAt];
}

abstract interface class CommunityRepository {
  Future<Result<League>> league();
  Future<Result<Quests>> quests();
  Future<Result<int>> invitations();
  Future<Result<List<Friend>>> friends();
  Future<Result<FriendInvite>> invite();
  Future<Result<Friend>> accept(String code);
  Future<Result<void>> remove(String id);
}

final class CommunityActions {
  const CommunityActions(this.repository);
  final CommunityRepository repository;
  Future<Result<League>> league() => repository.league();
  Future<Result<Quests>> quests() => repository.quests();
  Future<Result<int>> invitations() => repository.invitations();
  Future<Result<List<Friend>>> friends() => repository.friends();
  Future<Result<FriendInvite>> invite() => repository.invite();
  Future<Result<Friend>> accept(String code) => repository.accept(code.trim().toUpperCase());
  Future<Result<void>> remove(String id) => repository.remove(id);
}
