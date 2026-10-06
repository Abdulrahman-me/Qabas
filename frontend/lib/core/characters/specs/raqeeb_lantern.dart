import 'package:qabas/core/characters/character_spec.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/l10n/gen/app_localizations.dart';

String _lanternLabel(AppLocalizations l10n) => l10n.characterLanternSemantics;
const raqeebLantern = CharacterSpec(
  id: 'raqeeb_lantern',
  rig: PainterRigSpec(),
  supportedMoods: {CharacterMood.idle, CharacterMood.thinking, CharacterMood.listening, CharacterMood.speaking},
  supportedCues: {},
  fallback: CharacterFallbackKind.lantern,
  semanticsLabel: _lanternLabel,
);
