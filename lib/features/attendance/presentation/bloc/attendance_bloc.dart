import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/attendance_repository.dart';
import '../../data/drain_result.dart';
import '../../data/sync_worker.dart';
import 'attendance_event.dart';
import 'attendance_state.dart';

class AttendanceBloc extends Bloc<AttendanceBlocEvent, AttendanceState> {
  final AttendanceRepository _repository;
  final SyncWorker _sync;

  static const _initialBackoff = Duration(seconds: 30);
  static const _maxBackoff = Duration(minutes: 10);

  Timer? _retryTimer;
  Duration _backoff = _initialBackoff;

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
    if (count > 0) {
      _scheduleNextSync();
    }
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
      // A new event is pending: try immediately, then on backoff.
      add(const AttendanceSyncRequested());
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

    _retryTimer?.cancel();

    emit(current.copyWith(syncing: true));
    DrainResult result;
    try {
      result = await _sync.drain();
    } catch (_) {
      result = const DrainResult(retries: 1);
    }

    final status = await _repository.currentStatus();
    final count = await _repository.pendingCount();
    emit(AttendanceReady(
      status: status,
      pendingCount: count,
      lastRecorded: current.lastRecorded,
    ));

    if (count == 0) {
      _backoff = _initialBackoff;
      return;
    }
    if (result.allClean) {
      _backoff = _initialBackoff;
    } else {
      _backoff = _doubled(_backoff);
    }
    _scheduleNextSync();
  }

  void _scheduleNextSync() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_backoff, () {
      if (!isClosed) add(const AttendanceSyncRequested());
    });
  }

  Duration _doubled(Duration d) {
    final next = d * 2;
    return next > _maxBackoff ? _maxBackoff : next;
  }

  @override
  Future<void> close() {
    _retryTimer?.cancel();
    return super.close();
  }
}
