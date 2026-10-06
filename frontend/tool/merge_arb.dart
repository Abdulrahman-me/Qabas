import 'dart:convert';
import 'dart:io';

/// Validates before writing, so a failed merge never damages generated files.
Map<String, Map<String, Object?>> mergeArb(Directory source) {
  final locales = <String, Map<String, Object?>>{'en': {}, 'ar': {}};
  final files = source.listSync().whereType<File>().where((f) => f.path.endsWith('.arb')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final arb = Map<String, Object?>.from(jsonDecode(file.readAsStringSync()) as Map);
    final match = RegExp(r'_(en|ar)\.arb$').firstMatch(file.path);
    if (match == null) throw FormatException('Fragment must end in _en.arb or _ar.arb: ${file.path}');
    final locale = match[1]!;
    if (arb['@@locale'] != locale) throw FormatException('Wrong @@locale in ${file.path}');
    for (final entry in arb.entries.where((e) => !e.key.startsWith('@@'))) {
      if (locales[locale]!.containsKey(entry.key)) throw FormatException('Duplicate ${entry.key} in ${file.path}');
      locales[locale]![entry.key] = entry.value;
    }
  }
  Set<String> keys(String locale) => locales[locale]!.keys.where((k) => !k.startsWith('@')).toSet();
  final en = keys('en'), ar = keys('ar');
  if (en.isEmpty || en.difference(ar).isNotEmpty || ar.difference(en).isNotEmpty) {
    throw FormatException('Key parity: missing Arabic ${en.difference(ar)}, missing English ${ar.difference(en)}');
  }
  for (final locale in locales.keys) {
    for (final metaKey in locales[locale]!.keys.where((key) => key.startsWith('@'))) {
      if (!keys(locale).contains(metaKey.substring(1))) throw FormatException('Orphan metadata: $locale/$metaKey');
    }
  }
  for (final key in en) {
    final placeholders = <String, Map<String, String>>{};
    for (final locale in locales.keys) {
      final message = locales[locale]![key];
      if (message is! String) throw FormatException('Message must be a string: $locale/$key');
      final metadata = locales[locale]!['@$key'];
      if (metadata is! Map || metadata['description'] is! String || (metadata['description'] as String).isEmpty) {
        throw FormatException('Missing translator description: $locale/$key');
      }
      final declared = metadata['placeholders'] as Map? ?? {};
      final used = RegExp(r'\{(\w+)\s*[,}]').allMatches(message).map((m) => m[1]!).toSet();
      if (used.difference(declared.keys.toSet()).isNotEmpty || declared.keys.toSet().difference(used).isNotEmpty) {
        throw FormatException('Undeclared or unused placeholders: $locale/$key');
      }
      placeholders[locale] = {for (final name in declared.keys) name as String: (declared[name] as Map)['type'] as String? ?? 'String'};
    }
    final enParams = placeholders['en']!, arParams = placeholders['ar']!;
    if (enParams.length != arParams.length || enParams.entries.any((e) => arParams[e.key] != e.value)) {
      throw FormatException('Placeholder parity: $key');
    }
  }
  return {
    for (final locale in locales.keys)
      locale: {'@@locale': locale, for (final key in locales[locale]!.keys.toList()..sort()) key: locales[locale]![key]},
  };
}

void main(List<String> args) {
  try {
    final result = mergeArb(Directory(args.isEmpty ? 'lib/l10n/fragments' : args[0]));
    final output = Directory(args.length < 2 ? 'lib/l10n/arb' : args[1])..createSync(recursive: true);
    for (final entry in result.entries) {
      File('${output.path}/app_${entry.key}.arb').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(entry.value)}\n');
    }
    stdout.writeln('Merged ${(result['en']!.length - 1) ~/ 2} keys; English/Arabic key and placeholder parity passed.');
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}
