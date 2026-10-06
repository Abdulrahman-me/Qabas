import 'dart:convert';
import 'dart:io';

/// One-off, reproducible extraction. Never writes to the prototype.
void main(List<String> args) {
  final source = Directory(args.isEmpty ? '/Users/aw/Documents/qpr/qabas/lib/l10n' : args.first);
  final fragments = Directory('lib/l10n/fragments')..createSync(recursive: true);
  final patterns = jsonDecode(File('tool/prototype_string_patterns.json').readAsStringSync()) as Map<String, dynamic>;
  final entries = <String, Map<String, Object?>>{};
  final index = <String, Object>{};
  void add(String feature, String name, String en, String ar, {Map<String, dynamic>? placeholders}) {
    final key = '$feature${name[0].toUpperCase()}${name.substring(1)}';
    for (final locale in ['en', 'ar']) {
      final fragment = entries.putIfAbsent('${feature}_$locale', () => {'@@locale': locale});
      if (fragment.containsKey(key)) throw StateError('Duplicate extracted key: $key');
      fragment[key] = locale == 'en' ? en : ar;
      fragment['@$key'] = {
        'description': 'Prototype interface copy: $feature / $name. Preserve the original warm wording.',
        'placeholders': ?placeholders,
      };
    }
    index['$feature.$name'] = key;
  }

  final getter = RegExp(r'''String get (\w+)\s*=>\s*t\(\s*'((?:\\.|[^'\\])*)'\s*,\s*'((?:\\.|[^'\\])*)'\s*,?\s*\)''', dotAll: true);
  final lists = RegExp(r'''List<String> get (\w+)\s*=>\s*isAr\s*\?\s*\[(.*?)\]\s*:\s*\[(.*?)\]''', dotAll: true);
  final literal = RegExp(r''' '((?:\\.|[^'\\])*)' '''.trim());
  String decode(String text) => text.replaceAll(r"\'", "'").replaceAll(r'\n', '\n').replaceAll(r'\\', r'\');
  for (final filename in ['s.dart', 'strings_app.dart', 'strings_learn.dart', 'strings_onboarding.dart']) {
    final text = File('${source.path}/$filename').readAsStringSync();
    String featureAt(int position) {
      if (filename == 'strings_onboarding.dart') return 'onboarding';
      final comments = RegExp(
        r'//[ -]*(brand|common|shell|review|raqeeb|community|live|profile|settings|about|journey|lesson intro|lesson chrome|exercise kinds|recite|feedback|complete|streak celebration|terms|evidence)\s*$',
        multiLine: true,
      ).allMatches(text.substring(0, position));
      final section = comments.isEmpty ? 'common' : comments.last[1]!;
      return switch (section) {
        'brand' || 'common' || 'shell' => 'common',
        'live' => 'challenge',
        'lesson intro' || 'lesson chrome' || 'exercise kinds' || 'recite' || 'feedback' || 'complete' => 'session',
        'streak celebration' => 'streak',
        'terms' => 'glossary',
        'evidence' => 'content',
        _ => section,
      };
    }

    for (final match in getter.allMatches(text)) {
      var name = match[1]!;
      if (name == 'continueLabel') name = 'continue';
      if (name == 'new_') name = 'new';
      add(featureAt(match.start), name, decode(match[2]!), decode(match[3]!));
    }
    for (final match in lists.allMatches(text)) {
      final ar = literal.allMatches(match[2]!).map((m) => decode(m[1]!)).toList();
      final en = literal.allMatches(match[3]!).map((m) => decode(m[1]!)).toList();
      if (en.length != ar.length) throw StateError('List parity: ${match[1]}');
      for (var i = 0; i < en.length; i++) {
        add(featureAt(match.start), '${match[1]}${i + 1}', en[i], ar[i]);
      }
    }
    // Parameterized methods are explicitly transcribed, preserving the prototype's branches.
    for (final match in RegExp(r'String (\w+)\([^;{}]*?\)\s*=>', dotAll: true).allMatches(text)) {
      final name = match[1]!;
      if (['t', 'bi', 'tr', 'of'].contains(name)) continue;
      final pattern = patterns[name] as Map<String, dynamic>?;
      if (pattern == null) throw StateError('Missing parameterized pattern: $name');
      add(
        featureAt(match.start),
        name,
        pattern['en'] as String,
        pattern['ar'] as String,
        placeholders: pattern['placeholders'] as Map<String, dynamic>,
      );
    }
  }
  for (final fragment in entries.entries) {
    final sorted = {for (final key in fragment.value.keys.toList()..sort()) key: fragment.value[key]};
    File('${fragments.path}/${fragment.key}.arb').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
  }
  File('docs/prototype/STRING_KEYS.json').writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(index)}\n');
  stdout.writeln('Extracted ${index.length} prototype interface entries into ${entries.length} bilingual fragments.');
}
