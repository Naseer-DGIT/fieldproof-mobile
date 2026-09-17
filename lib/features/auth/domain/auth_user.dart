import 'package:equatable/equatable.dart';

class AuthUser extends Equatable {
  final int id;
  final String email;
  final String role;
  final int tenantId;

  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    required this.tenantId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int,
        email: json['email'] as String,
        role: json['role'] as String,
        tenantId: json['tenant_id'] as int,
      );

  @override
  List<Object?> get props => [id, email, role, tenantId];
}
