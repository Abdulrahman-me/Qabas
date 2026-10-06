import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/merge_arb.dart';

void main() {
  late Directory directory;
  setUp(() => directory = Directory.systemTemp.createTempSync('qabas-arb-'));
  tearDown(() => directory.deleteSync(recursive: true));
  void write(String name, String locale, Map<String, Object?> contents) =>
      File('${directory.path}/${name}_$locale.arb').writeAsStringSync(jsonEncode({'@@locale': locale, ...contents}));
  Map<String, Object?> entry(String value, {String type = 'String'}) => {
    'commonValue': value,
    '@commonValue': {
      'description': 'Test placeholder',
      'placeholders': {
        'value': {'type': type},
      },
    },
  };
  test('merges and sorts bilingual fragments with identical placeholder types', () {
    write('common', 'en', entry('Value {value}'));
    write('common', 'ar', entry('قيمة {value}'));
    final result = mergeArb(directory);
    expect(result['ar']!['commonValue'], 'قيمة {value}');
    expect(result['en']!['@@locale'], 'en');
  });
  test('rejects duplicates', () {
    write('common', 'en', entry('{value}'));
    write('common', 'ar', entry('{value}'));
    write('other', 'en', entry('{value}'));
    expect(() => mergeArb(directory), throwsFormatException);
  });
  test('rejects a missing translation', () {
    write('common', 'en', entry('{value}'));
    write('common', 'ar', {});
    expect(() => mergeArb(directory), throwsFormatException);
  });
  test('rejects mismatched placeholder types', () {
    write('common', 'en', entry('{value}'));
    write('common', 'ar', entry('{value}', type: 'num'));
    expect(() => mergeArb(directory), throwsFormatException);
  });
  test('rejects undeclared placeholders and orphan metadata', () {
    write('common', 'en', entry('{value} {missing}'));
    write('common', 'ar', entry('{value}'));
    expect(() => mergeArb(directory), throwsFormatException);
    write('common', 'en', {
      ...entry('{value}'),
      '@orphan': {'description': 'Orphan'},
    });
    expect(() => mergeArb(directory), throwsFormatException);
  });
  test('validates all checked-in fragments', () {
    final result = mergeArb(Directory('lib/l10n/fragments'));
    expect(result['en']!.length, greaterThan(700));
  });
}
