import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

class SensorySettings {
  const SensorySettings({this.sound = true, this.haptics = true});
  final bool sound;
  final bool haptics;
}

/// Injected counterpart of the prototype's Sensory singleton.
class SensoryService {
  SensoryService({required this.settings});
  final SensorySettings Function() settings;
  final Map<String, AudioPlayer> _players = {};
  final _log = Logger('sensory');
  bool _disposed = false;

  Future<void> warmUp() async {
    for (final name in const ['tap', 'select', 'correct', 'retry', 'complete', 'streak', 'sparkle']) {
      if (_disposed) return;
      final player = AudioPlayer();
      try {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setSource(AssetSource('sounds/$name.wav'));
        if (_disposed) {
          await player.dispose();
          return;
        }
        _players[name] = player;
      } catch (_) {
        _log.fine('Sound effect unavailable: $name');
        await _quietly(player.dispose);
      }
    }
  }

  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      _log.fine('Optional sensory feedback unavailable');
    }
  }

  Future<void> _play(String name, double volume) async {
    if (_disposed || !settings().sound) return;
    final player = _players[name];
    if (player == null) return;
    await _quietly(() async {
      await player.stop();
      await player.setVolume(volume);
      await player.resume();
    });
  }

  void _feedback(String name, double volume, Future<void> Function() haptic) {
    if (_disposed) return;
    if (settings().haptics) unawaited(_quietly(haptic));
    unawaited(_play(name, volume));
  }

  void tap() => _feedback('tap', 0.5, HapticFeedback.selectionClick);
  void select() => _feedback('select', 0.6, HapticFeedback.selectionClick);
  void correct() => _feedback('correct', 0.75, HapticFeedback.mediumImpact);
  void retry() => _feedback('retry', 0.6, HapticFeedback.lightImpact);
  void complete() => _feedback('complete', 0.8, HapticFeedback.heavyImpact);
  void streak() => _feedback('streak', 0.8, HapticFeedback.heavyImpact);
  void sparkle() => _feedback('sparkle', 0.6, HapticFeedback.lightImpact);

  Future<void> dispose() async {
    _disposed = true;
    for (final player in _players.values) {
      await _quietly(player.dispose);
    }
    _players.clear();
  }
}

class SensoryScope extends InheritedWidget {
  const SensoryScope({super.key, required this.service, required super.child});
  final SensoryService service;
  static SensoryService of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SensoryScope>()!.service;

  @override
  bool updateShouldNotify(SensoryScope oldWidget) => service != oldWidget.service;
}
