import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/attendance_event.dart';
import '../bloc/attendance_bloc.dart';
import '../bloc/attendance_event.dart';
import '../bloc/attendance_state.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        if (state is AttendanceUnknown) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is AttendanceFailure) {
          return Center(child: Text(state.message));
        }
        if (state is AttendanceRecording) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is! AttendanceReady) {
          return const SizedBox.shrink();
        }
        return _ReadyView(state: state);
      },
    );
  }
}

class _ReadyView extends StatelessWidget {
  final AttendanceReady state;
  const _ReadyView({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (state.status) {
      AttendanceStatus.checkedOut => 'Checked out',
      AttendanceStatus.checkedIn => 'Checked in',
      AttendanceStatus.onBreak => 'On break',
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Pending sync: ${state.pendingCount}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          if (state.status == AttendanceStatus.checkedOut)
            FilledButton(
              onPressed: () => context
                  .read<AttendanceBloc>()
                  .add(const AttendanceRecordRequested(
                      AttendanceEventType.checkIn)),
              child: const Text('Check in'),
            ),
          if (state.status == AttendanceStatus.checkedIn) ...[
            FilledButton.tonal(
              onPressed: () => context
                  .read<AttendanceBloc>()
                  .add(const AttendanceRecordRequested(
                      AttendanceEventType.breakStart)),
              child: const Text('Start break'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context
                  .read<AttendanceBloc>()
                  .add(const AttendanceRecordRequested(
                      AttendanceEventType.checkOut)),
              child: const Text('Check out'),
            ),
          ],
          if (state.status == AttendanceStatus.onBreak)
            FilledButton(
              onPressed: () => context
                  .read<AttendanceBloc>()
                  .add(const AttendanceRecordRequested(
                      AttendanceEventType.breakEnd)),
              child: const Text('End break'),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
