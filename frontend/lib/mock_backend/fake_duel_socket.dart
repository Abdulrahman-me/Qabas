import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/core/network/duel_socket.dart';
import 'package:qabas/mock_backend/controls/mock_controls.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_db.dart';
import 'package:qabas/mock_backend/mock_router.dart';
import 'package:uuid/uuid.dart';

/// Dev/demo coordinator. Matches outlive their sockets; ticket URLs are single use.
final class FakeDuelSocketFactory implements DuelSocketFactory {
  FakeDuelSocketFactory(this.db, this.fixtures, this.controls, {this.onFinished});
  final Future<void> Function()? onFinished;
  final MockDb db;
  final Fixtures fixtures;
  final MockControls controls;
  final Map<String, _Match> _matches = {};
  int connects = 0;
  String stamp() => db.now().toUtc().toIso8601String();
  Map<String, dynamic> _copy(Map<String, dynamic> j) => jsonDecode(jsonEncode(j)) as Map<String, dynamic>;
  Map<String, dynamic> _ticket(Map<String, dynamic> duel) {
    final row = _copy(duel)..remove('recording_language'), ticket = const Uuid().v4();
    db.socketTickets[ticket] = (id: duel['duel_id'] as String, expires: db.now().add(const Duration(seconds: 60)));
    row['ws_url'] = 'mock-ws://duels/${duel['duel_id']}?ticket=$ticket';
    return row;
  }

