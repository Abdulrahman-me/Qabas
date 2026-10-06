import 'package:flutter/widgets.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';

enum CharacterFallbackKind { flame, lantern, none }

sealed class RigSpec {
  const RigSpec();
}

final class RiveRigSpec extends RigSpec {
  const RiveRigSpec({
    required this.assetPath,
    this.artboard,
    this.stateMachine,
    this.viewModelInstance,
    this.moodProperty = 'mood',
    this.moodValues = const {},
    this.cueTriggers = const {},
    this.reducedMotionProperty,
  });
  final String assetPath, moodProperty;
  final String? artboard, stateMachine, viewModelInstance, reducedMotionProperty;
  final Map<CharacterMood, String> moodValues;
  final Map<CharacterCue, String> cueTriggers;
}

final class PainterRigSpec extends RigSpec {
  const PainterRigSpec();
}

final class CharacterLayout {
  const CharacterLayout({this.aspect = 1, this.zoom = 1, this.alignment = Alignment.bottomCenter, this.tint});
  final double aspect, zoom;
  final Alignment alignment;
  final Color? tint;
}

final class CharacterSpec {
  const CharacterSpec({
    required this.id,
    required this.rig,
    required this.supportedMoods,
    required this.supportedCues,
    required this.semanticsLabel,
    this.moodFallbacks = const {},
    this.cueFallbacks = const {},
    this.layout = const CharacterLayout(),
    this.fallback = CharacterFallbackKind.flame,
  });
  final String id;
  final RigSpec rig;
  final Set<CharacterMood> supportedMoods;
  final Set<CharacterCue> supportedCues;
  final Map<CharacterMood, CharacterMood> moodFallbacks;
  final Map<CharacterCue, CharacterCue> cueFallbacks;
  final CharacterLayout layout;
  final CharacterFallbackKind fallback;
  final String Function(AppLocalizations) semanticsLabel;
  CharacterMood resolveMood(CharacterMood mood) => supportedMoods.contains(mood) ? mood : moodFallbacks[mood] ?? CharacterMood.idle;
  CharacterCue? resolveCue(CharacterCue cue) => supportedCues.contains(cue) ? cue : cueFallbacks[cue];
}
