// Rekey integration test.
//
// Runs on a real device or emulator. Uses the actual sqflite_sqlcipher
// plugin, so PRAGMA rekey executes and encryption is exercised.
//
// Run:
//     flutter test integration_test/core/storage/rekey_test.dart -d <device-id>

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fieldproof_mobile/core/config/env.dart';
import 'package:fieldproof_mobile/core/logging/secure_logger.dart';
import 'package:fieldproof_mobile/core/security/key_store.dart';
import 'package:fieldproof_mobile/core/storage/database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final secureStore = <String, String>{};

  setUpAll(() {
    Env.current = Environment.dev;
    Env.apiBaseUrl = 'http://localhost:9999/api/v1';
    Env.logLevel = 'error';
    Env.certificatePinning = false;
    SecureLogger.init();
  });

  setUp(() async {
    secureStore.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map).cast<String, dynamic>();
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return secureStore[key];
          case 'write':
            secureStore[key!] = args['value'] as String;
            return null;
          case 'delete':
            secureStore.remove(key);
            return null;
          case 'deleteAll':
            secureStore.clear();
            return null;
          case 'readAll':
            return Map<String, String>.from(secureStore);
          case 'containsKey':
            return secureStore.containsKey(key);
          default:
            return null;
        }
      },
    );

    await AppDatabase.reset();
  });

  tearDown(() async {
    await AppDatabase.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  testWidgets('rekey preserves existing rows', (tester) async {
    final db = await AppDatabase.instance;

    await db.insert('attendance_queue', {
      'event_id': 'evt-before-rekey',
      'event_type': 'check_in',
      'payload': '{"x":1}',
      'signature': 'sig',
      'previous_hash': null,
      'idempotency_key': 'idem-1',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    final before = await db.query('attendance_queue');
    expect(before.length, 1);

    await AppDatabase.rekey();

    final after = await db.query('attendance_queue');
    expect(after.length, 1);
    expect(after.first['event_id'], 'evt-before-rekey');

    final newPrimary = await KeyStore.getDbKey();
    expect(newPrimary, isNotNull);
    expect(await KeyStore.getNextDbKey(), isNull);
    expect(await KeyStore.getPrevDbKey(), isNull);

    await AppDatabase.reset();
    final reopened = await AppDatabase.instance;
    final afterReopen = await reopened.query('attendance_queue');
    expect(afterReopen.length, 1);
  });

  testWidgets('rekey survives a crash after staging the next key',
      (tester) async {
    final db = await AppDatabase.instance;
    await db.insert('attendance_queue', {
      'event_id': 'evt-a',
      'event_type': 'check_in',
      'payload': '{}',
      'signature': 'sig',
      'previous_hash': null,
      'idempotency_key': 'idem-a',
      'created_at': 1,
    });

    expect(await KeyStore.getDbKey(), isNotNull);

    final newKey = KeyStore.generateDbKey();
    await KeyStore.setNextDbKey(newKey);

    await AppDatabase.reset();
    final reopened = await AppDatabase.instance;
    final rows = await reopened.query('attendance_queue');
    expect(rows.length, 1);
    expect(rows.first['event_id'], 'evt-a');
  });

  testWidgets('rekey survives a crash after the DB was rekeyed',
      (tester) async {
    final db = await AppDatabase.instance;
    await db.insert('attendance_queue', {
      'event_id': 'evt-b',
      'event_type': 'check_out',
      'payload': '{}',
      'signature': 'sig',
      'previous_hash': null,
      'idempotency_key': 'idem-b',
      'created_at': 2,
    });

    final oldKey = await KeyStore.getDbKey();
    final newKey = KeyStore.generateDbKey();

    await KeyStore.setNextDbKey(newKey);
    await db.execute("PRAGMA rekey = '$newKey'");

    await AppDatabase.reset();
    final reopened = await AppDatabase.instance;
    final rows = await reopened.query('attendance_queue');
    expect(rows.length, 1);
    expect(rows.first['event_id'], 'evt-b');

    expect(await KeyStore.getDbKey(), newKey);
    expect(await KeyStore.getNextDbKey(), isNull);
    expect(oldKey, isNot(newKey));
  });
}
