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

      // 402 insufficient_balance — parse available/required paise.
      if (response.statusCode == 402 && body is Map) {
        int parsePaise(String key) {
          final v = body[key];
          if (v is num) return v.toInt();
          if (v is String) return (double.tryParse(v)?.toInt()) ?? 0;
          return 0;
        }
        return InsufficientCreditsError(
          availablePaise: parsePaise('available_paise'),
          requiredPaise: parsePaise('required_paise'),
        );
      }

      String message = 'Request failed (${response.statusCode})';
      if (body is Map && body['detail'] != null) {
        final detail = body['detail'];
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map) {
            final msg = first['msg']?.toString() ?? '';
            final loc = (first['loc'] as List?)?.skip(1).join('.') ?? '';
            message = loc.isNotEmpty ? '$msg: $loc' : msg;
          } else {
            message = detail.toString();
          }
        } else {
          message = detail.toString();
        }
      } else if (body is Map && body['error'] != null) {
        message = body['error'].toString();
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
