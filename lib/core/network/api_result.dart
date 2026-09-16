import 'package:dio/dio.dart';

import '../errors/api_failure.dart';
import 'api_client.dart';

/// Thin wrapper that converts DioException into ApiFailure.
/// Prefer this over calling Dio directly from repositories.
class ApiResult {
  ApiResult._();

  static Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic)? parse,
  }) =>
      _run(() => ApiClient.instance.get(path, queryParameters: query), parse);

  static Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? headers,
    T Function(dynamic)? parse,
  }) =>
      _run(
        () => ApiClient.instance.post(path, data: body, options: Options(headers: headers)),
        parse,
      );

  static Future<T> _run<T>(
    Future<Response> Function() call,
    T Function(dynamic)? parse,
  ) async {
    try {
      final response = await call();
      return parse != null ? parse(response.data) : response.data as T;
    } on DioException catch (e) {
      final failure = e.error;
      if (failure is ApiFailure) throw failure;
      throw const UnknownFailure();
    }
  }
}
