import 'dart:async';
import 'package:logging/logging.dart';
import 'package:qabas/core/characters/character_spec.dart';
import 'package:rive/rive.dart' as rive;

final class CharacterAssetCache {
  CharacterAssetCache({this._loader, this.loadTimeout = const Duration(seconds: 20)});
  final Duration loadTimeout;
  final Future<rive.File?> Function(RiveRigSpec)? _loader;
  final Map<String, Future<rive.File?>> _files = {};
  Future<bool>? _initialization;
  final _timedOut = <String>{};
  final _pending = <String, ({Completer<rive.File?> completion, Timer timer})>{};
  final _loadedFiles = <rive.File>[];
  bool _disposed = false;
  Future<rive.File?> load(RiveRigSpec spec) {
    if (_disposed) return Future.value();
    return _files.putIfAbsent(spec.assetPath, () {
      final completion = Completer<rive.File?>();
      final timer = Timer(loadTimeout, () {
        _timedOut.add(spec.assetPath);
        Logger('characters').warning('Character loading timed out: ${spec.assetPath}');
        if (!completion.isCompleted) completion.complete(null);
        _pending.remove(spec.assetPath);
      });
      _pending[spec.assetPath] = (completion: completion, timer: timer);
      unawaited(
        _load(spec).then((file) {
          timer.cancel();
          _pending.remove(spec.assetPath);
          if (!completion.isCompleted) completion.complete(file);
        }),
      );
      return completion.future;
    });
  }

  Future<rive.File?> _load(RiveRigSpec spec) async {
    try {
      rive.File? file;
      if (_loader != null) {
        file = await _loader(spec);
      } else {
        if (!await (_initialization ??= rive.RiveNative.init())) return null;
        file = await rive.File.asset(spec.assetPath, riveFactory: rive.Factory.rive);
      }
      if (_disposed || _timedOut.contains(spec.assetPath)) {
        file?.dispose();
        return null;
      }
      if (file != null) _loadedFiles.add(file);
      return file;
    } catch (_) {
      Logger('characters').warning('Character asset failed: ${spec.assetPath}');
      return null;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final pending in _pending.values) {
      pending.timer.cancel();
      if (!pending.completion.isCompleted) pending.completion.complete(null);
    }
    _pending.clear();
    for (final file in _loadedFiles) {
      file.dispose();
    }
    _loadedFiles.clear();
    _files.clear();
  }
}
