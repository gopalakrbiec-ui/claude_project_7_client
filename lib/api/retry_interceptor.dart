import 'package:dio/dio.dart';
import '../core/constants.dart';

// ---------------------------------------------------------------------------
// Safe-GET retry interceptor
//
// WHY GET-only:
//   GETs are idempotent by definition — repeating them cannot cause side
//   effects. POSTs are NOT safe to auto-retry:
//
//   • POST /orders — backend uses idempotency_key to deduplicate, BUT we
//     still do not auto-retry because the controller already reuses the same
//     key on manual retry and auto-retry would surprise the user (they may
//     have intentionally cancelled).
//   • POST /payments/create-order — could create multiple Razorpay orders.
//   • POST /orders/{id}/remove-watermark — could double-debit credits.
//   • POST /auth/request-otp — sends multiple SMS messages.
//
//   Any non-GET request that fails is surfaced as a typed ApiError and the
//   controller decides whether to prompt the user for a manual retry.
//
// WHAT gets retried:
//   Transient network-level failures only: connection timeout, receive timeout,
//   connection error (no route to host). We do NOT retry HTTP 5xx responses —
//   the server may be overloaded and retrying would make it worse.
//
// BACKOFF:
//   Attempt 0 delay: 1 s
//   Attempt 1 delay: 2 s
//   Attempt 2 delay: 4 s   (then hard fail — total extra wait ≤ 7 s)
// ---------------------------------------------------------------------------
class GetRetryInterceptor extends Interceptor {
  GetRetryInterceptor(this._dio);
  final Dio _dio;

  static const _attemptKey = '_retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final method = options.method.toUpperCase();

    // Only retry GETs and HEADs.
    if (method != 'GET' && method != 'HEAD') {
      handler.next(err);
      return;
    }

    // Only retry transient network failures, never HTTP errors.
    if (!_isTransient(err)) {
      handler.next(err);
      return;
    }

    final attempt = (options.extra[_attemptKey] as int?) ?? 0;
    if (attempt >= kGetMaxRetries) {
      handler.next(err);
      return;
    }

    // Exponential backoff: 1 s, 2 s, 4 s.
    final delay = kGetRetryBaseDelay * (1 << attempt);
    await Future<void>.delayed(delay);

    final retryOptions = options.copyWith(
      extra: Map<String, dynamic>.from(options.extra)
        ..[_attemptKey] = attempt + 1,
    );

    try {
      final response = await _dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }

  static bool _isTransient(DioException err) =>
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.sendTimeout ||
      err.type == DioExceptionType.connectionError;
}
