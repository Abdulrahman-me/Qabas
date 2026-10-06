import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_db.dart';
import 'package:qabas/mock_backend/mock_router.dart';

void registerCommunity(MockRouter router, MockDb db, Fixtures fixtures) {
  Future<void> seed() async {
    if (db.friendsSeeded) return;
    final page = await fixtures.example('Page[Friend]');
    for (final row in (page['items'] as List).cast<Map<String, dynamic>>()) {
      db.friends[row['user_id'] as String] = row;
    }
    db.friendsSeeded = true;
  }

  router.routes.addAll([
    MockRoute('GET', '/leagues/current', (request, _) async {
      if (db.noLeague) {
        return BackendResponse.error(404, 'not_found', 'Earn embers to join this week’s league', {'reason': 'no_league_this_week'});
      }
      final league = await fixtures.example('League');
      for (final member in (league['members'] as List).cast<Map<String, dynamic>>()) {
        if (member['is_me'] == true) {
          member['user_id'] = db.user!['user_id'];
          member['display_name'] = db.user!['display_name'];
          member['avatar_key'] = db.user!['avatar_key'];
        }
      }
      return BackendResponse(200, league);
    }),
    MockRoute('GET', '/me/quests', (_, _) async => BackendResponse(200, await fixtures.example('Quests'))),
    MockRoute('GET', '/friends', (_, _) async {
      await seed();
      return BackendResponse(200, {'items': db.friends.values.toList(), 'next_cursor': null});
    }),
    MockRoute('POST', '/friends/invites', (_, _) async {
      final row = await fixtures.example('Invite');
      row['expires_at'] = db.now().toUtc().add(const Duration(days: 7)).toIso8601String();
      return BackendResponse(201, row);
    }),
    MockRoute('POST', '/friends/invites/accept', (request, _) async {
      await seed();
      final b = request.body;
      if (b is! Map || b.length != 1 || b['code'] is! String) return BackendResponse.error(400, 'validation_error', 'Invalid invite code');
      // TODO(contract): A-47 — the supplied fixture code adds a fixture-derived third friend in mock mode.
      final invite = await fixtures.example('Invite');
      if (b['code'] != invite['code']) return BackendResponse.error(409, 'invite_invalid', 'Invalid invite');
      if (db.friends.containsKey('usr_f3')) return BackendResponse.error(409, 'already_friends', 'Already friends');
      final original = db.friends.values.first;
      final friend = Map<String, dynamic>.from(original)..addAll({'user_id': 'usr_f3', 'online': true});
      db.friends['usr_f3'] = friend;
      return BackendResponse(200, friend);
    }),
    MockRoute('DELETE', '/friends/{id}', (_, params) async {
      await seed();
      db.friends.remove(params['id']);
      return const BackendResponse(204, null);
    }),
  ]);
}
