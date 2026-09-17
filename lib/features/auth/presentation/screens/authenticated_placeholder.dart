import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class AuthenticatedPlaceholder extends StatelessWidget {
  const AuthenticatedPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    final user = state is AuthAuthenticated ? state.user : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FieldProof'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Signed in', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(user?.email ?? 'unknown'),
            Text('role: ${user?.role ?? '-'}'),
            const SizedBox(height: 24),
            const Text('S2 will replace this with the app shell'),
          ],
        ),
      ),
    );
  }
}
