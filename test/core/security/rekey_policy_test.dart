// RekeyPolicy and KeyStore alias tests.
//
// No database access. Exercises:
//   - primary key generation and reuse
//   - next/prev alias independence
//   - isDue() timing around the 90-day boundary
//
// The DB rekey itself needs a real device; see
// integration_test/core/storage/rekey_test.dart.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldproof_mobile/core/config/env.dart';
import 'package:fieldproof_mobile/core/logging/secure_logger.dart';
import 'package:fieldproof_mobile/core/security/key_store.dart';
import 'package:fieldproof_mobile/core/security/rekey_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = <String, String>{};

  setUpAll(() {
    Env.current = Environment.dev;
    Env.apiBaseUrl = 'http://localhost:9999/api/v1';
    Env.logLevel = 'error';
    Env.certificatePinning = false;
    SecureLogger.init();
  });

  setUp(() {
    store.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map).cast<String, dynamic>();
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return store[key];
          case 'write':
            store[key!] = args['value'] as String;
            return null;
          case 'delete':
            store.remove(key);
            return null;
          case 'deleteAll':
            store.clear();
            return null;
          case 'readAll':
            return Map<String, String>.from(store);
          case 'containsKey':
            return store.containsKey(key);
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  test('primary key is generated once and reused', () async {
    final a = await KeyStore.getOrCreateDbKey();
    final b = await KeyStore.getOrCreateDbKey();
    expect(a, b);
    expect(a.length, greaterThan(40));
  });

  test('next and prev aliases are independent of primary', () async {
    await KeyStore.setDbKey('primary');
    await KeyStore.setNextDbKey('next');
    await KeyStore.setPrevDbKey('prev');

    expect(await KeyStore.getDbKey(), 'primary');
    expect(await KeyStore.getNextDbKey(), 'next');
    expect(await KeyStore.getPrevDbKey(), 'prev');

    await KeyStore.clearNextDbKey();
    expect(await KeyStore.getNextDbKey(), isNull);
    expect(await KeyStore.getDbKey(), 'primary');
  });

  test('isDue returns false on first call and records a timestamp', () async {
    expect(await KeyStore.getLastRekeyAt(), isNull);
    expect(await RekeyPolicy.isDue(), isFalse);
    expect(await KeyStore.getLastRekeyAt(), isNotNull);
  });

  test('isDue returns true when the interval has elapsed', () async {
    final longAgo = DateTime.now().toUtc().subtract(const Duration(days: 91));
    await KeyStore.setLastRekeyAt(longAgo);
    expect(await RekeyPolicy.isDue(), isTrue);
  });

  test('isDue returns false when the interval has not elapsed', () async {
    final recent = DateTime.now().toUtc().subtract(const Duration(days: 89));
    await KeyStore.setLastRekeyAt(recent);
    expect(await RekeyPolicy.isDue(), isFalse);
  });
}
