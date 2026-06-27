import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../models/order.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final storage = ref.read(secureStorageProvider);
  final dio = DioClient.create(
    storage,
    () => ref.read(authControllerProvider.notifier).forceLogout(),
  );
  return OrdersRepository(dio);
});

class CreateOrderParams {
  const CreateOrderParams({
    required this.templateId,
    required this.idempotencyKey,
    required this.name,
    required this.eventDate,
    required this.theme,
    required this.language,
    required this.mediaType,
    this.customerPhone,
  });

  final String templateId;
  final String idempotencyKey;
  final String name;
  final String eventDate; // ISO-8601 date string e.g. "2025-12-25"
  final String theme;
  final String language;
  final String mediaType; // "image" | "video"
  /// Agent-only: forwarded in input_payload.customer_phone.
  /// Backend infers the agent role from the JWT; this is purely metadata.
  final String? customerPhone;
}

class OrdersRepository {
  OrdersRepository(this._dio);
  final Dio _dio;

  Future<Order> createOrder(CreateOrderParams params) async {
    dev.log('[OrdersRepo] POST /orders — templateId=${params.templateId} key=${params.idempotencyKey}', name: 'order');
    try {
      final response = await _dio.post<Map<String, dynamic>>('/orders', data: {
        'template_id': params.templateId,
        'idempotency_key': params.idempotencyKey,
        'input_payload': {
          'name': params.name,
          'event_date': params.eventDate,
          'theme': params.theme,
          'language': params.language,
          'media_type': params.mediaType,
          if (params.customerPhone != null &&
              params.customerPhone!.isNotEmpty)
            'customer_phone': params.customerPhone,
        },
      });

      dev.log('[OrdersRepo] POST /orders response ${response.statusCode}: ${response.data}', name: 'order');
      return Order.fromJson(response.data!);
    } on DioException catch (e) {
      dev.log('[OrdersRepo] DioException: ${e.type} ${e.response?.statusCode} ${e.response?.data}', name: 'order');
      throw DioClient.handleDioError(e);
    }
  }

  Future<Order> getOrder(String orderId) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/orders/$orderId');
      return Order.fromJson(response.data!);
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }

  /// POST /orders/{id}/remove-watermark
  /// Backend debits credits and returns the clean (unwatermarked) URL.
  /// Throws ServerError(402) if the user has insufficient credits.
  Future<String> removeWatermark(String orderId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/orders/$orderId/remove-watermark',
      );
      return response.data!['clean_url'] as String;
    } on DioException catch (e) {
      throw DioClient.handleDioError(e);
    }
  }
}
