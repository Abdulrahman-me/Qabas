import 'package:flutter/widgets.dart';
import 'package:qabas/core/characters/character_spec.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/characters/rig/character_rig.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/shared/presentation/brand/lantern.dart';

final class PainterCharacterRig implements CharacterRig {
  final ValueNotifier<CharacterMood> _mood = ValueNotifier(CharacterMood.idle);
  bool _paused = false, _disposed = false;
  @override
  Future<bool> attach() async => true;
  @override
  void setMood(CharacterMood mood) {
    if (_disposed) return;
    _mood.value = _paused ? CharacterMood.idle : mood;
  }

  @override
  void fire(CharacterCue cue) {}
  @override
  void setPaused(bool paused) {
    if (_disposed) return;
    _paused = paused;
    if (paused) _mood.value = CharacterMood.idle;
  }

  @override
  Widget build(BuildContext context, CharacterLayout layout) => ValueListenableBuilder(
    valueListenable: _mood,
    builder: (context, mood, _) => LayoutBuilder(
      builder: (context, constraints) {
        final glyph = LanternGlyph(
          color: mood == CharacterMood.speaking ? QColors.flameGold : layout.tint ?? QColors.emerald500,
          lit: true,
          size: constraints.biggest.shortestSide,
        );
        return mood == CharacterMood.thinking && !_paused ? Breathe(child: glyph) : glyph;
      },
    ),
  );
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _mood.dispose();
  }
}
