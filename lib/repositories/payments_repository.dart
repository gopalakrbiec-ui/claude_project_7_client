import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../models/payment_order.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  final storage = ref.read(secureStorageProvider);
  final dio = DioClient.create(
    storage,
    () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
  return PaymentsRepository(dio);
});

class PaymentsRepository {
  PaymentsRepository(this._dio);
  final Dio _dio;

  /// POST /payments/create-order
  /// Returns a PaymentOrder whose key_id must be used to initialise Razorpay.
  Future<PaymentOrder> createOrder(int amountPaise) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/payments/create-order',
        data: {'amount_paise': amountPaise},
      );
      return PaymentOrder.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }
}
