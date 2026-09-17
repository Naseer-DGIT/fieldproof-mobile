import 'package:equatable/equatable.dart';

class DeviceRegistration extends Equatable {
  final int id;
  final int userId;
  final String publicKey;
  final String platform;
  final String attestationStatus;
  final bool revoked;

  const DeviceRegistration({
    required this.id,
    required this.userId,
    required this.publicKey,
    required this.platform,
    required this.attestationStatus,
    required this.revoked,
  });

  factory DeviceRegistration.fromJson(Map<String, dynamic> json) =>
      DeviceRegistration(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        publicKey: json['public_key'] as String,
        platform: (json['platform'] as String?) ?? 'unknown',
        attestationStatus: json['attestation_status'] as String,
        revoked: json['revoked'] as bool,
      );

  @override
  List<Object?> get props =>
      [id, userId, publicKey, platform, attestationStatus, revoked];
}
