import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';
import 'api_error.dart';
import 'retry_interceptor.dart';

// ---------------------------------------------------------------------------
// Factory — call DioClient.create() once; store in a Riverpod provider.
// The generated API classes (lib/api/generated/) accept a Dio instance in
// their constructor:
//   final _auth = AuthApi(dioClient);
// ---------------------------------------------------------------------------
class DioClient {
  DioClient._();

  static Dio create(FlutterSecureStorage storage, void Function() onUnauthorised) {
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
      // Retries transient failures on GETs only — never on POSTs.
      // See GetRetryInterceptor for the full safety rationale.
      GetRetryInterceptor(dio),
      // LogInterceptor must NEVER be added in release — it logs full
      // request/response bodies including JWT tokens.
      // Add it only in a local debug session via a #if kDebugMode guard:
      //   if (kDebugMode) dio.interceptors.add(LogInterceptor(requestBody: true));
    ]);

    return dio;
  }

  /// Convert a [DioException] to a typed [ApiError].
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
      final message = (body is Map && body['detail'] != null)
          ? body['detail'].toString()
          : 'Request failed';
      return ServerError(statusCode: response.statusCode ?? 0, message: message);
    }

    return UnknownError(e);
  }
}

// ---------------------------------------------------------------------------
// JWT interceptor
// ---------------------------------------------------------------------------
class _JwtInterceptor extends Interceptor {
  _JwtInterceptor(this._storage, this._onUnauthorised);

  final FlutterSecureStorage _storage;
  final void Function() _onUnauthorised;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: kTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token is invalid or expired — clear it and send user to login.
      _storage.delete(key: kTokenKey);
      _storage.delete(key: kRoleKey);
      _onUnauthorised();
    }
    handler.next(err);
  }
}
