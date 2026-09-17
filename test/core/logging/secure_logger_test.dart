import 'package:flutter_test/flutter_test.dart';
import 'package:fieldproof_mobile/core/config/env.dart';
import 'package:fieldproof_mobile/core/logging/secure_logger.dart';

void main() {
  setUpAll(() {
    Env.current = Environment.dev;
    Env.logLevel = 'debug';
    SecureLogger.init();
  });

  group('SecureLogger redaction', () {
    test('redacts forbidden keys in a flat map', () {
      final out = SecureLogger.debugRedact({
        'user_id': '123',
        'password': 'hunter2',
        'token': 'abc',
        'latitude': 12.9,
        'safe_field': 'ok',
      });

      expect(out['password'], '[REDACTED]');
      expect(out['token'], '[REDACTED]');
      expect(out['latitude'], '[REDACTED]');
      expect(out['user_id'], '123');
      expect(out['safe_field'], 'ok');
    });

    test('redacts nested maps recursively', () {
      final out = SecureLogger.debugRedact({
        'outer': {
          'inner': {
            'db_key': 'topsecret',
            'request_id': 'req-1',
          },
        },
      });

      final nested = out['outer'] as Map<String, dynamic>;
      final inner = nested['inner'] as Map<String, dynamic>;
      expect(inner['db_key'], '[REDACTED]');
      expect(inner['request_id'], 'req-1');
    });

    test('truncates very long values', () {
      final long = 'a' * 1000;
      final out = SecureLogger.debugRedact({'payload': long});
      final value = out['payload'].toString();
      expect(value.contains('...[truncated]'), isTrue);
      expect(value.length, lessThan(600));
    });
  });
}
