import 'dart:convert';

import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/mock_backend/controls/mock_controls.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_db.dart';
import 'package:qabas/mock_backend/mock_router.dart';
import 'package:uuid/uuid.dart';

void registerRaqeeb(MockRouter router, MockDb db, Fixtures fixtures, MockControls controls) {
  final messages = db.raqeebMessages;
  final work = db.raqeebWork;
  String id(String prefix) => '${prefix}_${const Uuid().v4()}';
  String stamp() => db.now().toUtc().toIso8601String();
  BackendResponse missing() => BackendResponse.error(404, 'not_found', 'Resource not found');
  // TODO(contract): A-43 — unchanged Arabic A–H examples are the supplied demo answers in both UI languages.
  Future<Map<String, dynamic>> advance(String key) async {
    final current = messages[key]!;
    if (current['status'] != 'processing') return current;
    final task = work[key]!;
    final index = controls.fast
        ? task['polls'] as int
        : db.now().difference(DateTime.parse(task['accepted'] as String)).inMilliseconds ~/ 1200;
    task['polls'] = (task['polls'] as int) + 1;
    const stages = ['reading_inputs', 'classifying', 'retrieving', 'verifying', 'writing', 'adapting'];
    if (index < stages.length) {
      current['stage'] = stages[index.clamp(0, stages.length - 1)];
      return current;
    }
    final result = task['recording_answer'] is String
        ? await fixtures.object('recording/raqeeb_${task['recording_answer']}_${task['language']}.json')
        : task['outcome'] == 'failed'
        ? await fixtures.example('AssistantFailed')
        : await fixtures.object(
            'examples/RaqeebCompleted__get_raqeeb_messages_message_id__${3 + 'ABCDEFGH'.indexOf(task['outcome'] as String)}.json',
          );
    result['message_id'] = key;
    result['created_at'] = current['created_at'];
    if (result['status'] == 'completed') {
      result['completed_at'] = stamp();
      for (final row in db.conversations.values) {
        final ids = (row['message_ids'] as List).cast<String>();
        if (ids.contains(key)) {
          final conversation = row['conversation'] as Map<String, dynamic>;
          final first = ids.map((id) => messages[id]).whereType<Map<String, dynamic>>().where((m) => m['role'] == 'user').firstOrNull;
          conversation['title'] ??= first?['text'];
          conversation['updated_at'] = stamp();
        }
      }
    }
    current
      ..clear()
      ..addAll(result);
    return current;
  }

  router.routes.addAll([
    MockRoute('POST', '/raqeeb/conversations', (request, _) async {
      final body = request.body;
      if (body is! Map<String, Object?> ||
          body.keys.any((k) => k != 'context') ||
          !body.containsKey('context') ||
          (body['context'] != null && body['context'] is! Map<String, Object?>)) {
        return BackendResponse.error(400, 'validation_error', 'Invalid conversation context');
      }
      if (db.conversations.isEmpty) work.clear();
      final key = id('conv');
      final row = <String, dynamic>{
        'conversation_id': key,
        'title': null,
        'context': body['context'],
        'created_at': stamp(),
        'updated_at': stamp(),
      };
      db.conversations[key] = {'conversation': row, 'message_ids': <String>[]};
      return BackendResponse(201, row);
    }),
    MockRoute('GET', '/raqeeb/conversations', (request, _) async {
      final limit = int.tryParse('${request.query['limit'] ?? 20}'), offset = int.tryParse('${request.query['cursor'] ?? 0}');
      if (limit == null || limit < 1 || limit > 100 || offset == null || offset < 0) {
        return BackendResponse.error(400, 'validation_error', 'Invalid history cursor');
      }
      final rows = db.conversations.values.toList()
        ..sort(
          (a, b) => ((b['conversation'] as Map)['updated_at'] as String).compareTo((a['conversation'] as Map)['updated_at'] as String),
        );
      final end = (offset + limit).clamp(0, rows.length);
      if (offset > rows.length) return BackendResponse.error(400, 'validation_error', 'Invalid history cursor');
      return BackendResponse(200, {
        'items': [
          for (final row in rows.sublist(offset, end))
            {
              'conversation_id': (row['conversation'] as Map)['conversation_id'],
              'title': (row['conversation'] as Map)['title'],
              'last_message_preview': (row['message_ids'] as List)
                  .map((id) => messages[id])
                  .whereType<Map>()
                  .where((m) => m['role'] == 'user')
                  .lastOrNull?['text'],
              'updated_at': (row['conversation'] as Map)['updated_at'],
            },
        ],
        'next_cursor': end < rows.length ? '$end' : null,
      });
    }),
    MockRoute('GET', '/raqeeb/conversations/{id}', (_, params) async {
      final row = db.conversations[params['id']];
      if (row == null) return missing();
      final rows = <Map<String, dynamic>>[];
      for (final key in (row['message_ids'] as List).cast<String>()) {
        if (messages[key]?['role'] == 'assistant') await advance(key);
        if (messages[key] != null) rows.add(messages[key]!);
      }
      return BackendResponse(200, {'conversation': row['conversation'], 'messages': rows});
    }),
    MockRoute('POST', '/raqeeb/conversations/{id}/messages', (request, params) async {
      final row = db.conversations[params['id']];
      if (row == null) return missing();
      final ids = (row['message_ids'] as List).cast<String>();
      for (final key in ids) {
        if (messages[key]?['role'] == 'assistant') await advance(key);
        if (messages[key]?['status'] == 'processing') {
          return BackendResponse.error(409, 'answer_in_progress', 'An answer is still processing');
        }
      }
      final body = request.body;
      if (body is! Map<String, Object?>) return BackendResponse.error(400, 'validation_error', 'Invalid message');
      final fields = body['fields'];
      if (fields is! Map<String, Object?>) return BackendResponse.error(400, 'validation_error', 'Invalid message fields');
      final text = fields['text'];
      final files = body['files'];
      if ((text != null && text is! String) ||
          (text is String && text.runes.length > 2000) ||
          fields.keys.any((k) => k != 'text') ||
          files is! List ||
          ((text == null || (text as String).trim().isEmpty) && files.isEmpty)) {
        return BackendResponse.error(400, 'validation_error', 'A question or attachment is required');
      }
      final counts = <String, int>{};
      if (files.any((file) => file is! Map)) return BackendResponse.error(400, 'validation_error', 'Invalid attachment');
      final uploads = files.map((file) => Map<String, Object?>.from(file as Map)).toList();
      for (final file in uploads) {
        final field = file['field'], mime = file['mime_type'], length = file['length'];
        final types = switch (field) {
          'images' => ['image/jpeg', 'image/png', 'image/webp'],
          'document' => ['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
          'audio' => ['audio/mp4', 'audio/webm', 'audio/wav', 'audio/mpeg'],
          _ => <String>[],
        };
        if (!types.contains(mime)) return BackendResponse.error(415, 'unsupported_media', 'Unsupported file type');
        if (length is! int || length <= 0 || length > (field == 'images' ? 8 : 10) * 1024 * 1024) {
          return BackendResponse.error(413, 'payload_too_large', 'Attachment too large');
        }
        counts[field as String] = (counts[field] ?? 0) + 1;
        if (counts[field]! > (field == 'images' ? 3 : 1)) return BackendResponse.error(400, 'validation_error', 'Too many attachments');
      }
      final userId = id('msg_u'), assistantId = id('msg_a');
      final user = <String, dynamic>{
        'message_id': userId,
        'role': 'user',
        'status': 'received',
        'text': text,
        'attachments': [
          for (final file in uploads)
            {
              'attachment_id': id('att'),
              'kind': file['field'] == 'images'
                  ? 'image'
                  : file['field'] == 'audio'
                  ? 'audio'
                  : 'document',
              'filename': file['filename'],
              'mime': file['mime_type'],
              'size_bytes': file['length'],
              'url': file['field'] == 'images'
                  ? fixtures.recording && file['bytes'] is List
                        ? 'data:${file['mime_type']};base64,${base64Encode((file['bytes'] as List).cast<int>())}'
                        : 'mock-asset://test/u1l0.webp'
                  : null,
              'duration_ms': file['field'] == 'audio' ? file['duration_ms'] : null,
              'pages': file['field'] == 'document' ? 1 : null,
            },
        ],
        'created_at': stamp(),
      };
      final assistant = <String, dynamic>{
        'message_id': assistantId,
        'role': 'assistant',
        'status': 'processing',
        'stage': 'received',
        'created_at': stamp(),
      };
      messages[userId] = user;
      messages[assistantId] = assistant;
      ids.addAll([userId, assistantId]);
      final picked = controls.raqeebOutcome;
      // TODO(contract): A-56 — select only supplied recording answers; no model or recognition.
      final normalized = (text as String? ?? '').toLowerCase();
      final recordingAnswer = normalized.contains('hadith') || normalized.contains('حديث')
          ? 'hadith'
          : normalized.contains('arabic') || normalized.contains('العربية')
          ? 'arabic'
          : normalized.contains('islam') || normalized.contains('الإسلام')
          ? 'islam'
          : normalized.contains('pray') || normalized.contains('يصل') || normalized.contains('صلا')
          ? 'prayer'
          : 'other';
      work[assistantId] = {
        'outcome': ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'failed'].contains(picked) ? picked : 'A',
        if (fixtures.recording && picked == 'auto') ...{
          'recording_answer': recordingAnswer,
          'language': request.header('Accept-Language') ?? 'en',
        },
        'accepted': stamp(),
        'polls': 0,
      };
      (row['conversation'] as Map<String, dynamic>)['updated_at'] = stamp();
      return BackendResponse(202, jsonDecode(jsonEncode({'user_message': user, 'assistant_message': assistant})));
    }),
    MockRoute('GET', '/raqeeb/messages/{id}', (_, params) async {
      final key = params['id']!;
      // A reset removes ownership, including every pending answer.
      final owned = db.conversations.values.any((r) => (r['message_ids'] as List).contains(key));
      if (!owned || messages[key]?['role'] != 'assistant') return missing();
      return BackendResponse(200, await advance(key));
    }),
    MockRoute('POST', '/raqeeb/messages/{id}/feedback', (request, params) async {
      final owned = db.conversations.values.any((r) => (r['message_ids'] as List).contains(params['id']));
      final message = messages[params['id']];
      if (!owned || message == null) return missing();
      final body = request.body;
      if (message['status'] != 'completed' ||
          body is! Map<String, Object?> ||
          !['up', 'down'].contains(body['rating']) ||
          !body.containsKey('reason') ||
          !body.containsKey('comment') ||
          ![null, 'inaccurate', 'unclear', 'not_helpful', 'other'].contains(body['reason']) ||
          body.keys.any((k) => !['rating', 'reason', 'comment'].contains(k))) {
        return BackendResponse.error(400, 'validation_error', 'Invalid answer feedback');
      }
      message['feedback'] = body['rating'];
      return const BackendResponse(204, null);
    }),
  ]);
}
