/// Validated SVG M/L/H/V/C/Q/Z commands, normalized to absolute coordinates.
/// No permissive general SVG parser: unsupported syntax rejects the scene.
final class ScenePath {
  ScenePath._(List<PathCommand> commands) : commands = List.unmodifiable(commands);
  final List<PathCommand> commands;
  static final _token = RegExp(r'[MLHVCQZmlhvcqz]|[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?');
  static const _arity = {'M': 2, 'L': 2, 'H': 1, 'V': 1, 'C': 6, 'Q': 4, 'Z': 0};

  factory ScenePath.parse(String source) {
    if (source.length > 20000 || RegExp(r',\s*,|[A-Za-z]\s*,|,\s*[A-Za-z]').hasMatch(source)) {
      throw const FormatException('Invalid path');
    }
    final tokens = <String>[];
    var end = 0;
    for (final match in _token.allMatches(source)) {
      if (source.substring(end, match.start).replaceAll(RegExp(r'[\s,]'), '').isNotEmpty) {
        throw const FormatException('Unsupported path syntax');
      }
      tokens.add(match.group(0)!);
      end = match.end;
    }
    if (source.substring(end).trim().isNotEmpty || tokens.isEmpty || tokens.first.toUpperCase() != 'M') {
      throw const FormatException('Path must start with moveto');
    }
    final commands = <PathCommand>[];
    var index = 0, x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
    while (index < tokens.length) {
      final command = tokens[index++], upper = command.toUpperCase(), arity = _arity[command.toUpperCase()];
      if (arity == null) throw const FormatException('Expected path command');
      final relative = command != upper;
      if (arity == 0) {
        commands.add(PathCommand('Z', const []));
        x = startX;
        y = startY;
        continue;
      }
      var first = true;
      while (index < tokens.length && !_arity.containsKey(tokens[index].toUpperCase())) {
        if (index + arity > tokens.length) throw const FormatException('Incomplete path command');
        final args = <double>[];
        for (var i = 0; i < arity; i++) {
          final value = double.tryParse(tokens[index++]);
          if (value == null || !value.isFinite) throw const FormatException('Invalid path coordinate');
          args.add(value);
        }
        var normalized = upper == 'M' && !first ? 'L' : upper;
        if (upper == 'H') {
          args[0] += relative ? x : 0;
          args.add(y);
          normalized = 'L';
        } else if (upper == 'V') {
          final target = args[0] + (relative ? y : 0);
          args[0] = x;
          args.add(target);
          normalized = 'L';
        } else if (relative) {
          for (var i = 0; i < args.length; i += 2) {
            args[i] += x;
            args[i + 1] += y;
          }
        }
        if (args.any((value) => !value.isFinite)) throw const FormatException('Invalid normalized path coordinate');
        x = args[args.length - 2];
        y = args.last;
        if (normalized == 'M') {
          startX = x;
          startY = y;
        }
        commands.add(PathCommand(normalized, args));
        if (commands.length > 400) throw const FormatException('Path command limit');
        first = false;
      }
      if (first) throw const FormatException('Path command needs arguments');
    }
    if (commands.length > 400) throw const FormatException('Path command limit');
    return ScenePath._(commands);
  }
}

final class PathCommand {
  PathCommand(this.kind, List<double> values) : values = List.unmodifiable(values);
  final String kind;
  final List<double> values;
}
