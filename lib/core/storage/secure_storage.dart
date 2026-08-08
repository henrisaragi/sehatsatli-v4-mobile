import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'access_token';
  static const _userKey = 'current_user';

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  /// Persists the raw login-response user object (as JSON) so RBAC flags
  /// (`is_doctor`, `heads_upt`, etc. — see FFAppState._userField) survive an
  /// app restart. Only `access_token` was ever persisted before, so a
  /// restored session used to lose these flags until the next fresh login.
  Future<void> saveUserJson(String json) => _storage.write(key: _userKey, value: json);

  Future<String?> readUserJson() => _storage.read(key: _userKey);

  Future<void> deleteUserJson() => _storage.delete(key: _userKey);
}
