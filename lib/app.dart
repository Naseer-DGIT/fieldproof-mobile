import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/config/env.dart';
import 'features/attendance/data/attendance_queue.dart';
import 'features/attendance/data/attendance_repository.dart';
import 'features/attendance/presentation/bloc/attendance_bloc.dart';
import 'features/attendance/presentation/bloc/attendance_event.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/device/data/device_repository.dart';
import 'features/device/presentation/bloc/device_bloc.dart';
import 'features/device/presentation/bloc/device_event.dart';
import 'features/device/presentation/bloc/device_state.dart';
import 'features/device/presentation/screens/device_setup_screen.dart';
import 'features/shell/presentation/app_shell.dart';
import 'features/shell/presentation/bloc/app_shell_bloc.dart';

class FieldProofApp extends StatelessWidget {
  const FieldProofApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (_) => const AuthRepository(),
        ),
        RepositoryProvider<DeviceRepository>(
          create: (_) => const DeviceRepository(),
        ),
        RepositoryProvider<AttendanceRepository>(
          create: (_) => const AttendanceRepository(AttendanceQueue()),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (ctx) =>
                AuthBloc(ctx.read<AuthRepository>())..add(const AuthStarted()),
          ),
          BlocProvider<AppShellBloc>(
            create: (_) => AppShellBloc(),
          ),
        ],
        child: MaterialApp(
          title: 'FieldProof',
          debugShowCheckedModeBanner: !Env.isProd,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            useMaterial3: true,
          ),
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return BlocProvider<DeviceBloc>(
            create: (ctx) =>
                DeviceBloc(ctx.read<DeviceRepository>())
                  ..add(const DeviceStatusRequested()),
            child: const _DeviceGate(),
          );
        }
        if (state is AuthUnknown) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const LoginScreen();
      },
    );
  }
}

class _DeviceGate extends StatelessWidget {
  const _DeviceGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceBloc, DeviceState>(
      builder: (context, state) {
        if (state is DeviceRegistered) {
          return BlocProvider<AttendanceBloc>(
            create: (ctx) => AttendanceBloc(
              ctx.read<AttendanceRepository>(),
            )..add(const AttendanceStatusRequested()),
            child: const AppShell(),
          );
        }
        if (state is DeviceUnknown) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const DeviceSetupScreen();
      },
    );
  }
}
