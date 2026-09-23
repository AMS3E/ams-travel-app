import 'package:dio/dio.dart';

import '../config/api_config.dart';

/// Error surfaced to the UI. [message] is safe to show to the user.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;

  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? serverMessage;
    if (data is Map) {
      serverMessage = (data['message'] ?? data['error'])?.toString();
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return ApiException('The connection timed out. Please try again.');
      case DioExceptionType.connectionError:
        return ApiException('No internet connection.');
      default:
        return ApiException(serverMessage ?? 'Something went wrong (${status ?? 'network'}).', statusCode: status);
    }
  }
}

/// Thin wrapper around Dio: base URL, timeouts, auth header and error mapping.
class ApiClient {
  ApiClient({required String? Function() tokenProvider})
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
          headers: {'Accept': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokenProvider();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) => _send(() => _dio.post<dynamic>(path, data: body));

  Future<dynamic> put(String path, {Object? body}) => _send(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) => _send(() => _dio.delete<dynamic>(path, data: body));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final res = await request();
      return unwrap(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Many APIs wrap payloads as `{ "data": ... }`. Accept both shapes so the
  /// repositories don't care which one the backend picks.
  static dynamic unwrap(dynamic body) {
    if (body is Map && body.containsKey('data') && body.length <= 3) {
      return body['data'];
    }
    return body;
  }
}