  void register(MockRouter router) {
    router.routes.addAll([
      MockRoute('POST', '/duels', (request, _) async {
        final b = request.body;
        if (b is! Map || !['duel', 'group'].contains(b['preset']) || b['friend_user_ids'] is! List || b['bot_fill'] is! bool) {
          return BackendResponse.error(400, 'validation_error', 'Invalid challenge');
        }
        final group = b['preset'] == 'group', ids = (b['friend_user_ids'] as List).cast<String>(), kind = b['opponent_type'];
        if (group && (kind != 'friends' || ids.isEmpty || ids.length > 3) ||
            !group && !(kind == 'bot' && ids.isEmpty || kind == 'friend' && ids.length == 1)) {
          return BackendResponse.error(400, 'validation_error', 'Invalid participants');
        }
        final duel = group ? await fixtures.object('contract/challenges/group_challenge.json') : await fixtures.example('Duel');
        final id = 'duel_${const Uuid().v4()}';
        duel.addAll({
          'duel_id': id,
          'status': group || kind == 'friend' ? 'pending' : 'ready',
          'created_at': stamp(),
          'expires_at': db.now().toUtc().add(Duration(seconds: group ? 60 : 120)).toIso8601String(),
          'ws_url': 'mock-ws://duels/$id',
          'result': null,
        });
        final fixturePlayers = (duel['players'] as List).cast<Map<String, dynamic>>();
        final me = fixturePlayers.firstWhere((p) => p['is_me'] == true)
          ..addAll({'user_id': db.user!['user_id'], 'display_name': db.user!['display_name'], 'avatar_key': db.user!['avatar_key']});
        final players = <Map<String, dynamic>>[me];
        if (group) {
          for (var i = 0; i < ids.length; i++) {
            final p = _copy(fixturePlayers[(i + 1).clamp(1, fixturePlayers.length - 1)]);
            p.addAll({'user_id': ids[i], 'status': 'invited'});
            if (db.friends[ids[i]] case final f?) {
              p.addAll({'display_name': f['display_name'], 'avatar_key': f['avatar_key']});
            }
            players.add(p);
          }
          if (b['bot_fill'] == true) {
            while (players.length < 4) {
              final p = _copy(fixturePlayers[players.length]);
              p.addAll({'user_id': 'usr_bot_${players.length}', 'is_bot': true, 'status': 'joined'});
              players.add(p);
            }
          }
        } else {
          final p = _copy(fixturePlayers.last);
          if (kind == 'friend') {
            p.addAll({'user_id': ids.first, 'is_bot': false, 'status': 'invited'});
            if (db.friends[ids.first] case final f?) {
              p.addAll({'display_name': f['display_name'], 'avatar_key': f['avatar_key']});
            }
          }
          players.add(p);
        }
        duel['players'] = players;
        if (fixtures.recording) duel['recording_language'] = request.header('Accept-Language') ?? 'en';
        db.duels[id] = duel;
        return BackendResponse(201, _ticket(duel));
      }),
      MockRoute('GET', '/duels/invitations', (_, _) async {
        // TODO(contract): A-47 — one invitation from the supplied example in mock mode; accepting creates a real coordinated match.
        if (db.duels.containsKey('invitation_consumed')) return const BackendResponse(200, {'items': <Object?>[], 'next_cursor': null});
        final page = await fixtures.example('Page[Invitation]');
        for (final item in (page['items'] as List).cast<Map<String, dynamic>>()) {
          item['created_at'] = stamp();
          item['expires_at'] = db.now().toUtc().add(const Duration(minutes: 2)).toIso8601String();
        }
        return BackendResponse(200, page);
      }),
      MockRoute('POST', '/duels/{id}/accept', (request, params) async {
        var duel = db.duels[params['id']];
        if (duel == null) {
          final invitations = (await fixtures.example('Page[Invitation]'))['items'] as List;
          if (db.duels.containsKey('invitation_consumed') || !invitations.any((item) => (item as Map)['duel_id'] == params['id'])) {
            return BackendResponse.error(404, 'not_found', 'Invitation not found');
          }
          duel = await fixtures.example('Duel');
          duel.addAll({
            'duel_id': params['id'],
            'status': 'ready',
            'created_at': stamp(),
            'expires_at': db.now().toUtc().add(const Duration(minutes: 2)).toIso8601String(),
            'result': null,
          });
          final me = (duel['players'] as List).cast<Map<String, dynamic>>().firstWhere((p) => p['is_me'] == true);
          me['user_id'] = db.user!['user_id'];
          db.duels[params['id']!] = duel;
        }
        if (duel['status'] == 'finished') return BackendResponse.error(409, 'duel_not_joinable', 'Challenge ended');
        db.duels['invitation_consumed'] = {};
        return BackendResponse(200, _ticket(duel));
      }),
      MockRoute('POST', '/duels/{id}/decline', (_, params) async {
        db.duels['invitation_consumed'] = {};
        return const BackendResponse(204, null);
      }),
      MockRoute('GET', '/duels/{id}', (_, params) async {
        final row = db.duels[params['id']];
        return row == null ? BackendResponse.error(404, 'not_found', 'Challenge not found') : BackendResponse(200, _ticket(row));
      }),
      MockRoute(
        'GET',
        '/duels',
        (_, _) async => BackendResponse(200, {
          'items': db.duels.values
              .where((d) => d.containsKey('duel_id'))
              .map((d) => Map<String, dynamic>.from(d)..remove('recording_language'))
              .toList(),
          'next_cursor': null,
        }),
      ),
    ]);
  }

  @override
  Future<DuelSocket> connect(Uri wsUrl) async {
    if (controls.offline) throw const TransportUnavailable();
    final ticket = wsUrl.queryParameters['ticket'], entry = ticket == null ? null : db.socketTickets.remove(ticket);
    final id = entry != null && db.now().isBefore(entry.expires) ? entry.id : null;
    if (id == null || id != wsUrl.pathSegments.last || !db.duels.containsKey(id)) throw const TransportUnavailable();
    connects++;
    final match = _matches[id] ??= await _Match.create(db, fixtures, controls, db.duels[id]!, onFinished);
    final socket = _FakeSocket(match);
    match.clients.add(socket);
    return socket;
  }

  /// Test/developer disconnect: the coordinator and deadlines continue running.
  Future<void> disconnect(String id) async {
    for (final socket in List<_FakeSocket>.from(_matches[id]?.clients ?? [])) {
      await socket.close();
    }
  }

