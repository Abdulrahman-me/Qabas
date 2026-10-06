import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/characters/character_vocabulary.dart';
import 'package:qabas/core/storage/preferences_store.dart';

enum CharacterSettingsStatus { ready, failure }

final class CharacterSettingsState extends Equatable {
  CharacterSettingsState({
    this.enabled = true,
    Map<CharacterRole, String> overrides = const {},
    this.status = CharacterSettingsStatus.ready,
  }) : overrides = Map.unmodifiable(overrides);
  final bool enabled;
  final Map<CharacterRole, String> overrides;
  final CharacterSettingsStatus status;
  @override
  List<Object?> get props => [enabled, overrides, status];
}

final class CharacterSettingsCubit extends Cubit<CharacterSettingsState> {
  CharacterSettingsCubit(this._store)
    : super(CharacterSettingsState(enabled: _store.boolean('companion_enabled', fallback: true), overrides: _load(_store)));
  final PreferencesStore _store;
  Future<void> _writes = Future.value();
  int _revision = 0;
  static Map<CharacterRole, String> _load(PreferencesStore store) {
    try {
      final json = jsonDecode(store.string('character_casting') ?? '{}') as Map<String, dynamic>;
      return {
        for (final role in CharacterRole.values)
          if (json[role.name] is String) role: json[role.name] as String,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> settingsChanged({bool? enabled, Map<CharacterRole, String>? overrides}) async {
    final next = CharacterSettingsState(enabled: enabled ?? state.enabled, overrides: overrides ?? state.overrides);
    final revision = ++_revision;
    emit(next);
    return _writes = _writes.then((_) async {
      try {
        await _store.setBoolean('companion_enabled', next.enabled);
        await _store.setString('character_casting', jsonEncode({for (final entry in next.overrides.entries) entry.key.name: entry.value}));
      } catch (_) {
        if (!isClosed && revision == _revision) {
          emit(CharacterSettingsState(enabled: next.enabled, overrides: next.overrides, status: CharacterSettingsStatus.failure));
        }
      }
    });
  }
}
