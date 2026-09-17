import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../config/env.dart';
import '../errors/api_failure.dart';
import 'auth_signals.dart';
import '../logging/secure_logger.dart';
import '../security/key_store.dart';

/// FieldProof HTTP client.
///
/// One Dio instance per app, configured from Env. Interceptors are
/// ordered: auth → request ID → logging → error sanitization.
///
/// Never logs request or response bodies. See DATA_CLASSIFICATION §4.1.
class ApiClient {
  ApiClient._();

  static Dio? _dio;
  static const _uuid = Uuid();

  /// Returns the shared Dio instance. Throws if [init] has not run.
  static Dio get instance {
    final dio = _dio;
    if (dio == null) {
      throw StateError('ApiClient.init() must be called before use');
    }
    return dio;
  }

  /// Configure the shared Dio instance. Idempotent: calling twice
  /// replaces the instance (tests rely on this).
  static void init() {
    _dio = _buildDio();
    SecureLogger.i('api.client.init', data: {
      'base_url_host': Uri.parse(Env.apiBaseUrl).host,
    });
  }

  /// Test-only: replace the underlying Dio with a stub.
  static void debugOverride(Dio dio) {
    _dio = dio;
  }

  /// Test-only: clear the instance so the next [init] starts fresh.
  static void debugReset() {
    _dio = null;
  }

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(),
      _RequestIdInterceptor(),
      _LoggingInterceptor(),
      _ErrorInterceptor(),
    ]);

    return dio;
  }
}

// ---------------------------------------------------------------------
// Auth — inject token, clear session on 401
// ---------------------------------------------------------------------

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await KeyStore.getSessionToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      // KeyStore may be unavailable (unit tests, corrupted device).
      // A missing token is not fatal — the server will return 401.
      SecureLogger.w('api.auth.keystore_unavailable');
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await KeyStore.clearSession();
      SecureLogger.w('api.auth.session_cleared');
      AuthSignals.sessionExpired();
    }
    handler.next(err);
  }
}

// ---------------------------------------------------------------------
// Request ID — one UUID per request, for server-side tracing
// ---------------------------------------------------------------------

class _RequestIdInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-Request-ID'] = ApiClient._uuid.v4();
    handler.next(options);
  }
}

// ---------------------------------------------------------------------
// Logging — method, path, status, duration. Never bodies.
// ---------------------------------------------------------------------

class _LoggingInterceptor extends Interceptor {
  static const _startKey = '_fp_started_at';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now().microsecondsSinceEpoch;
    SecureLogger.i('api.request', data: {
      'request_id': options.headers['X-Request-ID'] as String?,
      'method': options.method,
      'path': options.path,
    });
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final started = response.requestOptions.extra[_startKey] as int?;
    final durationMs = started == null
        ? null
        : ((DateTime.now().microsecondsSinceEpoch - started) / 1000).round();

    SecureLogger.i('api.response', data: {
      'request_id': response.requestOptions.headers['X-Request-ID'] as String?,
      'status_code': response.statusCode,
      'duration_ms': durationMs,
      'path': response.requestOptions.path,
    });
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    SecureLogger.w('api.error', error: {
      'request_id': err.requestOptions.headers['X-Request-ID'],
      'status_code': err.response?.statusCode,
      'type': err.type.name,
      'path': err.requestOptions.path,
    });
    handler.next(err);
  }
}

// ---------------------------------------------------------------------
// Error sanitization — DioException out, ApiFailure in
// ---------------------------------------------------------------------

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err.copyWith(error: _classify(err)));
  }

  ApiFailure _classify(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutFailure();
      case DioExceptionType.connectionError:
        return const NetworkFailure('Cannot reach server.');
      case DioExceptionType.badResponse:
        final code = err.response?.statusCode ?? 0;
        if (code == 401) return const UnauthorizedFailure();
        if (code == 403) return const ForbiddenFailure();
        if (code == 404) return const NotFoundFailure();
        if (code == 422) return const ValidationFailure();
        if (code >= 500) return ServerFailure(code);
        return const UnknownFailure();
      case DioExceptionType.cancel:
        return const NetworkFailure('Request cancelled.');
      case DioExceptionType.badCertificate:
        return const NetworkFailure('Certificate verification failed.');
      case DioExceptionType.unknown:
        return const UnknownFailure();
    }
  }
}
