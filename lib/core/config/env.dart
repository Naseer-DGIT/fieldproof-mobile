import 'package:flutter_dotenv/flutter_dotenv.dart';

/// FieldProof environment configuration.
///
/// Loaded once at startup from a flavor-specific .env file.
/// Reads: ENVIRONMENT, API_BASE_URL, LOG_LEVEL, CERTIFICATE_PINNING.
///
/// IMPORTANT: this class never reads secrets (tokens, keys, passwords).
/// Those come from KeyStore, not from .env.
enum Environment { dev, staging, prod }

class Env {
  static late Environment current;
  static late String apiBaseUrl;
  static late String logLevel;
  static late bool certificatePinning;

  static const _envKey = 'ENVIRONMENT';
  static const _urlKey = 'API_BASE_URL';
  static const _logKey = 'LOG_LEVEL';
  static const _pinKey = 'CERTIFICATE_PINNING';

  /// Loads the .env file matching [flavor] and validates every required key.
  /// Throws [StateError] if a key is missing — the app must not start
  /// in a half-configured state.
  static Future<void> load(String flavor) async {
    final fileName = '.env.$flavor';
    await dotenv.load(fileName: fileName);

    current = _parseEnvironment(dotenv.env[_envKey]);
    apiBaseUrl = _require(dotenv.env[_urlKey]);
    logLevel = _require(dotenv.env[_logKey]);
    certificatePinning = _require(dotenv.env[_pinKey]) == 'true';

    if (apiBaseUrl.endsWith('/')) {
      apiBaseUrl = apiBaseUrl.substring(0, apiBaseUrl.length - 1);
    }
  }

  static Environment _parseEnvironment(String? value) {
    switch (_require(value)) {
      case 'dev':
        return Environment.dev;
      case 'staging':
        return Environment.staging;
      case 'prod':
        return Environment.prod;
      default:
        throw StateError('Unknown ENVIRONMENT: $value');
    }
  }

  static String _require(String? value) {
    if (value == null || value.isEmpty) {
      throw StateError('Missing env key or empty value');
    }
    return value;
  }

  static bool get isProd => current == Environment.prod;
  static bool get isStaging => current == Environment.staging;
  static bool get isDev => current == Environment.dev;
}
