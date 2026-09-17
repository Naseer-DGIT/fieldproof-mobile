import 'package:equatable/equatable.dart';

enum AttendanceEventType {
  checkIn('check_in'),
  checkOut('check_out'),
  breakStart('break_start'),
  breakEnd('break_end');

  final String wireValue;
  const AttendanceEventType(this.wireValue);

  static AttendanceEventType fromWire(String value) =>
      AttendanceEventType.values.firstWhere((e) => e.wireValue == value);
}

class AttendanceEvent extends Equatable {
  final String eventId;
  final AttendanceEventType type;
  final DateTime clientTimestamp;
  final String? previousHash;

  const AttendanceEvent({
    required this.eventId,
    required this.type,
    required this.clientTimestamp,
    this.previousHash,
  });

  /// Canonical JSON used both for signing and for sending to the server.
  /// Keys are sorted; no whitespace; UTF-8.
  String canonicalPayload() {
    final map = <String, dynamic>{
      'event_id': eventId,
      'type': type.wireValue,
      'ts': clientTimestamp.toUtc().toIso8601String(),
      if (previousHash != null) 'prev': previousHash,
    };
    final keys = map.keys.toList()..sort();
    final buffer = StringBuffer('{');
    for (var i = 0; i < keys.length; i++) {
      final k = keys[i];
      final v = map[k];
      if (i > 0) buffer.write(',');
      buffer.write('"$k":');
      if (v is String) {
        buffer.write('"${v.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"');
      } else {
        buffer.write(v);
      }
    }
    buffer.write('}');
    return buffer.toString();
  }

  @override
  List<Object?> get props => [eventId, type, clientTimestamp, previousHash];
}

/// Current status shown to the user.
enum AttendanceStatus { checkedOut, checkedIn, onBreak }