  void dispose() {
    for (final match in _matches.values) {
      match.dispose();
    }
    _matches.clear();
  }
}

final class _FakeSocket implements DuelSocket {
  _FakeSocket(this.match);
  final _Match match;
  final _events = StreamController<WsEvent>();
  bool closed = false;
  @override
  Stream<WsEvent> get events => _events.stream;
  void emit(String type, Map<String, dynamic> data) {
    if (!closed) _events.add(WsEvent(type: type, data: jsonDecode(jsonEncode(data)) as Map<String, dynamic>));
  }

  @override
  void send(WsClientMessage message) {
    if (closed) throw const TransportUnavailable();
    if (match.controls.offline) {
      unawaited(close());
      return;
    }
    switch (message) {
      case WsReady():
        match.snapshot(this);
        match.start();
      case WsPing():
        emit('pong', {});
      case WsAnswer(:final questionIndex, :final answer):
        match.answer(questionIndex, answer);
    }
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    match.clients.remove(this);
    await _events.close();
  }
}

final class _Match {
  _Match(this.db, this.controls, this.duel, this.questions, this.templates, this.onFinished);
  final Future<void> Function()? onFinished;
  final MockDb db;
  final MockControls controls;
  final Map<String, dynamic> duel;
  final List<Map<String, dynamic>> questions, templates;
  final Set<_FakeSocket> clients = {};
  final List<Timer> timers = [];
  String phase = 'lobby';
  int index = -1;
  bool started = false;
  Map<String, dynamic>? question, myAnswer;
  DateTime? deadline, issuedAt;
  final Set<String> answered = {};
  final List<Map<String, dynamic>> results = [];
  final Map<String, int> totals = {}, correctCounts = {}, elapsedTotals = {};
  List<Map<String, dynamic>> get players => (duel['players'] as List).cast<Map<String, dynamic>>();
  String get myId => players.firstWhere((p) => p['is_me'] == true)['user_id'] as String;
  Map<String, dynamic> get config => duel['config'] as Map<String, dynamic>;
  static Future<_Match> create(
    MockDb db,
    Fixtures fixtures,
    MockControls controls,
    Map<String, dynamic> duel,
    Future<void> Function()? onFinished,
  ) async {
    final script =
        (await fixtures.load(
                  fixtures.recording
                      ? 'recording/challenges_${duel['recording_language'] ?? db.user?['language'] ?? 'en'}.json'
                      : 'contract/challenges/group_ws_script.json',
                )
                as List)
            .cast<Map<String, dynamic>>();
    final q = script.where((e) => e['type'] == 'question').map((e) => Map<String, dynamic>.from(e['data'] as Map)).toList();
    final r = script.where((e) => e['type'] == 'question_result').map((e) => Map<String, dynamic>.from(e['data'] as Map)).toList();
    final count = (duel['config'] as Map)['question_count'] as int;
    final match = _Match(
      db,
      controls,
      duel,
      [for (var i = 0; i < count; i++) q[i % q.length]],
      [for (var i = 0; i < count; i++) r[i % r.length]],
      onFinished,
    );
    for (final p in match.players) {
      final id = p['user_id'] as String;
      match.totals[id] = 0;
      match.correctCounts[id] = 0;
      match.elapsedTotals[id] = 0;
    }
    return match;
  }

  void emit(String type, Map<String, dynamic> data) {
    for (final client in List<_FakeSocket>.from(clients)) {
      client.emit(type, data);
    }
  }

  void later(Duration delay, void Function() callback) {
    timers.add(
      Timer(delay, () {
        if (db.duels[duel['duel_id']] != duel) return;
        callback();
      }),
    );
  }

