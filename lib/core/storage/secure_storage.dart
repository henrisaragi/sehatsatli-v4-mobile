import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'access_token';
  static const _userKey = 'current_user';

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _read(_tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  /// Persists the raw login-response user object (as JSON) so RBAC flags
  /// (`is_doctor`, `heads_upt`, etc. — see FFAppState._userField) survive an
  /// app restart. Only `access_token` was ever persisted before, so a
  /// restored session used to lose these flags until the next fresh login.
  Future<void> saveUserJson(String json) => _storage.write(key: _userKey, value: json);

  Future<String?> readUserJson() => _read(_userKey);

  Future<void> deleteUserJson() => _storage.delete(key: _userKey);

  /// A value that can't be decrypted (e.g. Android Auto Backup restored the
  /// storage file onto a device whose Keystore key is gone) is unrecoverable:
  /// wipe the storage and treat it as "no session" instead of throwing, which
  /// used to leave the splash screen spinning forever.
  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException {
      try {
        await _storage.deleteAll();
      } on PlatformException {
        // Nothing more to do; the next write recreates the storage.
      }
      return null;
    }
  }
}
