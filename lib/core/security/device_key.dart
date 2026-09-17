import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../logging/secure_logger.dart';
import 'key_store.dart';

/// Owns the device's Ed25519 key pair.
///
/// The private key is generated once on first use and stored in the
/// hardware-backed KeyStore. It never leaves the device. The public key
/// is uploaded to the server during device registration and used by the
/// server to verify event signatures (S2 Day 6+).
class DeviceKey {
  DeviceKey._();

  static final _algorithm = Ed25519();

  /// Returns the public key as base64url. Generates the key pair on first call.
  static Future<String> ensureKeyPair() async {
    final existing = await KeyStore.getDevicePrivateKey();
    if (existing != null) {
      final seed = base64Url.decode(existing);
      final keyPair = await _algorithm.newKeyPairFromSeed(seed);
      final publicKey = await keyPair.extractPublicKey();
      return base64Url.encode(publicKey.bytes);
    }

    final keyPair = await _algorithm.newKeyPair();
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    await KeyStore.saveDevicePrivateKey(base64Url.encode(privateBytes));
    SecureLogger.i('device_key.generated');

    return base64Url.encode(publicKey.bytes);
  }

  /// Returns the public key if a key pair exists, else null.
  static Future<String?> currentPublicKey() async {
    final stored = await KeyStore.getDevicePrivateKey();
    if (stored == null) return null;
    final seed = base64Url.decode(stored);
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    return base64Url.encode(publicKey.bytes);
  }

  /// Sign a UTF-8 payload. Returns base64url signature.
  /// Used in S2 Day 6 for attendance events.
  static Future<String> sign(String payload) async {
    final stored = await KeyStore.getDevicePrivateKey();
    if (stored == null) {
      throw StateError('Device key not initialised');
    }
    final seed = base64Url.decode(stored);
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final signature = await _algorithm.sign(
      utf8.encode(payload),
      keyPair: keyPair,
    );
    return base64Url.encode(signature.bytes);
  }
}
