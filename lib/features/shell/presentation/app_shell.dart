import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_event.dart';
import 'bloc/app_shell_bloc.dart';
import 'bloc/app_shell_event.dart';
import 'bloc/app_shell_state.dart';
import 'screens/attendance_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/security_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _screens = <Widget>[
    AttendanceScreen(),
    HistoryScreen(),
    SecurityScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppShellBloc, AppShellState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('FieldProof'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
                onPressed: () => context
                    .read<AuthBloc>()
                    .add(const AuthLogoutRequested()),
              ),
            ],
          ),
          body: SafeArea(
            child: IndexedStack(
              index: state.selectedIndex,
              children: _screens,
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: state.selectedIndex,
            onDestinationSelected: (index) => context
                .read<AppShellBloc>()
                .add(AppShellTabSelected(index)),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.fingerprint),
                label: 'Attendance',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.security),
                label: 'Security',
              ),
              NavigationDestination(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
