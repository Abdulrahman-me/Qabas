import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/features/community/data/community_dto.dart';
import 'package:qabas/features/community/domain/community.dart';

final class CommunityRepositoryImpl implements CommunityRepository {
  const CommunityRepositoryImpl(this.api);
  final ApiClient api;
  @override
  Future<Result<League>> league() => guard(() async => (await api.get('/leagues/current', decode: LeagueDto.fromJson)).toEntity());
  @override
  Future<Result<Quests>> quests() => guard(() async => (await api.get('/me/quests', decode: QuestsDto.fromJson)).toEntity());
  @override
  Future<Result<int>> invitations() => guard(() => api.get('/duels/invitations', decode: (j) => (j['items'] as List).length));
  @override
  Future<Result<List<Friend>>> friends() => guard(() async {
    final items = <Friend>[];
    String? cursor;
    do {
      final page = await api.get('/friends', query: {'cursor': ?cursor}, decode: FriendsDto.fromJson);
      items.addAll(page.items.map((f) => f.toEntity()));
      if (page.nextCursor == cursor && cursor != null) throw const FormatException('Repeated friends cursor');
      cursor = page.nextCursor;
    } while (cursor != null);
    return List.unmodifiable(items);
  });
  @override
  Future<Result<FriendInvite>> invite() =>
      guard(() async => (await api.post('/friends/invites', decode: FriendInviteDto.fromJson)).toEntity());
  @override
  Future<Result<Friend>> accept(String code) =>
      guard(() async => (await api.post('/friends/invites/accept', body: {'code': code}, decode: FriendDto.fromJson)).toEntity());
  @override
  Future<Result<void>> remove(String id) => guard(() => api.delete('/friends/${Uri.encodeComponent(id)}'));
}
