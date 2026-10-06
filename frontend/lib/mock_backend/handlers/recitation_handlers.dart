import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:qabas/core/network/backend_transport.dart';
import 'package:qabas/mock_backend/controls/mock_controls.dart';
import 'package:qabas/mock_backend/fixtures.dart';
import 'package:qabas/mock_backend/mock_db.dart';
import 'package:qabas/mock_backend/mock_router.dart';
import 'package:uuid/uuid.dart';

void registerRecitation(MockRouter router, MockDb db, Fixtures fixtures, MockControls controls) {
  router.routes.add(
    MockRoute('POST', '/recitation/checks', (request, _) async {
      if (controls.recitationUnavailable || controls.recitationOutcome == 'busy') {
        return BackendResponse.error(503, 'upstream_unavailable', 'Recitation checking is busy', {'retry_after_ms': 1000});
      }
      final body = request.body;
      if (body is! Map || body['fields'] is! Map || body['files'] is! List) {
        return BackendResponse.error(400, 'validation_error', 'Invalid recording');
      }
      final fields = body['fields'] as Map,
          files = body['files'] as List,
          surah = int.tryParse('${fields['surah']}'),
          ayah = int.tryParse('${fields['ayah']}');
      if (surah == null ||
          surah < 1 ||
          surah > 114 ||
          ayah == null ||
          ayah < 1 ||
          files.length != 1 ||
          fields.keys.any((k) => !['surah', 'ayah', 'word_start', 'word_end', 'exercise_id'].contains(k)) ||
          (fields['word_start'] == null) != (fields['word_end'] == null)) {
        return BackendResponse.error(400, 'validation_error', 'Invalid verse');
      }
      final start = fields['word_start'] == null ? null : int.tryParse('${fields['word_start']}'),
          end = fields['word_end'] == null ? null : int.tryParse('${fields['word_end']}');
      if (fields['word_start'] != null && (start == null || end == null || start < 1 || end < start)) {
        return BackendResponse.error(400, 'validation_error', 'Invalid word range');
      }
      if (files.single is! Map) return BackendResponse.error(400, 'validation_error', 'Invalid recording');
      final file = files.single as Map;
      if (file['field'] != 'audio' || !['audio/mp4', 'audio/webm', 'audio/wav', 'audio/mpeg'].contains(file['mime_type'])) {
        return BackendResponse.error(415, 'unsupported_media', 'Unsupported recording');
      }
      if (file['length'] is! int || (file['length'] as int) <= 0 || (file['length'] as int) > 5 * 1024 * 1024) {
        return BackendResponse.error(413, 'payload_too_large', 'Recording too large');
      }
      final exercises = [
        for (final s in db.sessions.values)
          for (final item in (s['items'] as List).cast<Map>()) ...[
            if (item['type'] == 'practice') ...(item['exercises'] as List).cast<Map>(),
            if (item['type'] == 'exercise') item['exercise'] as Map,
          ],
      ];
      final exercise = exercises.where((e) => e['exercise_id'] == fields['exercise_id']).firstOrNull;
      final payload = exercise?['payload'] as Map?;
      if (exercise != null && exercise['type'] != 'recite_verse') return BackendResponse.error(400, 'validation_error', 'Not a recitation');
      final result = await fixtures.object(
        'contract/recitation/check_${controls.recitationUnclear
            ? 'unclear'
            : controls.recitationOutcome == 'passed'
            ? 'passed'
            : controls.recitationOutcome == 'unclear'
            ? 'unclear'
            : 'errors'}.json',
      );
      // TODO(contract): A-49 — developer checks are fixture projections, never recognition or a demo pass.
      if (payload != null && result['status'] == 'evaluated') {
        final text = (payload['text_uthmani'] as String).split(RegExp(r'\s+'));
        final samples = (result['words'] as List).cast<Map<String, dynamic>>();
        result['words'] = [
          for (var i = 0; i < text.length; i++)
            {
              ...samples[((start ?? 1) - 1 + i) % samples.length],
              'index': i,
              'expected': text[i],
              'heard': samples[((start ?? 1) - 1 + i) % samples.length]['result'] == 'correct' ? text[i] : 'TEST',
            },
        ];
      }
      if (controls.recitationOutcome == 'missing_extra') {
        final words = (result['words'] as List).cast<Map<String, dynamic>>();
        words.first.addAll({'result': 'missing', 'heard': null});
        words.add({'index': words.length, 'expected': null, 'heard': 'TEST', 'result': 'extra', 'audio_segment': null});
        result['words'] = words;
      }
      final words = (result['words'] as List).cast<Map>();
      result['summary'] = {
        for (final kind in ['correct', 'missing', 'substituted', 'extra']) kind: words.where((w) => w['result'] == kind).length,
      };
      final id = 'rchk_${const Uuid().v4()}';
      result['check_id'] = id;
      db.checks[id] = {
        'user_id': db.user!['user_id'],
        'surah': surah,
        'ayah': ayah,
        'word_start': start,
        'word_end': end,
        'expected_digest': payload == null ? null : sha256.convert(utf8.encode(payload['text_uthmani'] as String)).toString(),
        'result': result,
      };
      return BackendResponse(200, result);
    }),
  );
}
