import 'package:qabas/core/characters/character_spec.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/characters/specs/guide_traveler.dart';
import 'package:qabas/core/characters/specs/raqeeb_lantern.dart';

final class CharacterRegistry {
  CharacterRegistry({required Iterable<CharacterSpec> specs, required Map<CharacterRole, String> casting})
    : specs = Map.unmodifiable({for (final spec in specs) spec.id: spec}),
      casting = Map.unmodifiable(casting);
  factory CharacterRegistry.bundled() => CharacterRegistry(
    specs: [guideTraveler, raqeebLantern],
    casting: {CharacterRole.guide: guideTraveler.id, CharacterRole.assistant: raqeebLantern.id},
  );
  final Map<String, CharacterSpec> specs;
  final Map<CharacterRole, String> casting;
  CharacterSpec? resolve(CharacterRole role, {Map<CharacterRole, String> overrides = const {}}) =>
      specs[overrides[role]] ?? specs[casting[role]];
}
