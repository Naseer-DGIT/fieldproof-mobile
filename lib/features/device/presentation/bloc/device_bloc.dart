import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/api_failure.dart';
import '../../../../core/security/key_store.dart';
import '../../data/device_repository.dart';
import 'device_event.dart';
import 'device_state.dart';

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  final DeviceRepository _repository;

  DeviceBloc(this._repository) : super(const DeviceUnknown()) {
    on<DeviceStatusRequested>(_onStatus);
    on<DeviceRegistrationRequested>(_onRegister);
    on<DeviceResetRequested>(_onReset);
  }

  Future<void> _onStatus(
    DeviceStatusRequested event,
    Emitter<DeviceState> emit,
  ) async {
    final hasLocal = await _repository.isRegistered();
    if (!hasLocal) {
      emit(const DeviceUnregistered());
      return;
    }
    final remote = await _repository.fetchCurrent();
    if (remote == null) {
      await KeyStore.clearDevice();
      emit(const DeviceUnregistered());
      return;
    }
    emit(DeviceRegistered(remote));
  }

  Future<void> _onRegister(
    DeviceRegistrationRequested event,
    Emitter<DeviceState> emit,
  ) async {
    emit(const DeviceRegistering());
    try {
      final device = await _repository.register();
      emit(DeviceRegistered(device));
    } on ApiFailure catch (e) {
      emit(DeviceError(e.message));
    }
  }

  Future<void> _onReset(
    DeviceResetRequested event,
    Emitter<DeviceState> emit,
  ) async {
    await KeyStore.clearDevice();
    emit(const DeviceUnregistered());
  }
}
