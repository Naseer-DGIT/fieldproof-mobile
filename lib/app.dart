import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/config/env.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/shell/presentation/app_shell.dart';
import 'features/shell/presentation/bloc/app_shell_bloc.dart';

class FieldProofApp extends StatelessWidget {
  const FieldProofApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<AuthRepository>(
      create: (_) => const AuthRepository(),
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
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, next) =>
          next is AuthUnauthenticated && prev is AuthAuthenticated,
      listener: (context, state) {
        // Logout from anywhere in the app returns to login.
        // No named routes yet — the shell is rebuilt from scratch.
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return const AppShell();
          }
          if (state is AuthUnknown) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
