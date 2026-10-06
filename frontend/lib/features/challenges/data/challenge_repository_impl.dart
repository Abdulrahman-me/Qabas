import 'package:qabas/core/error/failures.dart';
import 'package:qabas/core/error/guard.dart';
import 'package:qabas/core/error/result.dart';
import 'package:qabas/core/network/api_client.dart';
import 'package:qabas/core/network/duel_socket.dart';
import 'package:qabas/features/challenges/data/challenge_dto.dart';
import 'package:qabas/features/challenges/domain/challenge.dart';

final class ChallengeRepositoryImpl implements ChallengeRepository {
  const ChallengeRepositoryImpl(this.api, this.sockets);
  final ApiClient api;
  final DuelSocketFactory sockets;
  @override
  Future<Result<List<ChallengeInvitee>>> friends() => guard(() async {
    final friends = <ChallengeInvitee>[], seen = <String>{};
    String? cursor;
    do {
      final page = await api.get('/friends', query: {'limit': 20, 'cursor': ?cursor}, decode: (j) => j);
      friends.addAll(
        (page['items'] as List)
            .cast<Map<String, dynamic>>()
            .map(
              (f) => ChallengeInvitee(f['user_id'] as String, f['display_name'] as String, f['avatar_key'] as String, f['online'] as bool),
            )
            .where((f) => seen.add(f.id)),
      );
      final next = page['next_cursor'] as String?;
      if (next == cursor) break;
      cursor = next;
    } while (cursor != null);
    return friends;
  });
  @override
  Future<Result<Challenge>> create(ChallengePreset preset, List<String> friends, bool botFill) => guard(() async {
    if (preset == ChallengePreset.group && (friends.isEmpty || friends.length > 3) ||
        preset == ChallengePreset.duel && friends.length > 1) {
      throw ArgumentError('Invalid challenge participants');
    }
    return (await api.post(
      '/duels',
      body: {
        'preset': preset.name,
        'opponent_type': preset == ChallengePreset.group
            ? 'friends'
            : friends.isEmpty
            ? 'bot'
            : 'friend',
        'friend_user_ids': friends,
        'bot_fill': botFill,
      },
      decode: ChallengeDto.fromJson,
    )).toEntity();
  });
  @override
  Future<Result<Challenge>> get(String id) =>
      guard(() async => (await api.get('/duels/${Uri.encodeComponent(id)}', decode: ChallengeDto.fromJson)).toEntity());
  @override
  Future<Result<List<ChallengeInvitation>>> invitations() => guard(
    () => api.get(
      '/duels/invitations',
      decode: (j) => (j['items'] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (i) => ChallengeInvitation(
              i['duel_id'] as String,
              (i['from'] as Map)['display_name'] as String,
              DateTime.parse(i['expires_at'] as String),
            ),
          )
          .toList(),
    ),
  );
  @override
  Future<Result<Challenge>> accept(String id) =>
      guard(() async => (await api.post('/duels/${Uri.encodeComponent(id)}/accept', decode: ChallengeDto.fromJson)).toEntity());
  @override
  Future<Result<void>> decline(String id) => guard(() => api.postNoContent('/duels/${Uri.encodeComponent(id)}/decline'));
  @override
  Future<Result<ChallengeConnection>> connect(Challenge challenge) =>
      guard(() async => _Connection(await sockets.connect(challenge.wsUrl)));
}

final class _Connection implements ChallengeConnection {
  _Connection(this.socket);
  final DuelSocket socket;
  @override
  Stream<Result<ChallengeUpdate>> get events => socket.events.map((event) {
    try {
      return Ok<ChallengeUpdate>(decodeChallengeEvent(event));
    } on ChallengeSocketFailure catch (e) {
      return Err<ChallengeUpdate>(ConflictFailure(e.code));
    } catch (_) {
      return const Err<ChallengeUpdate>(UnexpectedFailure('Malformed challenge event'));
    }
  });
  @override
  void ready() => socket.send(const WsReady());
  @override
  void ping() => socket.send(const WsPing());
  @override
  void answer(int index, ChallengeChoice choice) => socket.send(WsAnswer(questionIndex: index, answer: encodeChoice(choice)));
  @override
  Future<void> close() => socket.close();
}
