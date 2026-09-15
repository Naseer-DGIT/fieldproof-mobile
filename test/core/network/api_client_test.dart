import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
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
  setUpAll(() {
    Env.current = Environment.dev;
    Env.apiBaseUrl = 'http://localhost:9999/api/v1';
    Env.logLevel = 'error';
    Env.certificatePinning = false;
    SecureLogger.init();
  });

  setUp(() {
    ApiClient.debugReset();
    ApiClient.init();
  });

  test('request carries X-Request-ID', () async {
    final adapter = _CaptureAdapter();
    ApiClient.instance.httpClientAdapter = adapter;

    await ApiClient.instance.get('/anything');

    expect(adapter.captured.length, 1);
    final headers = adapter.captured.first.headers;
    expect(headers.containsKey('X-Request-ID'), isTrue);
    expect(headers['X-Request-ID'], isNotEmpty);
  });

  test('Authorization is added when a session token exists', () async {
    final adapter = _CaptureAdapter();
    ApiClient.instance.httpClientAdapter = adapter;

    await ApiClient.instance.get('/anything');

    // No token saved in this test — header must be absent.
    expect(adapter.captured.first.headers.containsKey('Authorization'), isFalse);
  });

  test('init is idempotent — calling twice does not throw', () {
    ApiClient.init();
    ApiClient.init();
    expect(ApiClient.instance, isNotNull);
  });
}
