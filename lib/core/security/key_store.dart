import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/secure_logger.dart';

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
  static const _deviceIdAlias = 'fp_device_id_v1';

  static Future<String> getOrCreateDbKey() async {
    final existing = await _storage.read(key: _dbKeyAlias);
    if (existing != null) return existing;
    final generated = _generateRandomKey(32);
    await _storage.write(key: _dbKeyAlias, value: generated);
    SecureLogger.i('keystore.db_key.generated');
    return generated;
  }

  static Future<void> saveSessionToken(String token) =>
      _storage.write(key: _sessionTokenAlias, value: token);

  static Future<String?> getSessionToken() =>
      _storage.read(key: _sessionTokenAlias);

  static Future<void> clearSession() =>
      _storage.delete(key: _sessionTokenAlias);

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
