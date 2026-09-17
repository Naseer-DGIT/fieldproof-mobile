import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/attendance_repository.dart';
import 'attendance_event.dart';
import 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceBlocEvent, AttendanceState> {
  final AttendanceRepository _repository;

  AttendanceBloc(this._repository) : super(const AttendanceUnknown()) {
    on<AttendanceStatusRequested>(_onStatus);
    on<AttendanceRecordRequested>(_onRecord);
  }

  Future<void> _onStatus(
    AttendanceStatusRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    final status = await _repository.currentStatus();
    final count = await _repository.pendingCount();
    emit(AttendanceReady(status: status, pendingCount: count));
  }

  Future<void> _onRecord(
    AttendanceRecordRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    final previous = state;
    emit(const AttendanceRecording());
    try {
      await _repository.record(event.type);
      final status = await _repository.currentStatus();
      final count = await _repository.pendingCount();
      emit(AttendanceReady(
        status: status,
        pendingCount: count,
        lastRecorded: event.type,
      ));
    } catch (e) {
      // Restore the previous ready state if there was one; otherwise
      // fall through to Failure so the UI can show a message.
      if (previous is AttendanceReady) {
        emit(previous);
      } else {
        emit(const AttendanceFailure('Could not record event.'));
      }
    }
  }
}
