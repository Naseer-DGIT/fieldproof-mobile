import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/secure_logger.dart';

/// FieldProof KeyStore.
///
/// Owns every secret that must never leave the device in plaintext:
///   - the SQLCipher database key (random 256-bit, generated once)
///   - the session token (written by the auth flow in S2)
///   - the device private key (written in S2 after attestation)
///
/// Storage backend:
///   - Android: EncryptedSharedPreferences backed by Keystore
///   - iOS:     Keychain with first_unlock_this_device accessibility
///
/// The DB key is *random*, not derived. See ADR-0002 for the tradeoffs.
class KeyStore {
  KeyStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _dbKeyAlias = 'fp_db_key_v1';
  static const _sessionTokenAlias = 'fp_session_token_v1';
  static const _deviceKeyAlias = 'fp_device_private_key_v1';

  /// Returns the SQLCipher key, generating it on first call.
  /// The key never leaves secure storage in plaintext form.
  static Future<String> getOrCreateDbKey() async {
    final existing = await _storage.read(key: _dbKeyAlias);
    if (existing != null) return existing;

    final generated = _generateRandomKey(32);
    await _storage.write(key: _dbKeyAlias, value: generated);
    SecureLogger.i('keystore.db_key.generated');
    return generated;
  }

  static Future<void> saveSessionToken(String token) async {
    await _storage.write(key: _sessionTokenAlias, value: token);
  }

  static Future<String?> getSessionToken() =>
      _storage.read(key: _sessionTokenAlias);

  static Future<void> clearSession() async {
    await _storage.delete(key: _sessionTokenAlias);
  }

  static Future<void> saveDevicePrivateKey(String key) async {
    await _storage.write(key: _deviceKeyAlias, value: key);
  }

  static Future<String?> getDevicePrivateKey() =>
      _storage.read(key: _deviceKeyAlias);

  static Future<void> wipe() async {
    await _storage.deleteAll();
    SecureLogger.w('keystore.wiped');
  }

  static String _generateRandomKey(int bytes) {
    final rnd = Random.secure();
    final values = List<int>.generate(bytes, (_) => rnd.nextInt(256));
    return base64Url.encode(values);
  }
}
