import 'package:flutter/widgets.dart';
import 'package:qabas/core/characters/character_asset_cache.dart';
import 'package:qabas/core/characters/character_registry.dart';
import 'package:qabas/core/characters/character_settings_cubit.dart';

final class CharacterScope extends InheritedWidget {
  const CharacterScope({super.key, required super.child, required this.cache, required this.registry, required this.settings});
  final CharacterAssetCache cache;
  final CharacterRegistry registry;
  final CharacterSettingsState settings;
  static CharacterScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<CharacterScope>();
  @override
  bool updateShouldNotify(CharacterScope old) => cache != old.cache || registry != old.registry || settings != old.settings;
}
