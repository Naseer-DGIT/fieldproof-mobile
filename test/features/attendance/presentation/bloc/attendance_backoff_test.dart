import 'package:flutter_test/flutter_test.dart';

import 'package:fieldproof_mobile/core/config/env.dart';
import 'package:fieldproof_mobile/core/logging/secure_logger.dart';
import 'package:fieldproof_mobile/features/attendance/data/attendance_queue.dart';
import 'package:fieldproof_mobile/features/attendance/data/attendance_repository.dart';
import 'package:fieldproof_mobile/features/attendance/data/drain_result.dart';
import 'package:fieldproof_mobile/features/attendance/domain/attendance_event.dart';
import 'package:fieldproof_mobile/features/attendance/presentation/bloc/attendance_bloc.dart';
import 'package:fieldproof_mobile/features/attendance/presentation/bloc/attendance_event.dart';
import 'package:fieldproof_mobile/features/attendance/presentation/bloc/attendance_state.dart';

class _FakeAttendanceRepository implements AttendanceRepository {
  int pendingCountValue;
  final AttendanceStatus status = AttendanceStatus.checkedIn;

  _FakeAttendanceRepository({this.pendingCountValue = 0});

  @override
  Future<AttendanceEvent> record(AttendanceEventType type) async {
    pendingCountValue += 1;
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
  setUpAll(() {
    Env.current = Environment.dev;
    Env.apiBaseUrl = 'http://localhost:9999/api/v1';
    Env.logLevel = 'error';
    Env.certificatePinning = false;
    SecureLogger.init();
  });

  test('clean drain of one row results in 0 pending', () async {
    final repo = _FakeAttendanceRepository(pendingCountValue: 1);
    var calls = 0;

    final bloc = AttendanceBloc(repo, drain: () async {
      calls += 1;
      repo.pendingCountValue = 0;
      return const DrainResult(synced: 1);
    });

    final states = <AttendanceState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const AttendanceStatusRequested());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    bloc.add(const AttendanceSyncRequested());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(calls, 1);
    expect(states.any((s) => s is AttendanceReady && s.syncing), isTrue);
    expect(states.last, isA<AttendanceReady>());
    expect((states.last as AttendanceReady).pendingCount, 0);

    await sub.cancel();
    await bloc.close();
  });

  test('retry drain keeps pending count and does not crash', () async {
    final repo = _FakeAttendanceRepository(pendingCountValue: 1);
    var calls = 0;

    final bloc = AttendanceBloc(repo, drain: () async {
      calls += 1;
      return const DrainResult(retries: 1);
    });

    bloc.add(const AttendanceStatusRequested());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    bloc.add(const AttendanceSyncRequested());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(calls, 1);
    expect(bloc.state, isA<AttendanceReady>());
    expect((bloc.state as AttendanceReady).pendingCount, 1);

    await bloc.close();
  });

  test('close cancels the retry timer', () async {
    final repo = _FakeAttendanceRepository(pendingCountValue: 1);

    final bloc = AttendanceBloc(repo, drain: () async {
      return const DrainResult(retries: 1);
    });

    bloc.add(const AttendanceStatusRequested());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    bloc.add(const AttendanceSyncRequested());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Close before the 30s retry timer fires.
    await bloc.close();

    expect(bloc.isClosed, isTrue);
  });
}
