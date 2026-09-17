import 'package:equatable/equatable.dart';

import '../../domain/auth_user.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const [];
}

class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class AuthUnauthenticated extends AuthState {
  final String? message;
  const AuthUnauthenticated({this.message});

  @override
  List<Object?> get props => [message];
}

class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

class AuthAuthenticated extends AuthState {
  final AuthUser user;
  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}
