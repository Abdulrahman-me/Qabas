import 'package:collection/collection.dart';

/// Validates against the exact served payload before consulting private keys.
final class MockGrader {
  const MockGrader();
  void validate(Map<String, dynamic> exercise, Object? answer) {
    if (answer == null) {
      if (exercise['time_limit_ms'] == null) throw const FormatException('Untimed answer required');
      return;
    }
    if (answer is! Map<String, dynamic>) throw const FormatException('Answer object required');
    final p = exercise['payload'] as Map;
    final type = exercise['type'];
    void shape(Set<String> keys) {
      if (!const SetEquality<String>().equals(answer.keys.toSet(), keys)) throw const FormatException('Answer shape');
    }

    void member(Object? value, List values, String key) {
      if (value is! String || !values.cast<Map>().any((v) => v[key] == value)) throw const FormatException('Unknown answer ID');
    }

    void mapping(
      String field,
      String left,
      String right,
      List lefts,
      String leftId,
      List rights,
      String rightId, {
      bool uniqueRight = false,
    }) {
      shape({field});
      final rows = answer[field];
      if (rows is! List || rows.length != lefts.length) throw const FormatException('Incomplete mapping');
      final seen = <Object?>{}, taken = <Object?>{};
      for (final r in rows) {
        if (r is! Map || !const SetEquality().equals(r.keys.toSet(), {left, right})) throw const FormatException('Mapping shape');
        member(r[left], lefts, leftId);
        member(r[right], rights, rightId);
        if (!seen.add(r[left]) || (uniqueRight && !taken.add(r[right]))) throw const FormatException('Duplicate mapping');
      }
    }

    switch (type) {
      case 'multiple_choice':
      case 'scenario':
      case 'which_evidence':
      case 'verse_meaning':
        shape({'option_id'});
        member(answer['option_id'], p['options'] as List, 'option_id');
      case 'true_false_reason':
        shape({'value', 'reason_option_id'});
        if (answer['value'] is! bool) throw const FormatException('Boolean required');
        member(answer['reason_option_id'], p['reasons'] as List, 'option_id');
      case 'spot_error':
        shape({'segment_id'});
        member(answer['segment_id'], p['segments'] as List, 'segment_id');
      case 'map_place':
        if (answer['unavailable'] == true) {
          shape({'unavailable'});
        } else {
          shape({'pin_id'});
          member(answer['pin_id'], p['pins'] as List, 'pin_id');
        }
      case 'recite_verse':
        if (answer['check_id'] is String) {
          shape({'check_id'});
          break;
        }
        shape({'skipped'});
        if (answer['skipped'] != true || p['skippable'] != true) throw const FormatException('Recitation check required');
      case 'match_pairs':
        mapping('pairs', 'left_id', 'right_id', p['left'] as List, 'item_id', p['right'] as List, 'item_id', uniqueRight: true);
      case 'categorize':
        mapping('assignments', 'item_id', 'category_id', p['items'] as List, 'item_id', p['categories'] as List, 'category_id');
        for (final c in (p['categories'] as List).cast<Map>()) {
          final cap = c['capacity'];
          if (cap is int && (answer['assignments'] as List).cast<Map>().where((r) => r['category_id'] == c['category_id']).length > cap) {
            throw const FormatException('Category capacity');
          }
        }
      case 'flashcard':
        shape({'rating'});
        if (!['again', 'hard', 'good', 'easy'].contains(answer['rating'])) throw const FormatException('Unknown rating');
      case 'fill_blank':
        mapping(
          'fills',
          'blank_id',
          'word_id',
          (p['segments'] as List).cast<Map>().where((s) => s['type'] == 'blank').toList(),
          'blank_id',
          p['word_bank'] as List,
          'word_id',
          uniqueRight: true,
        );
      case 'timeline_order':
      case 'order_steps':
        shape({'order'});
        final order = answer['order'];
        final ids = (p[type == 'timeline_order' ? 'events' : 'steps'] as List)
            .cast<Map>()
            .map((s) => s[type == 'timeline_order' ? 'event_id' : 'step_id'])
            .toSet();
        if (order is! List || order.length != ids.length || !const SetEquality().equals(order.toSet(), ids)) {
          throw const FormatException('Order must be a permutation');
        }
      default:
        throw const FormatException('Unsupported exercise');
    }
  }

