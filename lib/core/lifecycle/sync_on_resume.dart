import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/attendance/presentation/bloc/attendance_bloc.dart';
import '../../features/attendance/presentation/bloc/attendance_event.dart';

/// Triggers an attendance sync whenever the app returns to the foreground.
///
/// The AttendanceBloc is only in the widget tree after auth and device
/// setup. If it is not provided at resume time, this does nothing.
class SyncOnResume extends StatefulWidget {
  final Widget child;

  const SyncOnResume({super.key, required this.child});

  @override
  State<SyncOnResume> createState() => _SyncOnResumeState();
}

class _SyncOnResumeState extends State<SyncOnResume>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;

    final bloc = _maybeAttendanceBloc();
    bloc?.add(const AttendanceSyncRequested());
  }

  AttendanceBloc? _maybeAttendanceBloc() {
    try {
      return context.read<AttendanceBloc>();
    } catch (_) {
      // No provider — user has not reached the attendance screen yet.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
