import 'dart:developer' as dev;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../controllers/auth_controller.dart';
import '../core/token_storage.dart';
import '../models/order.dart';
import '../models/order_summary.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final storage = ref.read(tokenStorageProvider);
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
    this.userPhotoKeys = const [],
    this.userPrompt,
    this.aspectRatio = '9:16',
    this.customerPhone,
  });

  final String templateId;
  final String idempotencyKey;
  final List<String> userPhotoKeys;
  final String? userPrompt;
  final String aspectRatio;
  final String? customerPhone;
}

class OrdersRepository {
  OrdersRepository(this._dio);
  final Dio _dio;

  /// Uploads a user photo for face-swap generation.
  /// Returns the photo_key string to include in [createOrder].
  Future<String> uploadPhoto(File photo) async {
    dev.log('[OrdersRepo] POST /uploads/photo', name: 'order');
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          photo.path,
          filename: 'photo.jpg',
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/uploads/photo',
        data: formData,
      );
      dev.log('[OrdersRepo] upload response: ${response.data}', name: 'order');
      return response.data!['photo_key'] as String;
    } on DioException catch (e) {
      dev.log('[OrdersRepo] upload DioException: ${e.type} ${e.response?.statusCode}', name: 'order');
      throw DioClient.handleDioError(e);
    }
  }

  Future<Order> createOrder(CreateOrderParams params) async {
    dev.log('[OrdersRepo] POST /orders — templateId=${params.templateId} key=${params.idempotencyKey}', name: 'order');
    try {
      final response = await _dio.post<Map<String, dynamic>>('/orders', data: {
        'template_id': int.tryParse(params.templateId) ?? params.templateId,
        'idempotency_key': params.idempotencyKey,
        if (params.userPhotoKeys.length == 1)
          'user_photo_key': params.userPhotoKeys.first,
        if (params.userPhotoKeys.length > 1)
          'user_photo_keys': params.userPhotoKeys,
        if (params.userPrompt != null && params.userPrompt!.isNotEmpty)
          'user_prompt': params.userPrompt,
        'aspect_ratio': params.aspectRatio,
        'input_payload': {
          if (params.customerPhone != null && params.customerPhone!.isNotEmpty)
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

  /// GET /orders?page=1&limit=20 — paginated list for My Orders tab.
  /// Returns an empty page if the endpoint doesn't exist yet (404).
  Future<OrderListPage> getOrders({int page = 1, int limit = 20}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/orders',
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return OrderListPage.fromJson(data);
      }
      if (data is List) {
        return OrderListPage(
          orders: data
              .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
              .toList(),
          total: data.length,
          page: page,
          limit: limit,
        );
      }
      return OrderListPage(orders: const [], total: 0, page: page, limit: limit);
    } on DioException catch (e) {
      final err = DioClient.handleDioError(e);
      // 404 means the orders list endpoint doesn't exist yet — return empty.
      if (e.response?.statusCode == 404) {
        return OrderListPage(orders: const [], total: 0, page: page, limit: limit);
      }
      throw err;
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
