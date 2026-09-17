import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldproof_mobile/core/errors/api_failure.dart';
import 'package:fieldproof_mobile/features/device/data/device_repository.dart';
import 'package:fieldproof_mobile/features/device/domain/device_registration.dart';
import 'package:fieldproof_mobile/features/device/presentation/bloc/device_bloc.dart';
import 'package:fieldproof_mobile/features/device/presentation/bloc/device_event.dart';
import 'package:fieldproof_mobile/features/device/presentation/bloc/device_state.dart';

class _FakeDeviceRepository implements DeviceRepository {
  final bool localRegistered;
  final DeviceRegistration? remote;
  final Object? registerError;

  _FakeDeviceRepository({
    this.localRegistered = false,
    this.remote,
    this.registerError,
  });

  @override
  Future<bool> isRegistered() async => localRegistered;

  @override
  Future<DeviceRegistration?> fetchCurrent() async => remote;

  @override
  Future<DeviceRegistration> register() async {
    if (registerError != null) throw registerError!;
    return remote!;
  }
}

void main() {
  const device = DeviceRegistration(
    id: 7,
    userId: 1,
    publicKey: 'pub',
    platform: 'android',
    attestationStatus: 'PENDING',
    revoked: false,
  );

  group('DeviceBloc', () {
    blocTest<DeviceBloc, DeviceState>(
      'no local registration → Unregistered',
      build: () => DeviceBloc(_FakeDeviceRepository()),
      act: (bloc) => bloc.add(const DeviceStatusRequested()),
      expect: () => [const DeviceUnregistered()],
    );

    blocTest<DeviceBloc, DeviceState>(
      'local + remote match → Registered',
      build: () => DeviceBloc(_FakeDeviceRepository(
        localRegistered: true,
        remote: device,
      )),
      act: (bloc) => bloc.add(const DeviceStatusRequested()),
      expect: () => [const DeviceRegistered(device)],
    );

    blocTest<DeviceBloc, DeviceState>(
      'register success → Registering then Registered',
      build: () => DeviceBloc(_FakeDeviceRepository(remote: device)),
      act: (bloc) => bloc.add(const DeviceRegistrationRequested()),
      expect: () => [
        const DeviceRegistering(),
        const DeviceRegistered(device),
      ],
    );

    blocTest<DeviceBloc, DeviceState>(
      'register fails → Registering then Error',
      build: () => DeviceBloc(_FakeDeviceRepository(
        registerError: const NetworkFailure('offline'),
      )),
      act: (bloc) => bloc.add(const DeviceRegistrationRequested()),
      expect: () => [
        const DeviceRegistering(),
        const DeviceError('offline'),
      ],
    );
  });
}
