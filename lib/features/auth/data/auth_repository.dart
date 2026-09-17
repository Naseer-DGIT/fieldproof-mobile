import '../../../core/errors/api_failure.dart';
import '../../../core/network/api_result.dart';
import '../../../core/security/key_store.dart';
import '../domain/auth_user.dart';

class AuthRepository {
  const AuthRepository();

  /// Calls POST /auth/login, stores the token in KeyStore, returns nothing
  /// on success. Throws ApiFailure on any error.
  Future<void> login({required String email, required String password}) async {
    final token = await ApiResult.post<String>(
      '/auth/login',
      body: {'email': email, 'password': password},
      parse: (data) => (data as Map<String, dynamic>)['access_token'] as String,
    );

    if (token.isEmpty) {
      throw const UnknownFailure();
    }
    await KeyStore.saveSessionToken(token);
  }

  Future<AuthUser> me() {
    return ApiResult.get<AuthUser>(
      '/auth/me',
      parse: (data) => AuthUser.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> logout() async {
    try {
      await ApiResult.post<void>('/auth/logout');
    } on ApiFailure {
      // Server-side logout is best-effort. Local cleanup always runs.
    }
    await KeyStore.clearSession();
  }

  Future<bool> hasSession() async {
    final token = await KeyStore.getSessionToken();
    return token != null && token.isNotEmpty;
  }
}
