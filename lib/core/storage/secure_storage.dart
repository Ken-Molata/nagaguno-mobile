// lib/core/storage/secure_storage.dart
//
// Keychain (iOS) / Keystore (Android) backed storage for the refresh
// token — the mobile equivalent of the web app's httpOnly cookie. The
// access token is kept in memory only (not persisted), matching the
// real backend's actual token lifetimes: 15-minute access tokens,
// longer-lived rotating refresh tokens (see AuthController on the real
// backend — refresh revokes the used token and issues a new pair on
// every call, verified this session).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _refreshTokenKey = 'nagaguno_refresh_token';

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> clearRefreshToken() => _storage.delete(key: _refreshTokenKey);

  Future<void> clearAll() => _storage.deleteAll();
}
