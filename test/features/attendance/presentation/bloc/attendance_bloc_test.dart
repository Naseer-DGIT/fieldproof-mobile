import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fieldproof_mobile/features/attendance/data/attendance_queue.dart';
import 'package:fieldproof_mobile/features/attendance/data/attendance_repository.dart';
import 'package:fieldproof_mobile/features/attendance/domain/attendance_event.dart';
import 'package:fieldproof_mobile/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:fieldproof_mobile/features/attendance/presentation/bloc/attendance_event.dart';
import 'package:fieldproof_mobile/features/attendance/presentation/bloc/attendance_state.dart';

class _FakeAttendanceRepository implements AttendanceRepository {
  AttendanceStatus status;
  int pendingCountValue;
  final List<AttendanceEventType> recorded = [];
  bool throwOnRecord;

  _FakeAttendanceRepository({
    this.status = AttendanceStatus.checkedOut,
    this.pendingCountValue = 0,
    this.throwOnRecord = false,
  });

  @override
  Future<AttendanceEvent> record(AttendanceEventType type) async {
    if (throwOnRecord) {
      throw StateError('simulated failure');
    }
    recorded.add(type);
    pendingCountValue += 1;
    switch (type) {
      case AttendanceEventType.checkIn:
        status = AttendanceStatus.checkedIn;
      case AttendanceEventType.checkOut:
        status = AttendanceStatus.checkedOut;
      case AttendanceEventType.breakStart:
        status = AttendanceStatus.onBreak;
      case AttendanceEventType.breakEnd:
        status = AttendanceStatus.checkedIn;
    }
    return AttendanceEvent(
      eventId: 'fake',
      type: type,
      clientTimestamp: DateTime.now().toUtc(),
    );
  }

  @override
  Future<int> pendingCount() async => pendingCountValue;

  @override
  Future<List<QueuedEvent>> pending() async => const [];

  @override
  Future<AttendanceStatus> currentStatus() async => status;
}

void main() {
  group('AttendanceBloc', () {
    blocTest<AttendanceBloc, AttendanceState>(
      'status request on empty queue → checkedOut, 0 pending',
      build: () => AttendanceBloc(_FakeAttendanceRepository()),
      act: (bloc) => bloc.add(const AttendanceStatusRequested()),
      expect: () => [
        const AttendanceReady(
          status: AttendanceStatus.checkedOut,
          pendingCount: 0,
        ),
      ],
    );

    blocTest<AttendanceBloc, AttendanceState>(
      'record check-in → Recording then Ready(checkedIn)',
      build: () => AttendanceBloc(_FakeAttendanceRepository()),
      act: (bloc) => bloc
          .add(const AttendanceRecordRequested(AttendanceEventType.checkIn)),
      expect: () => [
        const AttendanceRecording(),
        const AttendanceReady(
          status: AttendanceStatus.checkedIn,
          pendingCount: 1,
          lastRecorded: AttendanceEventType.checkIn,
        ),
      ],
    );

    blocTest<AttendanceBloc, AttendanceState>(
      'record failure restores previous ready state if any',
      build: () => AttendanceBloc(_FakeAttendanceRepository(
        status: AttendanceStatus.checkedIn,
        pendingCountValue: 3,
        throwOnRecord: true,
      )),
      seed: () => const AttendanceReady(
        status: AttendanceStatus.checkedIn,
        pendingCount: 3,
      ),
      act: (bloc) => bloc
          .add(const AttendanceRecordRequested(AttendanceEventType.checkOut)),
      expect: () => [
        const AttendanceRecording(),
        const AttendanceReady(
          status: AttendanceStatus.checkedIn,
          pendingCount: 3,
        ),
      ],
    );
  });
}
