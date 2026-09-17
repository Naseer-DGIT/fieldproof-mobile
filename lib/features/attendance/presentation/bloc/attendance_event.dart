import 'package:equatable/equatable.dart';

import '../../domain/attendance_event.dart';

sealed class AttendanceBlocEvent extends Equatable {
  const AttendanceBlocEvent();

  @override
  List<Object?> get props => const [];
}

class AttendanceStatusRequested extends AttendanceBlocEvent {
  const AttendanceStatusRequested();
}

class AttendanceRecordRequested extends AttendanceBlocEvent {
  final AttendanceEventType type;
  const AttendanceRecordRequested(this.type);

  @override
  List<Object?> get props => [type];
}
