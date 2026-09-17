import '../../../core/errors/api_failure.dart';
import '../../../core/logging/secure_logger.dart';
import '../../../core/network/api_result.dart';
import 'attendance_queue.dart';
import 'drain_result.dart';

enum SyncOutcome { accepted, duplicate, rejected, conflict, retry, stopped }

typedef EventPoster = Future<Map<String, dynamic>> Function(QueuedEvent row);

/// Drains the pending attendance queue against the server.
///
/// Rules:
///   - Stop at the first retryable failure. Do not skip rows.
///   - Stop at the first conflict. Local and server chain disagree.
///   - Rejected rows are marked and skipped.
class SyncWorker {
  final AttendanceQueue _queue;
  final EventPoster _post;

  SyncWorker({
    AttendanceQueue? queue,
    EventPoster? poster,
  })  : _queue = queue ?? const AttendanceQueue(),
        _post = poster ?? _defaultPoster;

  static Future<Map<String, dynamic>> _defaultPoster(QueuedEvent row) {
    return ApiResult.post<Map<String, dynamic>>(
      '/attendance/events',
      body: {
        'event_id': row.eventId,
        'event_type': row.type.wireValue,
        'payload_b64': row.payload,
        'signature_b64': row.signature,
        'previous_hash': row.previousHash,
        'idempotency_key': row.idempotencyKey,
      },
      parse: (data) => Map<String, dynamic>.from(data as Map),
    );
  }

  Future<DrainResult> drain() async {
    final pending = await _queue.pending();
    var synced = 0;
    var rejected = 0;
    var conflicts = 0;
    var retries = 0;

    for (final row in pending) {
      final outcome = await _send(row);
      switch (outcome) {
        case SyncOutcome.accepted:
        case SyncOutcome.duplicate:
          await _queue.markSynced(row.rowId);
          synced += 1;
        case SyncOutcome.rejected:
          await _queue.markRejected(row.rowId);
          rejected += 1;
        case SyncOutcome.conflict:
          await _queue.markConflict(row.rowId);
          conflicts += 1;
          return DrainResult(
            synced: synced,
            rejected: rejected,
            conflicts: conflicts,
            retries: retries,
          );
        case SyncOutcome.retry:
          await _queue.bumpRetry(row.rowId);
          retries += 1;
          return DrainResult(
            synced: synced,
            rejected: rejected,
            conflicts: conflicts,
            retries: retries,
          );
        case SyncOutcome.stopped:
          return DrainResult(
            synced: synced,
            rejected: rejected,
            conflicts: conflicts,
            retries: retries,
          );
      }
    }
    return DrainResult(synced: synced, rejected: rejected);
  }

  Future<SyncOutcome> _send(QueuedEvent row) async {
    try {
      final response = await _post(row);
      SecureLogger.event('sync.accepted', data: {
        'event_id': row.eventId,
        'status_code': 201,
      });
      return response['id'] == null
          ? SyncOutcome.duplicate
          : SyncOutcome.accepted;
    } on ValidationFailure {
      SecureLogger.w('sync.rejected');
      return SyncOutcome.rejected;
    } on ConflictFailure {
      SecureLogger.w('sync.conflict');
      return SyncOutcome.conflict;
    } on ForbiddenFailure {
      SecureLogger.w('sync.stopped');
      return SyncOutcome.stopped;
    } on ApiFailure {
      SecureLogger.w('sync.retry');
      return SyncOutcome.retry;
    }
  }
}
