import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldproof_mobile/core/config/env.dart';
import 'package:fieldproof_mobile/core/logging/secure_logger.dart';
import 'package:fieldproof_mobile/core/network/api_client.dart';

/// Intercepts the transport layer while keeping ApiClient's real
/// interceptors (auth, request ID, logging, error) in the chain.
class _CaptureAdapter implements HttpClientAdapter {
  final List<RequestOptions> captured = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Env.current = Environment.dev;
    Env.apiBaseUrl = 'http://localhost:9999/api/v1';
    Env.logLevel = 'error';
    Env.certificatePinning = false;
    SecureLogger.init();
  });

  setUp(() {
    // Mock flutter_secure_storage so KeyStore reads do not throw.
    // Default: no token stored. Individual tests override as needed.
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        switch (call.method) {
          case 'read':
            return null;
          case 'write':
          case 'delete':
          case 'deleteAll':
            return null;
          case 'readAll':
            return <String, String>{};
          case 'containsKey':
            return false;
          default:
            return null;
        }
      },
    );

    ApiClient.debugReset();
    ApiClient.init();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  test('request carries X-Request-ID', () async {
    final adapter = _CaptureAdapter();
    ApiClient.instance.httpClientAdapter = adapter;

    await ApiClient.instance.get('/anything');

    expect(adapter.captured, hasLength(1));
    final headers = adapter.captured.first.headers;
    expect(headers.containsKey('X-Request-ID'), isTrue);
    expect(headers['X-Request-ID'], isNotEmpty);
  });

  test('no Authorization header when no token is stored', () async {
    final adapter = _CaptureAdapter();
    ApiClient.instance.httpClientAdapter = adapter;

    await ApiClient.instance.get('/anything');

    expect(adapter.captured, hasLength(1));
    expect(
      adapter.captured.first.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('Authorization header is added when a token is stored', () async {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        if (call.method == 'read') return 'test-token-abc';
        return null;
      },
    );

    final adapter = _CaptureAdapter();
    ApiClient.instance.httpClientAdapter = adapter;

    await ApiClient.instance.get('/anything');

    expect(adapter.captured, hasLength(1));
    expect(
      adapter.captured.first.headers['Authorization'],
      'Bearer test-token-abc',
    );
  });

  test('init is idempotent — calling twice does not throw', () {
    ApiClient.init();
    ApiClient.init();
    expect(ApiClient.instance, isNotNull);
  });
}
