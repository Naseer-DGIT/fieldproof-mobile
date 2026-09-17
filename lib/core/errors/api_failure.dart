/// Sanitized API failures. Callers never see raw DioException,
/// server stack traces, or response bodies.
sealed class ApiFailure implements Exception {
  final String message;
  final int? statusCode;

  const ApiFailure(this.message, {this.statusCode});

  @override
  String toString() => 'ApiFailure($statusCode): $message';
}

class NetworkFailure extends ApiFailure {
  const NetworkFailure(super.message);
}

class TimeoutFailure extends ApiFailure {
  const TimeoutFailure() : super('Request timed out. Please retry.');
}

class UnauthorizedFailure extends ApiFailure {
  const UnauthorizedFailure() : super('Session expired.', statusCode: 401);
}

class ForbiddenFailure extends ApiFailure {
  const ForbiddenFailure() : super('You do not have access.', statusCode: 403);
}

class NotFoundFailure extends ApiFailure {
  const NotFoundFailure() : super('Resource not found.', statusCode: 404);
}

/// 409. Used when the server rejects a request because the client state
/// has diverged — e.g. an attendance event whose previous_hash does not
/// match the server's chain head.
class ConflictFailure extends ApiFailure {
  final String? detail;
  const ConflictFailure({this.detail})
      : super(detail ?? 'Conflict with server state.', statusCode: 409);
}

class ValidationFailure extends ApiFailure {
  final Map<String, dynamic>? fieldErrors;

  const ValidationFailure({this.fieldErrors})
      : super('Validation failed.', statusCode: 422);
}

class ServerFailure extends ApiFailure {
  const ServerFailure(int statusCode)
      : super('Server error ($statusCode).', statusCode: statusCode);
}

class UnknownFailure extends ApiFailure {
  const UnknownFailure() : super('Something went wrong.');
}
