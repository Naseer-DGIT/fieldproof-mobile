import '../../../core/errors/api_failure.dart';
import '../../../core/logging/secure_logger.dart';
import '../../../core/network/api_result.dart';
import 'attendance_queue.dart';

/// Result of a single sync attempt.
enum SyncOutcome { accepted, duplicate, rejected, conflict, retry, stopped }

/// Signature of the outbound call. Injectable for tests.
typedef EventPoster = Future<Map<String, dynamic>> Function(
  QueuedEvent row,
);

/// Drains the pending attendance queue against the server.
///
/// Rules:
///   - Stop at the first retryable failure. Do not skip rows: events
///     must reach the server in chain order.
///   - Stop at the first conflict. A chain mismatch means the local
///     queue and the server disagree; continuing would only widen the gap.
///   - Rejected rows are marked and skipped; they will never succeed.
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

  /// Runs one full drain pass. Returns the number of rows that ended
  /// in a terminal state (synced, rejected, or conflict) during this pass.
  Future<int> drain() async {
    final pending = await _queue.pending();
    var completed = 0;

    for (final row in pending) {
      final outcome = await _send(row);
      switch (outcome) {
        case SyncOutcome.accepted:
        case SyncOutcome.duplicate:
          await _queue.markSynced(row.rowId);
          completed += 1;
        case SyncOutcome.rejected:
          await _queue.markRejected(row.rowId);
          completed += 1;
        case SyncOutcome.conflict:
          await _queue.markConflict(row.rowId);
          completed += 1;
          return completed;
        case SyncOutcome.retry:
          await _queue.bumpRetry(row.rowId);
          return completed;
        case SyncOutcome.stopped:
          return completed;
      }
    }
    return completed;
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
    } on ApiFailure catch (e) {
      if (e.statusCode == 409) {
        SecureLogger.w('sync.conflict');
        return SyncOutcome.conflict;
      }
      if (e is ForbiddenFailure || e is NotFoundFailure) {
        SecureLogger.w('sync.stopped');
        return SyncOutcome.stopped;
      }
      SecureLogger.w('sync.retry');
      return SyncOutcome.retry;
    }
  }
}
