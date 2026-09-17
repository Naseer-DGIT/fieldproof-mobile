import 'package:equatable/equatable.dart';

sealed class DeviceEvent extends Equatable {
  const DeviceEvent();

  @override
  List<Object?> get props => const [];
}

class DeviceStatusRequested extends DeviceEvent {
  const DeviceStatusRequested();
}

class DeviceRegistrationRequested extends DeviceEvent {
  const DeviceRegistrationRequested();
}

class DeviceResetRequested extends DeviceEvent {
  const DeviceResetRequested();
}
