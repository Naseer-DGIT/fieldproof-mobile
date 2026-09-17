import '../../../core/storage/database.dart';
import '../domain/attendance_event.dart';

enum SyncStatus {
  pending('pending'),
  synced('synced'),
  rejected('rejected'),
  conflict('conflict');

  final String wire;
  const SyncStatus(this.wire);

  static SyncStatus fromWire(String value) =>
      SyncStatus.values.firstWhere((s) => s.wire == value);
}

class QueuedEvent {
  final int rowId;
  final String eventId;
  final AttendanceEventType type;
  final String payload;
  final String signature;
  final String? previousHash;
  final String idempotencyKey;
  final int createdAt;
  final SyncStatus syncStatus;
  final int retryCount;

  const QueuedEvent({
    required this.rowId,
    required this.eventId,
    required this.type,
    required this.payload,
    required this.signature,
    required this.previousHash,
    required this.idempotencyKey,
    required this.createdAt,
    required this.syncStatus,
    required this.retryCount,
  });

  factory QueuedEvent.fromRow(Map<String, dynamic> row) => QueuedEvent(
        rowId: row['id'] as int,
        eventId: row['event_id'] as String,
        type: AttendanceEventType.fromWire(row['event_type'] as String),
        payload: row['payload'] as String,
        signature: row['signature'] as String,
        previousHash: row['previous_hash'] as String?,
        idempotencyKey: row['idempotency_key'] as String,
        createdAt: row['created_at'] as int,
        syncStatus: SyncStatus.fromWire(row['sync_status'] as String),
        retryCount: (row['retry_count'] as int?) ?? 0,
      );
}

class AttendanceQueue {
  const AttendanceQueue();

  Future<void> enqueue({
    required AttendanceEvent event,
    required String payloadCanonical,
    required String signatureB64,
    required String idempotencyKey,
  }) async {
    final db = await AppDatabase.instance;
    await db.insert('attendance_queue', {
      'event_id': event.eventId,
      'event_type': event.type.wireValue,
      'payload': payloadCanonical,
      'signature': signatureB64,
      'previous_hash': event.previousHash,
      'idempotency_key': idempotencyKey,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'sync_status': SyncStatus.pending.wire,
    });
  }

  Future<List<QueuedEvent>> pending() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'attendance_queue',
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.wire],
      orderBy: 'id ASC',
    );
    return rows.map(QueuedEvent.fromRow).toList();
  }

  Future<List<QueuedEvent>> byStatus(SyncStatus status) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'attendance_queue',
      where: 'sync_status = ?',
      whereArgs: [status.wire],
      orderBy: 'id ASC',
    );
    return rows.map(QueuedEvent.fromRow).toList();
  }

  Future<QueuedEvent?> lastEvent() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'attendance_queue',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return QueuedEvent.fromRow(rows.first);
  }

  Future<int> pendingCount() async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM attendance_queue WHERE sync_status = ?',
      [SyncStatus.pending.wire],
    );
    return (result.first.values.first as int?) ?? 0;
  }

  Future<String?> lastEventId() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'attendance_queue',
      columns: ['event_id'],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['event_id'] as String;
  }

  Future<void> markSynced(int rowId) async {
    final db = await AppDatabase.instance;
    await db.update(
      'attendance_queue',
      {'sync_status': SyncStatus.synced.wire},
      where: 'id = ?',
      whereArgs: [rowId],
    );
  }

  Future<void> markRejected(int rowId) async {
    final db = await AppDatabase.instance;
    await db.update(
      'attendance_queue',
      {'sync_status': SyncStatus.rejected.wire},
      where: 'id = ?',
      whereArgs: [rowId],
    );
  }

  Future<void> markConflict(int rowId) async {
    final db = await AppDatabase.instance;
    await db.update(
      'attendance_queue',
      {'sync_status': SyncStatus.conflict.wire},
      where: 'id = ?',
      whereArgs: [rowId],
    );
  }

  Future<void> bumpRetry(int rowId) async {
    final db = await AppDatabase.instance;
    await db.rawUpdate(
      'UPDATE attendance_queue SET retry_count = retry_count + 1 WHERE id = ?',
      [rowId],
    );
  }

  Future<void> clearAll() async {
    final db = await AppDatabase.instance;
    await db.delete('attendance_queue');
  }
}
