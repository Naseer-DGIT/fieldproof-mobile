import 'dart:convert';

import '../../../core/storage/database.dart';
import '../domain/attendance_event.dart';

class QueuedEvent {
  final int rowId;
  final String eventId;
  final AttendanceEventType type;
  final String payload;
  final String signature;
  final String? previousHash;
  final String idempotencyKey;
  final int createdAt;
  final String syncStatus;

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
        syncStatus: row['sync_status'] as String,
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
      'sync_status': 'pending',
    });
  }

  Future<List<QueuedEvent>> pending() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'attendance_queue',
      where: "sync_status = 'pending'",
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
    final result =
        await db.rawQuery("SELECT COUNT(*) FROM attendance_queue WHERE sync_status = 'pending'");
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

  /// Test and debug helper — clears the queue. Never call from production.
  Future<void> clearAll() async {
    final db = await AppDatabase.instance;
    await db.delete('attendance_queue');
  }

  /// Whether the payload column already contains the given canonical string.
  /// Useful in tests to assert the signed bytes match the sent bytes.
  static String decodePayload(String payload) => utf8.decode(base64Url.decode(payload));
}
