import 'package:flutter_test/flutter_test.dart';

import 'package:fieldproof_mobile/core/config/env.dart';
import 'package:fieldproof_mobile/core/errors/api_failure.dart';
import 'package:fieldproof_mobile/core/logging/secure_logger.dart';
import 'package:fieldproof_mobile/features/attendance/data/attendance_queue.dart';
import 'package:fieldproof_mobile/features/attendance/data/sync_worker.dart';
import 'package:fieldproof_mobile/features/attendance/domain/attendance_event.dart';

class _FakeQueue implements AttendanceQueue {
  final List<QueuedEvent> rows = [];
  int nextId = 1;
  final List<SyncStatus> transitions = [];

  @override
  Future<void> enqueue({
    required AttendanceEvent event,
    required String payloadCanonical,
    required String signatureB64,
    required String idempotencyKey,
  }) async {
    rows.add(QueuedEvent(
      rowId: nextId++,
      eventId: event.eventId,
      type: event.type,
      payload: payloadCanonical,
      signature: signatureB64,
      previousHash: event.previousHash,
      idempotencyKey: idempotencyKey,
      createdAt: 0,
      syncStatus: SyncStatus.pending,
      retryCount: 0,
    ));
  }

  @override
  Future<List<QueuedEvent>> pending() async =>
      rows.where((r) => r.syncStatus == SyncStatus.pending).toList();

  @override
  Future<List<QueuedEvent>> byStatus(SyncStatus status) async =>
      rows.where((r) => r.syncStatus == status).toList();

  @override
  Future<QueuedEvent?> lastEvent() async => rows.isEmpty ? null : rows.last;

  @override
  Future<int> pendingCount() async =>
      rows.where((r) => r.syncStatus == SyncStatus.pending).length;

  @override
  Future<String?> lastEventId() async =>
      rows.isEmpty ? null : rows.last.eventId;

  @override
  Future<void> markSynced(int rowId) async {
    transitions.add(SyncStatus.synced);
    _set(rowId, SyncStatus.synced);
  }

  @override
  Future<void> markRejected(int rowId) async {
    transitions.add(SyncStatus.rejected);
    _set(rowId, SyncStatus.rejected);
  }

  @override
  Future<void> markConflict(int rowId) async {
    transitions.add(SyncStatus.conflict);
    _set(rowId, SyncStatus.conflict);
  }

  @override
  Future<void> bumpRetry(int rowId) async {
    final i = rows.indexWhere((r) => r.rowId == rowId);
    final r = rows[i];
    rows[i] = _copy(r, syncStatus: r.syncStatus, retryCount: r.retryCount + 1);
  }

  @override
  Future<void> clearAll() async => rows.clear();

  void _set(int rowId, SyncStatus status) {
    final i = rows.indexWhere((r) => r.rowId == rowId);
    rows[i] = _copy(rows[i], syncStatus: status, retryCount: rows[i].retryCount);
  }

  static QueuedEvent _copy(
    QueuedEvent r, {
    required SyncStatus syncStatus,
    required int retryCount,
  }) =>
      QueuedEvent(
        rowId: r.rowId,
        eventId: r.eventId,
        type: r.type,
        payload: r.payload,
        signature: r.signature,
        previousHash: r.previousHash,
        idempotencyKey: r.idempotencyKey,
        createdAt: r.createdAt,
        syncStatus: syncStatus,
        retryCount: retryCount,
      );
}

QueuedEvent _row(int id) => QueuedEvent(
      rowId: id,
      eventId: 'evt-$id',
      type: AttendanceEventType.checkIn,
      payload: 'payload',
      signature: 'sig',
      previousHash: null,
      idempotencyKey: 'idem-$id',
      createdAt: 0,
      syncStatus: SyncStatus.pending,
      retryCount: 0,
    );

void main() {
  setUpAll(() {
    Env.current = Environment.dev;
    Env.apiBaseUrl = 'http://localhost:9999/api/v1';
    Env.logLevel = 'error';
    Env.certificatePinning = false;
    SecureLogger.init();
  });

  test('accepted marks row synced', () async {
    final queue = _FakeQueue()..rows.add(_row(1));
    var calls = 0;

    final worker = SyncWorker(
      queue: queue,
      poster: (r) async {
        calls += 1;
        return {'id': 100};
      },
    );

    final n = await worker.drain();
    expect(n, 1);
    expect(calls, 1);
    expect(queue.transitions, [SyncStatus.synced]);
    expect((await queue.pending()).length, 0);
  });

  test('validation failure marks row rejected', () async {
    final queue = _FakeQueue()..rows.add(_row(1));

    final worker = SyncWorker(
      queue: queue,
      poster: (r) async => throw const ValidationFailure(),
    );

    final n = await worker.drain();
    expect(n, 1);
    expect(queue.transitions, [SyncStatus.rejected]);
  });

  test('409 marks row conflict and stops the pass', () async {
    final queue = _FakeQueue()
      ..rows.add(_row(1))
      ..rows.add(_row(2));

    final worker = SyncWorker(
      queue: queue,
      poster: (r) async => throw const ConflictFailure(),
    );

    final n = await worker.drain();
    expect(n, 1);
    expect(queue.transitions, [SyncStatus.conflict]);
    expect((await queue.pending()).length, 1);
  });

  test('network failure leaves row pending and bumps retry', () async {
    final queue = _FakeQueue()..rows.add(_row(1));

    final worker = SyncWorker(
      queue: queue,
      poster: (r) async => throw const NetworkFailure('down'),
    );

    final n = await worker.drain();
    expect(n, 0);
    expect(queue.transitions, isEmpty);
    final pending = await queue.pending();
    expect(pending.length, 1);
    expect(pending.first.retryCount, 1);
  });
}
