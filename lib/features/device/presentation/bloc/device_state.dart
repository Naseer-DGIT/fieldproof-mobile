import 'package:equatable/equatable.dart';

import '../../domain/device_registration.dart';

sealed class DeviceState extends Equatable {
  const DeviceState();

  @override
  List<Object?> get props => const [];
}

class DeviceUnknown extends DeviceState {
  const DeviceUnknown();
}

class DeviceUnregistered extends DeviceState {
  const DeviceUnregistered();
}

class DeviceRegistering extends DeviceState {
  const DeviceRegistering();
}

class DeviceRegistered extends DeviceState {
  final DeviceRegistration device;
  const DeviceRegistered(this.device);

  @override
  List<Object?> get props => [device];
}

class DeviceError extends DeviceState {
  final String message;
  const DeviceError(this.message);

  @override
  List<Object?> get props => [message];
}
