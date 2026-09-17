import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldproof_mobile/core/errors/api_failure.dart';
import 'package:fieldproof_mobile/features/auth/data/auth_repository.dart';
import 'package:fieldproof_mobile/features/auth/domain/auth_user.dart';
import 'package:fieldproof_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fieldproof_mobile/features/auth/presentation/bloc/auth_event.dart';
import 'package:fieldproof_mobile/features/auth/presentation/bloc/auth_state.dart';

class _FakeAuthRepository implements AuthRepository {
  final bool sessionExists;
  final AuthUser? meResult;
  final Object? loginError;

  _FakeAuthRepository({
    this.sessionExists = false,
    this.meResult,
    this.loginError,
  });

  @override
  Future<bool> hasSession() async => sessionExists;

  @override
  Future<void> login({required String email, required String password}) async {
    if (loginError != null) throw loginError!;
  }

  @override
  Future<AuthUser> me() async {
    return meResult!;
  }

  @override
  Future<void> logout() async {}
}

void main() {
  const user = AuthUser(
    id: 1,
    email: 'test@fieldproof.local',
    role: 'employee',
    tenantId: 1,
  );

  group('AuthBloc', () {
    blocTest<AuthBloc, AuthState>(
      'emits Unauthenticated when no session exists',
      build: () => AuthBloc(_FakeAuthRepository()),
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthUnauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits Authenticated when session exists and /me succeeds',
      build: () => AuthBloc(_FakeAuthRepository(
        sessionExists: true,
        meResult: user,
      )),
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthAuthenticated(user)],
    );

    blocTest<AuthBloc, AuthState>(
      'login success emits Authenticating then Authenticated',
      build: () => AuthBloc(_FakeAuthRepository(
        sessionExists: false,
        meResult: user,
      )),
      act: (bloc) => bloc.add(const AuthLoginRequested(
        email: 'test@fieldproof.local',
        password: 'Test1234!',
      )),
      expect: () => [
        const AuthAuthenticating(),
        const AuthAuthenticated(user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'login 401 emits Authenticating then Unauthenticated with message',
      build: () => AuthBloc(_FakeAuthRepository(
        loginError: const UnauthorizedFailure(),
      )),
      act: (bloc) => bloc.add(const AuthLoginRequested(
        email: 'test@fieldproof.local',
        password: 'wrong',
      )),
      expect: () => [
        const AuthAuthenticating(),
        const AuthUnauthenticated(message: 'Invalid email or password'),
      ],
    );
  });
}
