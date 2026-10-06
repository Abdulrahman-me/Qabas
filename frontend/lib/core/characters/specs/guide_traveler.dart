import 'package:qabas/core/characters/character_spec.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';

String _guideLabel(AppLocalizations l10n) => l10n.characterGuideSemantics;
const guideTraveler = CharacterSpec(
  id: 'guide_traveler',
  rig: RiveRigSpec(
    assetPath: 'assets/characters/guide_traveler/guide_traveler.riv',
    artboard: 'Companion',
    stateMachine: 'Companion',
    viewModelInstance: 'Default',
  ),
  supportedMoods: {CharacterMood.idle, CharacterMood.thinking},
  supportedCues: {
    CharacterCue.greet,
    CharacterCue.encourage,
    CharacterCue.correct,
    CharacterCue.retry,
    CharacterCue.celebrate,
    CharacterCue.complete,
    CharacterCue.streak,
  },
  moodFallbacks: {CharacterMood.listening: CharacterMood.idle, CharacterMood.speaking: CharacterMood.idle},
  semanticsLabel: _guideLabel,
);
