import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_error.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../core/token_storage.dart';
import '../models/payment_order.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final dio = DioClient.create(
    storage,
    () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
  return PaymentsRepository(dio);
});

class PaymentsRepository {
  PaymentsRepository(this._dio);
  final Dio _dio;

  /// GET /payments/packs — available top-up amounts in paise.
  Future<List<int>> getPaymentPacks() async {
    try {
      final response = await _dio.get<dynamic>('/payments/packs');
      final body = response.data;
      List<dynamic> raw;
      if (body is List) {
        raw = body;
      } else if (body is Map) {
        raw = (body['packs'] ?? body['data'] ?? body['amounts'] ?? []) as List;
      } else {
        return const [];
      }
      return raw
          .map((e) => _toInt(e is Map
              ? (e['amount_paise'] ?? e['paise'] ?? e['amount'])
              : e))
          .where((v) => v > 0)
          .toList();
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// POST /payments/create-order
  /// Returns a PaymentOrder whose key_id must be used to initialise Razorpay.
  Future<PaymentOrder> createOrder(int amountPaise) async {
    try {
      final response = await _dio.post<dynamic>(
        '/payments/create-order',
        data: {'amount_paise': amountPaise},
        options: Options(
          // Shorter timeout for payment creation — user is actively waiting.
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw ServerError(
          statusCode: response.statusCode ?? 0,
          message: 'Unexpected response from server (${body.runtimeType}). '
              'Please try again.',
        );
      }
      return PaymentOrder.fromJson(body);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  /// POST /payments/verify
  /// Called ONLY from onPaymentSuccess — never from error or dismiss callbacks.
  /// Sends Razorpay's payment proof to the backend so it can credit the account.
  Future<void> verifyPayment({
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/payments/verify',
        data: {
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_order_id': razorpayOrderId,
          'razorpay_signature': razorpaySignature,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }
}
