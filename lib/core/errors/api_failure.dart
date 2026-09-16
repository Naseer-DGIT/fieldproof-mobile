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
