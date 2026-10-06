import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabas/core/storage/preferences_store.dart';
import 'package:qabas/core/storage/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Token read/write/clear use secure storage and preserve other secure values', () async {
    FlutterSecureStorage.setMockInitialValues({'unrelated': 'kept'});
    SharedPreferences.setMockInitialValues({});
    const store = SecureTokenStore(FlutterSecureStorage());
    expect(await store.read(), isNull);
    await store.write('test-access-token');
    expect(await store.read(), 'test-access-token');
    final preferences = await PreferencesStore.open();
    expect(preferences.string('access_token'), isNull);
    await store.clear();
    expect(await store.read(), isNull);
    expect(await const FlutterSecureStorage().read(key: 'unrelated'), 'kept');
  });
}
