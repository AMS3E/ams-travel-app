import 'package:dio/dio.dart';

import '../config/api_config.dart';

/// Error surfaced to the UI. [message] is safe to show to the user.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;

  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    // The API answers errors as a problem JSON: {title, status, detail, instance}.
    String? serverMessage;
    if (data is Map) {
      serverMessage = (data['detail'] ?? data['title'])?.toString();
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

/// Where the client gets the signed-in traveller's token.
abstract class TokenSource {
  /// A token that is still valid (refreshed first when close to expiry), or
  /// null for a guest.
  Future<String?> accessToken();

  /// Called when the API rejected [token] with 401. Returns a fresh token, or
  /// null once the session is over (the traveller is then a guest).
  Future<String?> onRejected(String token);
}

/// No session: every request goes out as a guest.
class GuestTokens implements TokenSource {
  const GuestTokens();

  @override
  Future<String?> accessToken() async => null;

  @override
  Future<String?> onRejected(String token) async => null;
}

/// Thin wrapper around Dio: base URL, timeouts, auth header and error mapping.
///
/// Reads are public, so a guest sends no header; once signed in every request
/// carries the bearer token. A rejected token is refreshed once; if that fails
/// the request is sent again as a guest, so a public read never breaks on an
/// expired session.
class ApiClient {
  ApiClient({this._tokens = const GuestTokens(), HttpClientAdapter? adapter})
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
          headers: {'Accept': 'application/json'},
        ),
      ) {
    // Tests answer from fixtures instead of the network.
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  final Dio _dio;
  TokenSource _tokens;

  /// Set once the session holder exists (it needs this client to load the profile).
  set tokens(TokenSource value) => _tokens = value;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send((o) => _dio.get<dynamic>(path, queryParameters: _clean(query), options: o));

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send((o) => _dio.post<dynamic>(path, data: body, queryParameters: _clean(query), options: o));

  Future<dynamic> put(String path, {Object? body}) => _send((o) => _dio.put<dynamic>(path, data: body, options: o));

  Future<dynamic> delete(String path, {Object? body}) =>
      _send((o) => _dio.delete<dynamic>(path, data: body, options: o));

  /// Uploads one file as `multipart/form-data` (field `file`).
  Future<dynamic> upload(String path, {required String filePath, Map<String, dynamic>? query}) => _send(
    (o) async => _dio.post<dynamic>(
      path,
      data: FormData.fromMap({'file': await MultipartFile.fromFile(filePath)}),
      queryParameters: _clean(query),
      options: o,
    ),
  );

  Future<dynamic> _send(Future<Response<dynamic>> Function(Options options) request) async {
    Options withToken(String? token) =>
        Options(headers: {if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token'});

    final token = await _tokens.accessToken();
    try {
      return (await request(withToken(token))).data;
    } on DioException catch (e) {
      if (e.response?.statusCode != 401 || token == null) throw ApiException.fromDio(e);
      // The token was turned down: refresh once, or go on as a guest.
      final fresh = await _tokens.onRejected(token);
      try {
        return (await request(withToken(fresh))).data;
      } on DioException catch (e) {
        throw ApiException.fromDio(e);
      }
    }
  }

  /// Drops empty parameters and joins lists with commas (`ids=a,b`), the way
  /// the API reads them.
  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final out = <String, dynamic>{};
    query.forEach((key, value) {
      if (value is Iterable) {
        if (value.isNotEmpty) out[key] = value.join(',');
      } else if (value != null && value != '') {
        out[key] = value;
      }
    });
    return out;
  }
}
