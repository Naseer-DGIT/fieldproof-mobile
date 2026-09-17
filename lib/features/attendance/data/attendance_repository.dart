import 'package:uuid/uuid.dart';

import '../../../core/security/device_key.dart';
import '../domain/attendance_event.dart';
import 'attendance_queue.dart';

class AttendanceRepository {
  final AttendanceQueue _queue;
  static const _uuid = Uuid();

  const AttendanceRepository(this._queue);

  /// Creates a signed event, writes it to the encrypted queue.
  /// Returns the event that was queued.
  Future<AttendanceEvent> record(AttendanceEventType type) async {
    final lastId = await _queue.lastEventId();
    final event = AttendanceEvent(
      eventId: _uuid.v4(),
      type: type,
      clientTimestamp: DateTime.now().toUtc(),
      previousHash: lastId,
    );

    final canonical = event.canonicalPayload();
    final signature = await DeviceKey.sign(canonical);
    final idempotencyKey = _uuid.v4();

    await _queue.enqueue(
      event: event,
      payloadCanonical: canonical,
      signatureB64: signature,
      idempotencyKey: idempotencyKey,
    );
    return event;
  }

  Future<int> pendingCount() => _queue.pendingCount();

  Future<List<QueuedEvent>> pending() => _queue.pending();

  /// Derives the current status from the last queued event.
  Future<AttendanceStatus> currentStatus() async {
    final last = await _queue.lastEvent();
    if (last == null) return AttendanceStatus.checkedOut;
    switch (last.type) {
      case AttendanceEventType.checkIn:
        return AttendanceStatus.checkedIn;
      case AttendanceEventType.checkOut:
        return AttendanceStatus.checkedOut;
      case AttendanceEventType.breakStart:
        return AttendanceStatus.onBreak;
      case AttendanceEventType.breakEnd:
        return AttendanceStatus.checkedIn;
    }
  }
}
