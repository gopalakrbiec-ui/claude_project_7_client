import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../core/token_storage.dart';
import 'api_error.dart';
import 'retry_interceptor.dart';

class DioClient {
  DioClient._();

  static Dio create(TokenStorage storage, void Function() onUnauthorised) {
    final dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: kConnectTimeout,
        receiveTimeout: kReceiveTimeout,
        headers: {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.addAll([
      _JwtInterceptor(storage, onUnauthorised),
      GetRetryInterceptor(dio),
    ]);

    return dio;
  }

  static ApiError handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const NetworkError();
    }

    final response = e.response;
    if (response != null) {
      final body = response.data;
      String message = 'Request failed (${response.statusCode})';
      if (body is Map && body['detail'] != null) {
        final detail = body['detail'];
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          message = first is Map ? (first['msg']?.toString() ?? detail.toString()) : detail.toString();
        } else {
          message = detail.toString();
        }
      }
      return ServerError(statusCode: response.statusCode ?? 0, message: message);
    }

    return UnknownError(e);
  }
}

class _JwtInterceptor extends Interceptor {
  _JwtInterceptor(this._storage, this._onUnauthorised);

  final TokenStorage _storage;
  final void Function() _onUnauthorised;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Synchronous read — no await, no Keystore, never hangs.
    final token = _storage.token;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      _storage.clear();
      _onUnauthorised();
    }
    handler.next(err);
  }
}
