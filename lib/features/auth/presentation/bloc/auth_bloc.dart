import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_failure.dart';
import '../../../../core/network/auth_signals.dart';
import '../../data/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;
  StreamSubscription<void>? _sessionExpiredSub;

  AuthBloc(this._repository) : super(const AuthUnknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthSessionExpired>(_onSessionExpired);

    // The Dio interceptor emits here when a 401 is returned by the server.
    _sessionExpiredSub = AuthSignals.stream.listen((_) {
      if (!isClosed) add(const AuthSessionExpired());
    });
  }

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final has = await _repository.hasSession();
    if (!has) {
      emit(const AuthUnauthenticated());
      return;
    }
    try {
      final user = await _repository.me();
      emit(AuthAuthenticated(user));
    } on ApiFailure {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthAuthenticating());
    try {
      await _repository.login(email: event.email, password: event.password);
      final user = await _repository.me();
      emit(AuthAuthenticated(user));
    } on UnauthorizedFailure {
      emit(const AuthUnauthenticated(message: 'Invalid email or password'));
    } on ApiFailure catch (e) {
      emit(AuthUnauthenticated(message: e.message));
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    emit(const AuthUnauthenticated(message: 'Session expired'));
  }

  @override
  Future<void> close() async {
    await _sessionExpiredSub?.cancel();
    return super.close();
  }
}
