import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/secure_logger.dart';

/// KeyStore owns every secret that must never leave the device in
/// plaintext form.
///
/// Three DB key aliases support crash-safe rekey (see
/// docs/security/s5-mobile-rekey.md):
///
///   fp_db_key_v1        the key in use
///   fp_db_key_next_v1   a key written but not yet promoted
///   fp_db_key_prev_v1   the key just replaced, kept for one open cycle
class KeyStore {
  KeyStore._();

  // Version 10+ of flutter_secure_storage uses RSA OAEP + AES-GCM by
  // default. The old `encryptedSharedPreferences` flag was removed.
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _dbKeyAlias = 'fp_db_key_v1';
  static const _dbKeyNextAlias = 'fp_db_key_next_v1';
  static const _dbKeyPrevAlias = 'fp_db_key_prev_v1';
  static const _sessionTokenAlias = 'fp_session_token_v1';
  static const _deviceKeyAlias = 'fp_device_private_key_v1';
  static const _deviceIdAlias = 'fp_device_id_v1';
  static const _lastRekeyAtAlias = 'fp_db_rekey_at_v1';

  // --- DB key (primary) ---

  static Future<String> getOrCreateDbKey() async {
    final existing = await _storage.read(key: _dbKeyAlias);
    if (existing != null) return existing;
    final generated = _generateRandomKey(32);
    await _storage.write(key: _dbKeyAlias, value: generated);
    SecureLogger.i('keystore.db_key.generated');
    return generated;
  }

  static Future<String?> getDbKey() => _storage.read(key: _dbKeyAlias);
  static Future<String?> getNextDbKey() => _storage.read(key: _dbKeyNextAlias);
  static Future<String?> getPrevDbKey() => _storage.read(key: _dbKeyPrevAlias);

  static Future<void> setDbKey(String key) =>
      _storage.write(key: _dbKeyAlias, value: key);
  static Future<void> setNextDbKey(String key) =>
      _storage.write(key: _dbKeyNextAlias, value: key);
  static Future<void> setPrevDbKey(String key) =>
      _storage.write(key: _dbKeyPrevAlias, value: key);

  static Future<void> clearNextDbKey() => _storage.delete(key: _dbKeyNextAlias);
  static Future<void> clearPrevDbKey() => _storage.delete(key: _dbKeyPrevAlias);

  /// Generate a new 32-byte key. Does not persist it.
  static String generateDbKey() => _generateRandomKey(32);

  /// Timestamp of the last successful rekey. Null if never rekeyed.
  static Future<DateTime?> getLastRekeyAt() async {
    final raw = await _storage.read(key: _lastRekeyAtAlias);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> setLastRekeyAt(DateTime when) =>
      _storage.write(key: _lastRekeyAtAlias, value: when.toUtc().toIso8601String());

  // --- Session token ---

  static Future<void> saveSessionToken(String token) =>
      _storage.write(key: _sessionTokenAlias, value: token);

  static Future<String?> getSessionToken() =>
      _storage.read(key: _sessionTokenAlias);

  static Future<void> clearSession() =>
      _storage.delete(key: _sessionTokenAlias);

  // --- Device key ---

  static Future<void> saveDevicePrivateKey(String key) =>
      _storage.write(key: _deviceKeyAlias, value: key);

  static Future<String?> getDevicePrivateKey() =>
      _storage.read(key: _deviceKeyAlias);

  static Future<void> saveDeviceId(int id) =>
      _storage.write(key: _deviceIdAlias, value: id.toString());

  static Future<int?> getDeviceId() async {
    final raw = await _storage.read(key: _deviceIdAlias);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  static Future<void> clearDevice() async {
    await _storage.delete(key: _deviceKeyAlias);
    await _storage.delete(key: _deviceIdAlias);
  }

  // --- Wipe everything ---

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
