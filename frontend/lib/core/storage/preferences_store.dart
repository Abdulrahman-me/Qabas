import 'package:shared_preferences/shared_preferences.dart';

final class PreferencesStore {
  PreferencesStore(this._preferences);
  final SharedPreferences _preferences;
  static Future<PreferencesStore> open() async => PreferencesStore(await SharedPreferences.getInstance());
  bool boolean(String key, {bool fallback = false}) => _preferences.getBool('qabas_$key') ?? fallback;
  String? string(String key) => _preferences.getString('qabas_$key');
  Future<void> setBoolean(String key, bool value) async {
    if (!await _preferences.setBool('qabas_$key', value)) throw StateError('Preference write failed');
  }

  Future<void> setString(String key, String value) async {
    if (!await _preferences.setString('qabas_$key', value)) throw StateError('Preference write failed');
  }

  /// Reset learner choices without resetting the dev/demo server session.
  Future<void> clearLocal() => clear(preserve: const {'mock_server'});

  Future<void> clear({Set<String> preserve = const {}}) async {
    for (final key in _preferences.getKeys().where((key) => key.startsWith('qabas_') && !preserve.contains(key.substring(6))).toList()) {
      await _preferences.remove(key);
    }
  }
}