  Map<String, dynamic> get live => {
    'phase': phase,
    'question_index': max(0, index),
    'question': question,
    'deadline_at': deadline?.toUtc().toIso8601String(),
    'answered_user_ids': answered.toList(),
    'my_answer': myAnswer == null ? null : {'answer': myAnswer, 'locked': true},
    'totals': [
      for (final e in totals.entries) {'user_id': e.key, 'points': e.value},
    ],
    'results_so_far': results,
  };
  void snapshot(_FakeSocket socket) {
    socket.emit('state', {
      'duel': Map<String, dynamic>.from(duel)..remove('recording_language'),
      'server_ts': db.now().toUtc().toIso8601String(),
      'live': phase == 'lobby' ? null : live,
    });
  }

  void start() {
    if (started) return;
    started = true;
    for (var i = 1; i < players.length; i++) {
      final p = players[i];
      later(Duration(milliseconds: controls.fast ? 20 * i : 500 * i), () {
        p['status'] = 'joined';
        emit('player_status', {'user_id': p['user_id'], 'status': 'joined'});
      });
    }
    later(Duration(milliseconds: controls.fast ? 100 : 2100), () {
      duel['status'] = 'ready';
      for (final c in clients) {
        snapshot(c);
      }
      phase = 'countdown';
      deadline = db.now().add(const Duration(seconds: 3));
      emit('countdown', {'starts_at': deadline!.toUtc().toIso8601String(), 'seconds': 3});
      later(const Duration(seconds: 3), next);
    });
  }

  void next() {
    if (index + 1 == questions.length) {
      finish();
      return;
    }
    index++;
    phase = 'question';
    duel['status'] = 'in_progress';
    myAnswer = null;
    answered.clear();
    issuedAt = db.now();
    deadline = issuedAt!.add(Duration(milliseconds: config['time_limit_ms'] as int));
    question = Map<String, dynamic>.from(questions[index])
      ..addAll({
        'question_index': index,
        'total': questions.length,
        'issued_at': issuedAt!.toUtc().toIso8601String(),
        'deadline_at': deadline!.toUtc().toIso8601String(),
      });
    emit('question', question!);
    if (duel['preset'] == 'group' && index == 0 && players.length >= 3) {
      final p = players[2];
      later(const Duration(milliseconds: 300), () => emit('opponent_disconnected', {'user_id': p['user_id'], 'grace_ms': 10000}));
      later(const Duration(milliseconds: 1500), () => emit('opponent_reconnected', {'user_id': p['user_id']}));
    }
    for (var i = 1; i < players.length; i++) {
      final p = players[i], qIndex = index;
      later(Duration(milliseconds: controls.fast ? 50 * i : (2000 + 700 * i) ~/ controls.botSpeed), () {
        if (phase != 'question' || index != qIndex) return;
        answered.add(p['user_id'] as String);
        emit('opponent_answered', {'question_index': index, 'user_id': p['user_id']});
        if (myAnswer != null && answered.length == players.length) resolve();
      });
    }
    final qIndex = index;
    later(Duration(milliseconds: config['time_limit_ms'] as int), () {
      if (phase == 'question' && index == qIndex) resolve();
    });
  }

  void answer(int questionIndex, Map<String, Object?> answer) {
    if (phase != 'question' || index != questionIndex || myAnswer != null || db.now().isAfter(deadline!)) return;
    if (answer.length != 1 || answer['option_id'] is! String) return;
    final options = ((question!['exercise'] as Map)['payload'] as Map)['options'] as List;
    if (!options.any((o) => (o as Map)['option_id'] == answer['option_id'])) return;
    myAnswer = Map<String, dynamic>.from(answer);
    answered.add(myId);
    elapsedTotals['current'] = db.now().difference(issuedAt!).inMilliseconds.clamp(0, config['time_limit_ms'] as int);
    emit('answer_received', {'question_index': index});
    if (answered.length == players.length) resolve();
  }

  int points(bool correct, int elapsed) {
    if (!correct) return 0;
    final scoring = config['scoring'] as Map;
    final value = (scoring['speed_bonus'] as int) * (1 - elapsed / (config['time_limit_ms'] as int));
    return (scoring['base'] as int) + (scoring['rounding'] == 'floor' ? value.floor() : value.round());
  }

