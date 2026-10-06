import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

final class SecureTokenStore implements TokenStore {
  const SecureTokenStore(this._storage, {this.key = accessKey});
  final FlutterSecureStorage _storage;
  final String key;
  static const accessKey = 'qabas_access_token';

  /// Holds the learner's credential while a reviewer is signed in on this device.
  static const suspendedLearnerKey = 'qabas_suspended_learner_token';
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String token) => _storage.write(key: key, value: token);
  @override
  Future<void> clear() => _storage.delete(key: key);
}
