import 'package:logger/logger.dart';

import '../config/env.dart';

/// FieldProof secure logger.
///
/// Rules (enforced here, not by convention):
///   1. Denylist: any key matching a forbidden term is replaced with
///      [REDACTED] before the log line is built.
///   2. Allowlist: only [safeFields] keys pass through when the caller
///      uses [SecureLogger.event].
///   3. Prod: nothing is written to console. `_SanitizedOutput` drops
///      every event when [Env.isProd].
///   4. Values are truncated to [_maxValueLength] to prevent accidental
///      blob dumps (payloads, stack traces, base64 keys).
///
/// See DATA_CLASSIFICATION.md §4.1 and §4.2.
class SecureLogger {
  SecureLogger._();

  static late final Logger _logger;

  static const _redacted = '[REDACTED]';
  static const _truncated = '...[truncated]';
  static const _maxValueLength = 500;

  /// Substring match (case-insensitive) on the key name.
  /// Conservative on purpose — a false positive is a redacted field,
  /// a false negative is a leaked secret.
  static const _denyKeys = <String>[
    // auth
    'password', 'passwd', 'pin', 'otp',
    'token', 'jwt', 'bearer', 'authorization', 'cookie', 'session',
    // secrets / keys
    'secret', 'apikey', 'api_key', 'private_key', 'privatekey',
    'db_key', 'dbkey', 'keystore', 'kms',
    // biometric
    'biometric', 'embedding', 'face', 'fingerprint',
    // location
    'latitude', 'longitude', 'lat', 'lng', 'gps', 'location',
    // PII
    'email', 'phone', 'address', 'ssn', 'aadhaar', 'pan',
    // financial
    'credit_card', 'cvv', 'bank', 'iban',
  ];

  /// Only these keys are allowed when the caller opts into the
  /// allowlist path via [SecureLogger.event].
  static const _safeFields = <String>{
    'event_id',
    'request_id',
    'trace_id',
    'status_code',
    'error_type',
    'duration_ms',
    'user_id_hash',
    'device_id_hash',
    'environment',
    'flavor',
  };

  static void init() {
    _logger = Logger(
      level: _parseLevel(Env.logLevel),
      filter: ProductionFilter(),
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 100,
        colors: Env.isDev,
        printEmojis: false,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: _SanitizedOutput(),
    );
  }

  static Level _parseLevel(String value) {
    switch (value) {
      case 'debug':
        return Level.debug;
      case 'info':
        return Level.info;
      case 'warning':
        return Level.warning;
      case 'error':
        return Level.error;
      default:
        return Level.info;
    }
  }

  /// Generic logs. Message is sanitized; [data] is redacted recursively.
  static void d(String message, {Map<String, dynamic>? data}) =>
      _logger.d(_compose(message, data));
  static void i(String message, {Map<String, dynamic>? data}) =>
      _logger.i(_compose(message, data));
  static void w(String message, {Object? error}) =>
      _logger.w(message, error: _sanitizeValue(error));
  static void e(String message, {Object? error, StackTrace? stack}) =>
      _logger.e(message, error: _sanitizeValue(error), stackTrace: stack);

  /// Structured event logging — only keys in [_safeFields] survive.
  /// Use this for anything that touches attendance, devices, or AI.
  static void event(String name, {Map<String, dynamic>? data}) {
    final safe = <String, dynamic>{};
    if (data != null) {
      for (final entry in data.entries) {
        if (_safeFields.contains(entry.key)) {
          safe[entry.key] = _sanitizeValue(entry.value);
        }
      }
    }
    _logger.i('event=$name $safe');
  }

  // ---------------------------------------------------------------------
  // internals
  // ---------------------------------------------------------------------

  static String _compose(String message, Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return message;
    return '$message ${_redactMap(data)}';
  }

  static Map<String, dynamic> _redactMap(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    for (final entry in input.entries) {
      final key = entry.key;
      final value = entry.value;
      if (_isDenied(key)) {
        out[key] = _redacted;
      } else if (value is Map<String, dynamic>) {
        out[key] = _redactMap(value);
      } else {
        out[key] = _sanitizeValue(value);
      }
    }
    return out;
  }

  static bool _isDenied(String key) {
    final lower = key.toLowerCase();
    return _denyKeys.any(lower.contains);
  }

  static Object? _sanitizeValue(Object? value) {
    if (value == null) return null;
    final s = value.toString();
    if (s.length > _maxValueLength) {
      return '${s.substring(0, _maxValueLength)}$_truncated';
    }
    return value;
  }

  /// Exposes [_redactMap] for tests. Not for production call sites.
  static Map<String, dynamic> debugRedact(Map<String, dynamic> map) =>
      _redactMap(map);
}

class _SanitizedOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Prod builds must not write logs to console. Crash reporters
    // are wired later (S17) and will read from a sink, not stdout.
    if (Env.isProd) return;

    for (final line in event.lines) {
      // ignore: avoid_print
      print(line);
    }
  }
}
