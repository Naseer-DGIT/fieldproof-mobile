import 'package:equatable/equatable.dart';

import '../../domain/attendance_event.dart';

sealed class AttendanceState extends Equatable {
  const AttendanceState();

  @override
  List<Object?> get props => const [];
}

class AttendanceUnknown extends AttendanceState {
  const AttendanceUnknown();
}

class AttendanceReady extends AttendanceState {
  final AttendanceStatus status;
  final int pendingCount;
  final AttendanceEventType? lastRecorded;
  final bool syncing;

  const AttendanceReady({
    required this.status,
    required this.pendingCount,
    this.lastRecorded,
    this.syncing = false,
  });

  AttendanceReady copyWith({
    AttendanceStatus? status,
    int? pendingCount,
    AttendanceEventType? lastRecorded,
    bool? syncing,
  }) =>
      AttendanceReady(
        status: status ?? this.status,
        pendingCount: pendingCount ?? this.pendingCount,
        lastRecorded: lastRecorded ?? this.lastRecorded,
        syncing: syncing ?? this.syncing,
      );

  @override
  List<Object?> get props => [status, pendingCount, lastRecorded, syncing];
}

class AttendanceRecording extends AttendanceState {
  const AttendanceRecording();
}

class AttendanceFailure extends AttendanceState {
  final String message;
  const AttendanceFailure(this.message);

  @override
  List<Object?> get props => [message];
}