  Map<String, dynamic> grade(Map<String, dynamic> exercise, Object? answer, Map<String, dynamic> key) {
    final type = exercise['type'];
    final p = exercise['payload'] as Map;
    final expected = key['answer_key'] ?? key['correct_answer'];
    final a = answer as Map?;
    bool? correct;
    Map<String, dynamic>? details;
    final neutral = a?['skipped'] == true || a?['unavailable'] == true || type == 'recite_verse';
    if (neutral) {
      correct = null;
    } else if (a == null) {
      correct = false;
    } else {
      bool equals(Object? x, Object? y) => const DeepCollectionEquality().equals(x, y);
      correct = equals(a, expected);
      if (type == 'flashcard') {
        correct = a['rating'] != 'again';
      } else if (type == 'fill_blank') {
        final given = (a['fills'] as List).cast<Map>();
        final rows = [
          for (final r in ((expected as Map)['fills'] as List).cast<Map>())
            {'blank_id': r['blank_id'], 'correct': given.any((g) => g['blank_id'] == r['blank_id'] && g['word_id'] == r['word_id'])},
        ];
        correct = rows.every((r) => r['correct'] == true);
        details = {'blank_results': rows};
      } else if (type == 'timeline_order') {
        details = Map<String, dynamic>.from(key['details'] as Map? ?? {'event_dates': <Object>[]});
      } else if (type == 'categorize' || type == 'match_pairs') {
        final field = type == 'categorize' ? 'assignments' : 'pairs',
            id = type == 'categorize' ? 'item_id' : 'left_id',
            value = type == 'categorize' ? 'category_id' : 'right_id';
        final expectedRows = ((expected as Map)[field] as List).cast<Map>();
        final given = (a[field] as List).cast<Map>();
        final rows = [
          for (final r in expectedRows) {id: r[id], 'correct': given.any((g) => g[id] == r[id] && g[value] == r[value])},
        ];
        correct = rows.every((r) => r['correct'] == true);
        details = {type == 'categorize' ? 'item_results' : 'pair_results': rows};
      } else if (type == 'true_false_reason') {
        details = {
          'value_correct': a['value'] == (expected as Map)['value'],
          'reason_correct': a['reason_option_id'] == expected['reason_option_id'],
        };
      } else if (type == 'order_steps') {
        final order = a['order'] as List, target = (expected as Map)['order'] as List;
        int? wrong;
        for (var i = 0; i < order.length; i++) {
          if (order[i] != target[i]) {
            wrong = i;
            break;
          }
        }
        details = {'first_wrong_index': wrong};
      } else if (type == 'scenario') {
        final feedback = key['option_feedback'] as Map?;
        details = {
          'option_feedback': [
            for (final o in (p['options'] as List).cast<Map>()) {'option_id': o['option_id'], 'spans': feedback?[o['option_id']] ?? []},
          ],
        };
      } else if (type == 'map_place') {
        details = {
          'pin_labels': [
            for (final pin in (p['pins'] as List).cast<Map>())
              {
                'pin_id': pin['pin_id'],
                'label':
                    ((key['details'] as Map?)?['pin_labels'] as List?)
                        ?.cast<Map>()
                        .where((p) => p['pin_id'] == pin['pin_id'])
                        .firstOrNull?['label'] ??
                    pin['label'] ??
                    '',
              },
          ],
        };
      }
    }
    Map<String, dynamic>? misconception;
    if (correct == false && key['misconception_card'] is List) {
      final framing = exercise['framing'] as Map?;
      if (framing != null) {
        final statement = framing['statement'] as List;
        misconception = {
          'misconception_id': exercise['exercise_id'],
          'title': statement.cast<Map>().map((s) => s['text'] ?? '').join(),
          'card': key['misconception_card'],
          'source_ids': <String>[],
        };
      }
    }
    // Unit 0/1.1 provide only private misconception IDs, not learner cards. A-38.
    return {
      'exercise_id': exercise['exercise_id'],
      'recorded': true,
      'correct': correct,
      'correct_answer': neutral || type == 'flashcard' ? null : expected,
      'details': details,
      'explanation': key['explanation'] ?? [],
      'source_ids': key['source_ids'] ?? <String>[],
      'misconception': misconception,
      'mastery_changes': <Object>[],
      'term_changes': <Object>[],
      'xp_awarded': 0,
    };
  }
}
