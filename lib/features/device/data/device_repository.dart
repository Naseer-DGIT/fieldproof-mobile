import 'dart:io' show Platform;

import '../../../core/errors/api_failure.dart';
import '../../../core/network/api_result.dart';
import '../../../core/security/device_key.dart';
import '../../../core/security/key_store.dart';
import '../domain/device_registration.dart';

class DeviceRepository {
  const DeviceRepository();

  /// Ensures a key pair exists, uploads the public key, stores the
  /// server-assigned device id. Idempotent on the server.
  Future<DeviceRegistration> register() async {
    final publicKey = await DeviceKey.ensureKeyPair();

    final device = await ApiResult.post<DeviceRegistration>(
      '/devices/register',
      body: {
        'public_key': publicKey,
        'platform': Platform.isIOS ? 'ios' : 'android',
      },
      parse: (data) =>
          DeviceRegistration.fromJson(data as Map<String, dynamic>),
    );

    await KeyStore.saveDeviceId(device.id);
    return device;
  }

  Future<DeviceRegistration?> fetchCurrent() async {
    try {
      return await ApiResult.get<DeviceRegistration>(
        '/devices/me',
        parse: (data) =>
            DeviceRegistration.fromJson(data as Map<String, dynamic>),
      );
    } on NotFoundFailure {
      return null;
    }
  }

  Future<bool> isRegistered() async {
    final id = await KeyStore.getDeviceId();
    final key = await DeviceKey.currentPublicKey();
    return id != null && key != null;
  }
}