  void resolve() {
    if (phase != 'question') return;
    phase = 'result';
    final template = templates[index], correctAnswer = template['correct_answer'] as Map;
    final rows = <Map<String, dynamic>>[];
    final opponents = (template['players'] as List).cast<Map<String, dynamic>>().where((p) => p['user_id'] != 'usr_7f3k2a').toList();
    for (var i = 0; i < players.length; i++) {
      final id = players[i]['user_id'] as String;
      final right = i == 0
          ? myAnswer != null && jsonEncode(myAnswer) == jsonEncode(correctAnswer)
          : opponents[(i - 1) % opponents.length]['correct'] as bool;
      final elapsed = i == 0
          ? (myAnswer == null ? config['time_limit_ms'] as int : elapsedTotals.remove('current')!)
          : opponents[(i - 1) % opponents.length]['elapsed_ms'] as int;
      final score = points(right, elapsed);
      totals[id] = totals[id]! + score;
      correctCounts[id] = correctCounts[id]! + (right ? 1 : 0);
      if (right) elapsedTotals[id] = elapsedTotals[id]! + elapsed;
      rows.add({'user_id': id, 'correct': right, 'elapsed_ms': elapsed, 'points': score});
    }
    final result = <String, dynamic>{
      'question_index': index,
      'correct_answer': correctAnswer,
      'explanation': template['explanation'],
      'players': rows,
      'totals': [
        for (final e in totals.entries) {'user_id': e.key, 'points': e.value},
      ],
    };
    results.add(result);
    emit('question_result', result);
    later(Duration(milliseconds: config['reveal_ms'] as int), next);
  }

  void finish() {
    phase = 'finished';
    duel['status'] = 'finished';
    final ranked = players.map((p) => p['user_id'] as String).toList()
      ..sort((a, b) {
        final diff = totals[b]!.compareTo(totals[a]!);
        return diff == 0 ? elapsedTotals[a]!.compareTo(elapsedTotals[b]!) : diff;
      });
    var rank = 1;
    final scores = <Map<String, dynamic>>[];
    for (var i = 0; i < ranked.length; i++) {
      final id = ranked[i];
      if (i > 0 && (totals[id] != totals[ranked[i - 1]] || elapsedTotals[id] != elapsedTotals[ranked[i - 1]])) rank = i + 1;
      scores.add({'user_id': id, 'rank': rank, 'points': totals[id], 'correct': correctCounts[id]});
    }
    final winners = scores.where((s) => s['rank'] == 1).map((s) => s['user_id']).toList(),
        myRank = scores.firstWhere((s) => s['user_id'] == myId)['rank'] as int;
    final xp = duel['preset'] == 'duel'
        ? (winners.length == players.length
              ? 8
              : myRank == 1
              ? 15
              : 4)
        : myRank == 1
        ? 15
        : myRank == 2
        ? 8
        : 4;
    final result = {'winner_user_ids': winners, 'is_draw': winners.length == players.length, 'scores': scores, 'xp_awarded': xp};
    duel['result'] = result;
    if (db.stats != null) {
      db.stats!['xp_total'] = (db.stats!['xp_total'] as int) + xp;
      db.stats!['xp_this_week'] = (db.stats!['xp_this_week'] as int) + xp;
    }
    if (onFinished != null) unawaited(onFinished!());
    emit('finished', {
      'result': result,
      'summary': [
        for (var i = 0; i < questions.length; i++)
          {
            'question_index': i,
            'prompt': (questions[i]['exercise'] as Map)['prompt'],
            'correct_answer': templates[i]['correct_answer'],
            'explanation': templates[i]['explanation'],
          },
      ],
    });
  }

  void dispose() {
    for (final timer in timers) {
      timer.cancel();
    }
    for (final c in List<_FakeSocket>.from(clients)) {
      unawaited(c.close());
    }
  }
}
