import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/attendance_repository.dart';
import '../../data/sync_worker.dart';
import 'attendance_event.dart';
import 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceBlocEvent, AttendanceState> {
  final AttendanceRepository _repository;
  final SyncWorker _sync;

  AttendanceBloc(this._repository, {SyncWorker? sync})
      : _sync = sync ?? SyncWorker(),
        super(const AttendanceUnknown()) {
    on<AttendanceStatusRequested>(_onStatus);
    on<AttendanceRecordRequested>(_onRecord);
    on<AttendanceSyncRequested>(_onSync);
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
      if (previous is AttendanceReady) {
        emit(previous);
      } else {
        emit(const AttendanceFailure('Could not record event.'));
      }
    }
  }

  Future<void> _onSync(
    AttendanceSyncRequested event,
    Emitter<AttendanceState> emit,
  ) async {
    if (state is! AttendanceReady) return;
    final current = state as AttendanceReady;

    emit(current.copyWith(syncing: true));
    try {
      await _sync.drain();
    } catch (_) {
      // The worker swallows per-row failures. Reaching here means
      // something at the queue level broke.
    }
    final status = await _repository.currentStatus();
    final count = await _repository.pendingCount();
    emit(AttendanceReady(
      status: status,
      pendingCount: count,
      lastRecorded: current.lastRecorded,
    ));
  }
}
